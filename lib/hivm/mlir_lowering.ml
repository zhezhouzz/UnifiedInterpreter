open Stdlib
open Unified_interpreter
module C = Core_lang
module M = Hivm_module
module Mem = Mlir_memory
module Scalar = Mlir_scalar
module Launch = Mlir_launch
module Source = Attention_runtime.Source
module J = Yojson.Safe.Util

type source = {
  origin : Hivm_event.origin;
  span : Source.span option;
  synthetic : bool;
}

type t = {
  ast : M.t;
  launch : Launch.t;
  program : C.program;
  sources : ((int * int list) * source) list;
  operation_names : string array;
}

let error (op : M.operation) reason =
  let message = op.opcode ^ ": " ^ reason in
  match op.span with Some span -> Source.fail span message | None -> invalid_arg message

let checked op f =
  try f () with
  | Invalid_argument message | J.Type_error (message,_) -> error op message
  | Not_found -> error op "missing operand, type, or attribute"
  | Z.Overflow -> error op "integer exceeds the supported address range"

let attribute (op : M.operation) name =
  Option.value (List.assoc_opt name op.decoded) ~default:`Null

let integers j = List.map Launch.z_of_json (J.to_list j)

let enum = function
  | `String text ->
      (match String.index_opt text '<' with
       | Some i when text.[String.length text-1]='>' -> String.sub text (i+1) (String.length text-i-2)
       | _ -> text)
  | _ -> invalid_arg "expected an enumeration attribute"

let int n = C.Literal (C.VInt (Z.of_int n))
let var id = C.Var id
let values ids = List.map var ids

type code = { command : C.command; points : (int list * source) list }

let terminal command = {command;points=[]}
let child index code = List.map (fun (site,point) -> index :: site,point) code.points

let prepend ?point make rest =
  let points = child 0 rest in
  let points = match point with None -> points | Some p -> ([],p) :: points in
  {command=make rest.command; points}

type registry = {
  scalars : (C.value list -> C.value) Queue.t;
  accesses : (string * (C.value list -> C.footprint)) Queue.t;
}

type context = {
  ast : M.t;
  types : (int,string) Hashtbl.t;
  launch : Launch.t;
  stream : Launch.stream;
  registry : registry;
  mutable next : int;
  mutable pipes : C.Device.pipe list;
}

let fresh ctx = let id=ctx.next in ctx.next <- id+1; id

let register queue value = let id=Queue.length queue in Queue.add value queue; id

let scalar ctx op id arguments evaluate =
  let f = register ctx.registry.scalars (fun args -> checked op (fun () -> evaluate args)) in
  prepend (fun next -> C.Scalar (id,f,arguments,next))

let type_name ctx id = Hashtbl.find ctx.types id
let type_of ctx id = Mem.type_of ctx.ast (type_name ctx id)
let shaped ctx id = Mem.shaped ctx.ast (type_name ctx id)

let bits ctx id = match type_of ctx id with
  | M.Integer width when width > 0 -> width | _ -> invalid_arg "expected an integer type"

let result (op : M.operation) = match op.results with
  | [id,_] -> id | _ -> invalid_arg "expected one SSA result"

let unary f = function [x] -> f x | _ -> invalid_arg "expected one operand"
let binary f = function [a;b] -> f a b | _ -> invalid_arg "expected two operands"

let point ?part ?(synthetic=false) path (op : M.operation) =
  {origin={path;opcode=op.opcode;part};span=op.span;synthetic}

let pipe_id = function
  | C.Device.S -> C.scalar_pipe | V -> 0 | MTE2 -> 1 | MTE3 -> 2
  | FIX -> 3 | MTE1 -> 4 | M -> 5

let use_pipe ctx pipe =
  if pipe<>C.Device.S && not (List.mem pipe ctx.pipes) then ctx.pipes <- pipe :: ctx.pipes;
  pipe_id pipe

let accessed read write = {C.reads=read;writes=write}
let bytes value = Mem.addresses (Mem.buffer value)

let read_values = List.concat_map (function C.VBuffer b -> Mem.addresses b | _ -> [])

let issue ctx (op : M.operation) point pipe args footprint =
  let pipe = use_pipe ctx pipe in
  let f = register ctx.registry.accesses (op.opcode,fun args -> checked op (fun () -> footprint args)) in
  prepend ~point (fun rest -> C.Issue (pipe,f,args,rest))

let allocate ctx op point ~space id arguments descriptor rest =
  let spec = fresh ctx and storage = fresh ctx and size = fresh ctx in
  let bind = scalar ctx op id [var spec;var storage] (binary (fun b v -> Mem.adopt (Mem.buffer b) v)) in
  let alloc = prepend ~point (fun rest -> C.Alloc (storage,space,[var size],rest)) in
  scalar ctx op spec arguments (fun vs -> C.VBuffer (descriptor vs))
    (scalar ctx op size [var spec] (unary (fun v -> C.VInt (Z.of_int (Mem.size (Mem.buffer v)))))
       (alloc (bind rest)))

let space = function
  | Some "#hivm.address_space<gm>" -> 1
  | Some "#hivm.address_space<cbuf>" -> 2
  | Some "#hivm.address_space<ca>" -> 3
  | Some "#hivm.address_space<cb>" -> 4
  | Some "#hivm.address_space<cc>" -> 5
  | Some "#hivm.address_space<ub>" -> 6
  | _ -> 0

let constant ctx op id =
  let value = attribute op "value" in
  match type_of ctx id,value with
  | M.Integer 1,`Bool b -> C.VBool b
  | M.Integer width,v -> Scalar.int width (Launch.z_of_json v)
  | M.Float _,`String literal -> C.VFloat (float_of_string literal)
  | M.Float _,`Float f -> C.VFloat f
  | _ -> invalid_arg "unsupported constant value"

let lower_arith ctx (op : M.operation) rest =
  let id = result op in
  let arguments = values op.operands in
  let evaluate = match op.opcode,op.operands with
    | "arith.constant",[] -> let v=constant ctx op id in fun _ -> v
    | "arith.select",[_;_;_] -> (function [c;a;b] -> if Scalar.boolean c then a else b
        | _ -> invalid_arg "expected condition and two alternatives")
    | "arith.cmpi",left::_ ->
        binary (Scalar.compare (J.to_int (attribute op "predicate")) (bits ctx left))
    | cast,[source] when List.mem cast Scalar.casts ->
        let source_bits = bits ctx source and result_bits = bits ctx id in
        let extend = if List.mem cast ["arith.extui";"arith.index_castui"]
          then Scalar.unsigned else Scalar.signed in
        unary (fun v -> Scalar.int result_bits (extend source_bits (Mem.integer v)))
    | opcode,[_;_] when List.mem opcode Scalar.binary_opcodes ->
        (match attribute op "overflowFlags" with
         | `Null | `String "#arith.overflow<none>" -> ()
         | _ -> invalid_arg "unsupported integer overflow flags");
        binary (Scalar.integer_binary opcode (bits ctx id))
    | _ -> invalid_arg "unsupported scalar operation" in
  scalar ctx op id arguments evaluate rest

let mixed static dynamic =
  let sentinel = Z.of_int64 Int64.min_int in
  let rest = ref dynamic in
  let take value = if not (Z.equal sentinel value) then value else
    match !rest with
    | v::vs -> rest := vs; Mem.integer v
    | [] -> invalid_arg "missing dynamic slice component" in
  let offsets,sizes,strides = static in
  let offsets = List.map take offsets in
  let sizes = List.map (fun n -> Mem.dimension (take n)) sizes in
  let strides = List.map take strides in
  if !rest<>[] then invalid_arg "extra dynamic slice components";
  offsets,sizes,strides

let slice_attributes op =
  integers (attribute op "static_offsets"), integers (attribute op "static_sizes"),
  integers (attribute op "static_strides")

let check_view ast ty b =
  let expected = Mem.descriptor ast ty b.C.shape ~offset:b.offset ~layout:b.strides () in
  if expected.element_bytes<>b.element_bytes then invalid_arg "view changes element width";
  Mem.validate b

let lower_view ctx (op : M.operation) rest =
  let id = result op in
  let ty = shaped ctx id in
  let eval = match op.opcode with
    | "memref.subview" ->
        let static = slice_attributes op in
        (function source::dynamic ->
          let offsets,sizes,steps = mixed static dynamic in
          let b = Mem.subview (Mem.buffer source) ~offsets ~sizes ~steps ty.shape in
          C.VBuffer (check_view ctx.ast ty b)
        | _ -> invalid_arg "missing source view")
    | "memref.reinterpret_cast" ->
        let static = slice_attributes op in
        (function source::dynamic ->
          let old = Mem.buffer source in
          (match mixed static dynamic with
           | [offset],shape,layout ->
               let b = Mem.descriptor ctx.ast ty shape ~offset ~layout () in
               if b.element_bytes<>old.element_bytes then invalid_arg "reinterpret changes element width";
               C.VBuffer (Mem.validate {b with storage=old.storage;bytes=old.bytes})
           | _ -> invalid_arg "expected one reinterpret offset")
        | _ -> invalid_arg "missing source view")
    | "memref.cast" -> unary (fun source -> C.VBuffer (check_view ctx.ast ty (Mem.buffer source)))
    | "bufferization.to_tensor" | "bufferization.to_memref" | "bufferization.to_buffer" ->
        unary (fun source ->
          let b = Mem.buffer source in ignore (Mem.constrain_shape ty.shape b.shape);
          if Mem.element_bytes ctx.ast ty<>b.element_bytes then invalid_arg "view changes element width";
          source)
    | _ -> invalid_arg "unsupported view operation" in
  scalar ctx op id (values op.operands) eval rest

let reshape ctx (op : M.operation) rest =
  let id = result op in
  let ty = shaped ctx id in
  let groups = J.to_list (attribute op "reassociation") |> List.map (fun j -> List.map J.to_int (J.to_list j)) in
  let expand = List.mem op.opcode ["tensor.expand_shape";"memref.expand_shape"] in
  let eval = function source::dynamic ->
    let b = Mem.buffer source in
    let product dims = List.fold_left (fun n d -> Z.mul n (Z.of_int d)) Z.one dims in
    let shape = if expand then
        let shape = Mem.dimensions ty.shape dynamic in
        List.iter2 (fun n group ->
          if not (Z.equal (Z.of_int n) (product (List.map (List.nth shape) group))) then
            invalid_arg "reshape reassociation changes element count") b.shape groups;
        shape
      else (if dynamic<>[] then invalid_arg "unexpected collapse arguments";
            List.map (fun group -> Mem.dimension (product (List.map (List.nth b.shape) group))) groups) in
    if b.strides <> Mem.strides b.shape then invalid_arg "reshape of a noncontiguous view";
    ignore (Mem.constrain_shape ty.shape shape);
    C.VBuffer (Mem.validate {b with shape;strides=Mem.strides shape})
  | _ -> invalid_arg "missing reshape input" in
  scalar ctx op id (values op.operands) eval rest

let copy = binary (fun source target ->
  let a = Mem.buffer source and b = Mem.buffer target in
  if a.shape<>b.shape || a.element_bytes<>b.element_bytes then invalid_arg "copy shape or element width differs";
  accessed (Mem.addresses a) (Mem.addresses b))

let tensor_slice ctx path (op : M.operation) rest =
  let id = result op in
  let ty = shaped ctx id in
  let static = slice_attributes op in
  let whole = point path op in
  let temp = point ~part:"tensor allocation" ~synthetic:true path op in
  if op.opcode="tensor.extract_slice" then (
    let view = fresh ctx in
    let to_view = function source::dynamic ->
      let offsets,sizes,steps = mixed static dynamic in
      C.VBuffer (Mem.subview (Mem.buffer source) ~offsets ~sizes ~steps ty.shape)
    | _ -> invalid_arg "missing tensor source" in
    let descriptor = unary (fun v -> Mem.descriptor ctx.ast ty (Mem.buffer v).shape ()) in
    scalar ctx op view (values op.operands) to_view
      (allocate ctx op temp ~space:0 id [var view] descriptor
         (issue ctx op whole S [var view;var id] copy rest)))
  else match op.operands with
    | source::destination::dynamic ->
        let source_shape = (shaped ctx source).shape in
        let descriptor = unary (fun v -> Mem.descriptor ctx.ast ty (Mem.buffer v).shape ()) in
        let footprint = function src::dst::out::dynamic ->
          let offsets,sizes,steps = mixed static dynamic in
          let src = Mem.buffer src and dst = Mem.buffer dst in
          let replaced = Mem.subview dst ~offsets ~sizes ~steps source_shape in
          if src.shape<>replaced.shape || src.element_bytes<>dst.element_bytes then
            invalid_arg "inserted slice shape or element width differs";
          let overwritten = Hashtbl.create 16 in
          List.iter (fun address -> Hashtbl.replace overwritten address ()) (Mem.addresses replaced);
          let retained = List.filter (fun address -> not (Hashtbl.mem overwritten address)) (Mem.addresses dst) in
          accessed (Mem.addresses src @ retained) (bytes out)
        | _ -> invalid_arg "missing insert_slice operands" in
        allocate ctx op temp ~space:0 id [var destination] descriptor
          (issue ctx op whole S (values (source::destination::id::dynamic)) footprint rest)
    | _ -> invalid_arg "missing insert_slice operands"

let linalg_ops = ["linalg.fill";"linalg.transpose";"linalg.broadcast";"linalg.matmul";
  "linalg.elemwise_binary";"linalg.elemwise_unary";"linalg.reduce"]

let hfusion_ops = ["hfusion.cast";"hfusion.elemwise_binary";"hfusion.compare";
  "hfusion.select";"hfusion.bitcast"]

let vector_ops = ["hivm.hir.vadd";"hivm.hir.vsub";"hivm.hir.vmul";"hivm.hir.vdiv";
  "hivm.hir.vexp";"hivm.hir.vln";"hivm.hir.vcast";"hivm.hir.vbrc";"hivm.hir.vreduce";
  "hivm.hir.vand";"hivm.hir.vshr";"hivm.hir.vmin";"hivm.hir.vmax";
  "hivm.hir.vcmp";"hivm.hir.vsel";"hivm.hir.vabs"]

let dps_operands (op : M.operation) =
  let destinations = match attribute op "operandSegmentSizes" with
    | `List [`Int inputs;`Int n] when inputs+n=List.length op.operands -> n
    | `List [`Int 1;`Int 1;`Int 1;`Int 1;`Int 1;`Int 1;`Int 1;`Int 0;`Int 0;`Int 0]
      when op.opcode="hivm.hir.mmadL1" && List.length op.operands=7 -> 1
    | `Null -> 1
    | _ -> invalid_arg "unsupported destination operand segments" in
  if destinations<>1 then invalid_arg "expected a single destination";
  match List.rev op.operands with dst::ins -> List.rev ins,dst
  | _ -> invalid_arg "missing destination operand"

let dps ctx path (op : M.operation) rest =
  let inputs,destination = dps_operands op in
  let rec pure_node (node : M.operation) =
    if node.opcode<>"linalg.yield" && not (String.starts_with ~prefix:"arith." node.opcode)
       && not (List.mem node.opcode ["math.exp";"math.log";"math.sqrt";"math.absf"]) then
      error node "unsupported effect in a structured computation region";
    List.iter (List.iter (fun b -> List.iter pure_node b.M.body)) node.regions in
  List.iter (List.iter (fun b -> List.iter pure_node b.M.body)) op.regions;
  let reads_init args = match op.opcode,args with
    | "hivm.hir.mmadL1",_::_::initialize::_ -> not (Scalar.boolean initialize)
    | ("linalg.matmul" | "linalg.reduce"),_ -> true
    | _ -> false in
  let footprint args = match List.rev args with
    | result::init::ins ->
        let ins = List.rev ins in
        let read = read_values ins in
        accessed (if reads_init ins then bytes init @ read else read) (bytes result)
    | _ -> invalid_arg "missing structured operands" in
  let origin = point path op in
  match op.results with
  | [id,_] ->
      let ty = shaped ctx id in
      if ty.kind<>M.Tensor || (shaped ctx destination).kind<>M.Tensor then
        invalid_arg "expected tensor result and tensor destination";
      let descriptor = unary (fun init -> Mem.descriptor ctx.ast ty (Mem.buffer init).shape ()) in
      let storage = point ~part:"tensor allocation" ~synthetic:true path op in
      allocate ctx op storage ~space:0 id [var destination] descriptor
        (issue ctx op origin S (values (inputs @ [destination;id])) footprint rest)
  | [] ->
      if (shaped ctx destination).kind<>M.Memref then invalid_arg "expected a memref destination";
      let pipe = if List.mem op.opcode vector_ops then C.Device.V else C.Device.S in
      issue ctx op origin pipe (values (inputs @ [destination;destination])) footprint rest
  | _ -> invalid_arg "multiple destination results are unsupported"

let matrix_macro ctx path (op : M.operation) rest =
  let inputs,destination = dps_operands op in
  match inputs with
  | [a;b;init;m;k;n] ->
      let tile rows columns value =
        let b = Mem.buffer value in
        let elements = List.fold_left (fun size dim -> Z.mul size (Z.of_int dim)) Z.one b.shape in
        let required = Z.mul (Mem.integer rows) (Mem.integer columns) in
        if Z.sign required<=0 || not (Z.equal elements required) then
          invalid_arg "matrix macro requires whole tiles";
        Mem.addresses b in
      let load = function
        | [a;b;m;k;n] -> accessed (tile m k a @ tile k n b) []
        | _ -> invalid_arg "invalid matrix load operands" in
      let compute = function
        | [initial;m;n;dst] ->
            let writes = tile m n dst in
            accessed (if Scalar.boolean initial then [] else writes) writes
        | _ -> invalid_arg "invalid matrix compute operands" in
      let space id = (shaped ctx id).M.space in
      if List.exists (fun id -> space id <> Some "#hivm.address_space<cbuf>") [a;b] ||
         space destination <> Some "#hivm.address_space<cc>"
      then invalid_arg "matrix macro expects L1 operands and an L0C destination";
      (* The macro's input transfer must complete before its matrix task.
         Internal handoff keys are disjoint from source flag IDs. *)
      let handoff = C.Literal (C.VEvent (-1 - fresh ctx)) in
      let part part = point ~part path op in
      let transfer = use_pipe ctx MTE1 and matrix = use_pipe ctx M in
      let sync stage mode = prepend ~point:(part stage)
          (fun next -> C.Sync (mode,transfer,C.Data matrix,handoff,next)) in
      issue ctx op (part "load") MTE1 (values [a;b;m;k;n]) load
        (sync "signal_loaded" LocalSet
           (sync "wait_loaded" LocalWait
              (issue ctx op (part "compute") M (values [init;m;n;destination]) compute rest)))
  | _ -> invalid_arg "unsupported matrix macro operands"

let synchronization ctx path (op : M.operation) rest =
  let mode,source,target,static = match op.opcode with
    | "hivm.hir.set_flag" -> C.LocalSet,"set_pipe","wait_pipe","static_event_id"
    | "hivm.hir.wait_flag" -> C.LocalWait,"set_pipe","wait_pipe","static_event_id"
    | "hivm.hir.sync_block_set" -> C.BlockSet,"tpipe","pipe","static_flag_id"
    | _ -> C.BlockWait,"tpipe","pipe","static_flag_id" in
  let cross = mode=C.BlockSet || mode=C.BlockWait in
  if cross && Option.is_none ctx.launch.edges then invalid_arg "cross-block synchronization requires launch edges";
  (match attribute op "tsync_instr_mode" with
   | `Null -> () | mode when enum mode="INTRA_BLOCK_SYNCHRONIZATION" -> ()
   | _ -> invalid_arg "unsupported cross-core synchronization mode");
  let source = use_pipe ctx (Launch.pipe (enum (attribute op source))) in
  let target = match Launch.pipe (enum (attribute op target)) with
    | C.Device.S -> C.ScalarEnd | p -> C.Data (use_pipe ctx p) in
  let emit flag = prepend ~point:(point path op) (fun next -> C.Sync (mode,source,target,flag,next)) rest in
  let event n =
    let n = Mem.dimension n in
    C.VEvent n in
  match op.operands,attribute op static with
  | [id],`Null ->
      let flag = fresh ctx in
      scalar ctx op flag [var id] (unary (fun v -> event (Mem.integer v))) (emit (var flag))
  | [],(`Int _ | `Intlit _ as n) -> emit (C.Literal (event (Launch.z_of_json n)))
  | [],`String text ->
      let name = enum (`String text) and prefix = "EVENT_ID" in
      if not (String.starts_with ~prefix name) then invalid_arg "invalid static event id";
      let number = String.sub name (String.length prefix) (String.length name-String.length prefix) in
      emit (C.Literal (event (Z.of_string number)))
  | _ -> invalid_arg "expected one static or dynamic event id"

let rec lower_block ctx path (block : M.block) =
  let operations = List.mapi (fun i op -> i,op) block.body in
  List.fold_right (fun (i,op) rest -> checked op (fun () -> lower_op ctx (path @ [i]) op rest))
    operations (terminal C.End)

and lower_op ctx path (op : M.operation) rest =
  let args = values op.operands and origin = point path op in
  let block region b = lower_block ctx (path @ [region;0]) b in
  match op.opcode,op.operands,op.regions with
  | "func.return",_,_ -> terminal (C.Return args)
  | "scf.yield",_,_ -> terminal (C.Yield args)
  | "scf.if",[test],[[yes];[no]] ->
      let yes = block 0 yes and no = block 1 no in
      let ids = List.map fst op.results in
      {command=C.Branch_values (ids,var test,yes.command,no.command,rest.command);
       points=child 0 yes @ child 1 no @ child 2 rest}
  | "scf.if",[test],[[yes];[]] when op.results=[] ->
      let yes = block 0 yes in
      {command=C.Branch (var test,yes.command,C.End,rest.command);points=child 0 yes @ child 2 rest}
  | "scf.for",lo::hi::step::initial,[[body]] ->
      if attribute op "unsignedCmp"<>`Null then invalid_arg "unsigned induction comparisons are unsupported";
      (match body.arguments with
       | (index,_)::carried when List.length carried=List.length initial &&
                                List.length carried=List.length op.results ->
           let body = block 0 body in
           let carried = List.map2 (fun (id,_) initial -> id,var initial) carried initial in
           let ids = List.map fst op.results and stride = fresh ctx in
           let loop = {command=C.For_values (index,var lo,var hi,var stride,carried,ids,body.command,rest.command);
                       points=child 0 body @ child 1 rest} in
           scalar ctx op stride [var step] (unary (fun v ->
             if Z.sign (Mem.integer v)<=0 then invalid_arg "scf.for step must be positive"; v)) loop
       | _ -> invalid_arg "mismatched loop-carried values")
  | ("memref.alloc" | "tensor.empty"),_,_ ->
      let id = result op in
      let ty = shaped ctx id in
      let descriptor dims = Mem.descriptor ctx.ast ty (Mem.dimensions ty.shape dims) () in
      let origin = if ty.kind=M.Tensor then {origin with synthetic=true} else origin in
      allocate ctx op origin ~space:(space ty.space) id args descriptor rest
  | ("memref.subview" | "memref.reinterpret_cast" | "memref.cast" | "bufferization.to_tensor"
     | "bufferization.to_memref" | "bufferization.to_buffer"),_,_ -> lower_view ctx op rest
  | ("tensor.expand_shape" | "tensor.collapse_shape" | "memref.expand_shape" | "memref.collapse_shape"),_,_ ->
      reshape ctx op rest
  | ("tensor.extract_slice" | "tensor.insert_slice"),_,_ -> tensor_slice ctx path op rest
  | ("memref.dim" | "tensor.dim"),_,_ ->
      scalar ctx op (result op) args (binary (fun b axis ->
        let length = List.nth (Mem.buffer b).shape (Mem.dimension (Mem.integer axis)) in
        C.VInt (Z.of_int length))) rest
  | ("memref.copy" | "bufferization.materialize_in_destination"),_,_ ->
      issue ctx op origin S args copy rest
  | "hivm.hir.load",[_;_],_ when op.results=[] -> issue ctx op origin MTE2 args copy rest
  | "hivm.hir.store",[_;_],_ when op.results=[] -> issue ctx op origin MTE3 args copy rest
  | ("hivm.hir.load" | "hivm.hir.store"),[source;destination],_ when op.results<>[] ->
      let id = result op in
      let ty = shaped ctx id in
      let descriptor = unary (fun v -> Mem.descriptor ctx.ast ty (Mem.buffer v).shape ()) in
      let storage = point ~part:"tensor allocation" ~synthetic:true path op in
      allocate ctx op storage ~space:0 id [var destination] descriptor
        (issue ctx op origin S (values [source;id]) copy rest)
  | "memref.store",_::_,_ ->
      let footprint = function _::dst::indices ->
        accessed [] (Mem.addresses (Mem.at (Mem.buffer dst) (List.map Mem.integer indices)))
      | _ -> invalid_arg "missing scalar store operands" in
      issue ctx op origin S args footprint rest
  | ("hivm.hir.set_flag" | "hivm.hir.wait_flag" | "hivm.hir.sync_block_set" | "hivm.hir.sync_block_wait"),_,_ ->
      synchronization ctx path op rest
  | "hivm.hir.pipe_barrier",[],_ ->
      let pipe = match enum (attribute op "pipe") with
        | "PIPE_ALL" -> C.All | name -> C.Pipe (use_pipe ctx (Launch.pipe name)) in
      prepend ~point:origin (fun rest -> C.Barrier (pipe,rest)) rest
  | "hivm.hir.get_block_idx",[],_ ->
      scalar ctx op (result op) [] (fun _ -> C.VInt (Z.of_int ctx.stream.location.block)) rest
  | "hivm.hir.get_sub_block_idx",[],_ ->
      let index = match ctx.stream.location.core with C.Device.Cube -> 0 | Vector n -> n in
      scalar ctx op (result op) [] (fun _ -> C.VInt (Z.of_int index)) rest
  | "hivm.hir.mmadL1",_,_ when op.results=[] -> matrix_macro ctx path op rest
  | opcode,_,_ when List.mem opcode linalg_ops || List.mem opcode hfusion_ops || List.mem opcode vector_ops ||
                       (opcode="hivm.hir.mmadL1" && op.results<>[]) -> dps ctx path op rest
  | opcode,_,_ when String.starts_with ~prefix:"arith." opcode -> lower_arith ctx op rest
  | _ -> invalid_arg "unsupported operation for Core Language lowering"

let lower_with_launch ast (launch : Launch.t) =
  let registry = {scalars=Queue.create ();accesses=Queue.create ()} in
  let stream (s : Launch.stream) =
    let types = Hashtbl.create 32 in
    let rec visit (b : M.block) =
      List.iter (fun (id,ty) -> Hashtbl.add types id ty) b.arguments;
      List.iter (fun (op : M.operation) ->
        List.iter (fun (id,ty) -> Hashtbl.add types id ty) op.results;
        List.iter (List.iter visit) op.regions) b.body in
    visit s.ast;
    let next = Hashtbl.fold (fun id _ n -> max (id+1) n) types 0 in
    let ctx = {ast;types;launch;stream=s;registry;next;pipes=[]} in
    let code = lower_block ctx [] s.ast in
    let pipes = match s.pipes with
      | Some pipes ->
          if not (List.for_all (fun p -> List.mem p pipes) ctx.pipes) then
            invalid_arg (s.entry ^ " uses a pipe missing from its launch configuration");
          pipes
      | None -> ctx.pipes in
    let pipes = List.filter ((<>) C.Device.S) pipes |> List.map pipe_id |> List.sort_uniq compare in
    C.{id=s.id;params=s.arguments;pipes;body=code.command},
    List.map (fun (site,point) -> (s.id,site),point) code.points in
  let streams,sources = List.split (List.map stream launch.streams) in
  let scalars = Array.of_seq (Queue.to_seq registry.scalars) in
  let accesses = Array.of_seq (Queue.to_seq registry.accesses) in
  let program = C.{streams;scalar_eval=(fun _ id -> scalars.(id));
                   footprint=(fun _ _ id -> snd accesses.(id));block_edge=Launch.block_edge launch} in
  {ast;launch;program;sources=List.concat sources;operation_names=Array.map fst accesses}

let lower ?entry ?configuration ast =
  lower_with_launch ast (Launch.bind ?entry ?configuration ast)
