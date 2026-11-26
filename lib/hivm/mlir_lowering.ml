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
  frames : (string * int list * int * string) list;
}

type t = {
  ast_digest : string;
  launch : Launch.t;
  program : C.program;
  sources : ((int * int list) * source) list;
  operation_names : string array;
}

let error (op : M.operation) =
  let code=op.opcode and span=op.span in
  fun reason -> let message=code ^ ": " ^ reason in
  match span with Some span -> Source.fail span message | None -> invalid_arg message

let checked op =
  let fail=error op in fun f ->
  try f () with
  | Invalid_argument message | J.Type_error (message,_) -> fail message
  | Not_found -> fail "missing operand, type, or attribute"
  | Z.Overflow -> fail "integer exceeds the supported address range"

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
  banks : ((int * C.Device.core option * string),int) Hashtbl.t;
  initial : bytes array;
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
  entry : string;
  parents : string list;
  depth : int;
  rotation : int option;
  partial : bool;
  uses_async : bool ref;
}

let fresh ctx = let id=ctx.next in ctx.next <- id+1; id

let register queue value = let id=Queue.length queue in Queue.add value queue; id

let scalar ctx op id arguments evaluate =
  let protect=checked op in
  let f = register ctx.registry.scalars (fun args -> protect (fun () -> evaluate args)) in
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
  {origin={path;opcode=op.opcode;part};span=op.span;synthetic;frames=[]}

let validate_sources ast launch sources =
  let sites=Hashtbl.create (List.length sources) in
  List.iter (fun ((stream,site),p) ->
    if Hashtbl.mem sites (stream,site) then invalid_arg "duplicate origin for a Core site";
    Hashtbl.add sites (stream,site) ();
    let initial=(List.find (fun (s : Launch.stream) -> s.id=stream) launch.Launch.streams).entry in
    let entry=List.fold_left (fun entry (caller,path,depth,callee) ->
      let call=M.resolve ast ~entry path in
      if entry<>caller || depth<0 || call.opcode<>"func.call" || attribute call "callee"<>`String callee then
        invalid_arg "invalid source call frame";
      callee) initial p.frames in
    if (M.resolve ast ~entry p.origin.path).opcode<>p.origin.opcode then
      invalid_arg "Core site and source operation disagree") sources;
  sources

let pipe_id = function
  | C.Device.S -> C.scalar_pipe | V -> 0 | MTE2 -> 1 | MTE3 -> 2
  | FIX -> 3 | MTE1 -> 4 | M -> 5

let use_pipe ctx pipe =
  if pipe<>C.Device.S && not (List.mem pipe ctx.pipes) then ctx.pipes <- pipe :: ctx.pipes;
  pipe_id pipe

let accessed read write = {C.reads=read;writes=write}
let bytes value = Mem.addresses (Mem.buffer value)

let read_values = List.concat_map (function C.VBuffer b | VTensor (b,_) -> Mem.addresses b | _ -> [])

let initial_bytes ast (s : Launch.storage) =
  match s.initial with None -> Bytes.empty | Some (ty,values) ->
  let width,encode = match Mem.type_of ast ty with
    | M.Integer bits -> max 1 ((bits+7)/8),Launch.z_of_json
    | M.Float 16 when ty="bf16" -> 2,(fun v ->
        let n = Int32.bits_of_float (J.to_number v) in
        let rounded = Int32.add n (Int32.add 0x7fffl (Int32.logand 1l (Int32.shift_right_logical n 16))) in
        Z.of_int32 (Int32.shift_right_logical rounded 16))
    | M.Float 16 -> 2,(fun v -> Z.of_int64 (Device_value.half_bits (J.to_number v)))
    | M.Float 32 -> 4,(fun v -> Z.of_int32 (Int32.bits_of_float (J.to_number v)))
    | M.Float 64 -> 8,(fun v -> Z.of_int64 (Int64.bits_of_float (J.to_number v)))
    | _ -> invalid_arg ("unsupported initial storage type " ^ ty) in
  let data = Bytes.create (width * List.length values) in
  List.iteri (fun i v -> let n = encode v in
    for byte=0 to width-1 do Bytes.set_uint8 data (width*i+byte) (Z.to_int (Z.extract n (8*byte) 8)) done) values;
  data

let local_cells ctx = function
  | (C.Allocated _,_)::_ -> true
  | (C.Input i,_)::_ -> i >= List.length ctx.launch.storages
  | (C.Invalid_address,_)::_ | [] -> false

let load_value ctx ty =
  let contents=ctx.registry.initial in
  match Mem.type_of ctx.ast ty with
  | M.Shaped {kind=M.Memref;_} -> (fun cells -> C.VBuffer (Effect.perform (C.Load_descriptor (List.hd cells))))
  | scalar_type -> fun cells ->
      let initial = lazy (
        let n,_ = List.fold_left (fun (n,shift) (storage,offset) ->
          let byte = match storage with
            | C.Input i when i<Array.length contents ->
                let data=contents.(i) in if offset<Bytes.length data then Bytes.get_uint8 data offset else 0
            | _ -> raise (C.Prefix_boundary "a device memory value controls subsequent scheduling") in
          Z.logor n (Z.shift_left (Z.of_int byte) shift),shift+8) (Z.zero,0) cells in
        match scalar_type with
        | M.Integer bits -> Scalar.int bits n
        | M.Float 16 when ty="bf16" -> C.VFloat (Int32.float_of_bits (Int32.shift_left (Z.to_int32 n) 16))
        | M.Float 16 -> C.VFloat (Device_value.half_float (Z.to_int n))
        | M.Float 32 -> C.VFloat (Int32.float_of_bits (Z.to_int32 (Z.signed_extract n 0 32)))
        | M.Float 64 -> C.VFloat (Int64.float_of_bits (Z.to_int64 (Z.signed_extract n 0 64)))
        | _ -> invalid_arg ("unsupported scalar load of " ^ ty)) in
      (if local_cells ctx cells then
           (match Effect.perform (C.Capture_local (cells,ty)) with
            | Some value -> C.VDeferred (lazy (Effect.perform (C.Use_local cells); C.demand value))
            | None -> C.VMemory_read (cells,initial))
       else C.VMemory_read (cells,initial))

let indirect_atomic ctx path op rest =
  if attribute op "symbol"<>`String "__builtin_indirect_atomic" ||
     attribute op "extra_attr"<>`String "operate=add" ||
     attribute op "gm_addr_args_indices"<>`List [`Int 0] then
    invalid_arg "unsupported custom operation";
  let offsets_type=(shaped ctx (List.nth op.M.operands 1)).element
  and mask_type=(shaped ctx (List.nth op.operands 3)).element in
  let mask_value=load_value ctx mask_type and offset_value=load_value ctx offsets_type in
  let footprint = function
    | [base;offsets;values;mask;out] ->
        let base=Mem.buffer base and offsets=Mem.buffer offsets and mask=Mem.buffer mask
        and values=Mem.buffer values and out=Mem.buffer out in
        let lanes = match mask.shape with [n] when offsets.shape=[n] && values.shape=[n] && out.shape=[n] -> n
          | _ -> invalid_arg "incompatible indirect atomic lane shapes" in
        let reads = ref (Mem.addresses mask) and writes = ref [] in
        for i=0 to lanes-1 do
          let lane b = Mem.addresses (Mem.at b [Z.of_int i]) in
          if not (Z.equal (Mem.integer (mask_value (lane mask))) Z.zero) then (
            let index = Mem.integer (offset_value (lane offsets)) in
            let target=Mem.addresses (Mem.at base [index]) in
            reads := List.rev_append (lane offsets @ lane values @ target) !reads;
            writes := List.rev_append (target @ lane out) !writes)
        done; accessed !reads !writes
    | _ -> invalid_arg "expected four inputs and one destination for indirect atomic add" in
  let pipe=Launch.pipe (enum (attribute op "hivm.pipe")) in
  let id=register ctx.registry.accesses (op.opcode,footprint) in
  prepend ~point:(point path op) (fun next -> C.Issue(use_pipe ctx pipe,id,values op.operands,next)) rest

let issue_on ctx (op : M.operation) point pipe args footprint =
  if pipe=C.async_pipe then ctx.uses_async := true;
  let protect=checked op in
  let f = register ctx.registry.accesses (op.opcode,fun args -> protect (fun () -> footprint args)) in
  prepend ~point (fun rest -> C.Issue (pipe,f,args,rest))

let issue ctx op point pipe = issue_on ctx op point (use_pipe ctx pipe)

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

let device_bank ctx core bank =
  let key=ctx.stream.location.block,core,bank in
  match Hashtbl.find_opt ctx.registry.banks key with
  | Some i -> i
  | None -> let i=List.length ctx.launch.storages + Hashtbl.length ctx.registry.banks in
      Hashtbl.add ctx.registry.banks key i; i

let pointer ctx op rest =
  let id = result op in
  let ty = shaped ctx id in
  let make_view=Mem.descriptor ctx.ast ty in
  let bank = match ty.space with
    | Some name when space ty.space>=2 -> name
    | _ -> invalid_arg "pointer_cast requires a device storage space" in
  let location = ctx.stream.location in
  let core = if space ty.space=6 then Some location.core else None in
  let storage = device_bank ctx core bank in
  let count=match attribute op "operandSegmentSizes" with
    | `List [`Int count;`Int _] -> count
    | `Null -> List.length op.operands - List.length (List.filter Option.is_none ty.shape)
    | _ -> invalid_arg "invalid pointer operand segments" in
  if count<1 then invalid_arg "missing device address";
  let operands=values op.operands in
  let args=if count=1 then operands else (match ctx.rotation with Some id -> var id::operands
    | None -> invalid_arg "pointer with multiple buffers requires an enclosing loop") in
  scalar ctx op id args (fun inputs ->
      let slot,operands=if count=1 then 0,inputs else match inputs with
        | counter::xs -> Z.to_int (Z.erem (Scalar.unsigned 64 (Mem.integer counter)) (Z.of_int count)),xs
        | [] -> assert false in
      let base=List.nth operands slot and dims=List.drop count operands in
        let b = make_view (Mem.dimensions ty.shape dims) () in
        let b = {b with storage=Some (C.Input storage);base_bytes=Mem.dimension (Mem.integer base)} in
        C.VBuffer {b with bytes=Mem.size b}) rest

let affine op =
  let map = attribute op "map" in
  let opcode=op.M.opcode in
  let dims = J.to_int (J.member "dimensions" map) in
  fun operands ->
  let args = Array.of_list (List.map Mem.integer operands) in
  if Array.length args <> dims + J.to_int (J.member "symbols" map) then invalid_arg "affine map arity";
  let rec eval = function
    | `List [`String "d";`Int i] -> args.(i)
    | `List [`String "s";`Int i] -> args.(dims+i)
    | `List [`String op;x;y] ->
        let a=eval x and b=eval y in
        (match op with "+" -> Z.add a b | "*" -> Z.mul a b | "mod" -> Z.erem a b
         | "floordiv" -> Z.fdiv a b | "ceildiv" -> Z.cdiv a b | _ -> invalid_arg "unknown affine operator")
    | literal -> Launch.z_of_json literal in
  match List.map eval (J.to_list (J.member "results" map)) with
  | [x] -> C.VInt x
  | x::xs when opcode="affine.min" -> C.VInt (List.fold_left Z.min x xs)
  | x::xs when opcode="affine.max" -> C.VInt (List.fold_left Z.max x xs)
  | _ -> invalid_arg "unexpected affine result arity"

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

let like_buffer ctx ty =
  let make=Mem.descriptor ctx.ast ty in unary (fun v -> make (Mem.buffer v).shape ())

let lower_view ctx (op : M.operation) rest =
  let id = result op in
  let ty = shaped ctx id in
  let make=Mem.descriptor ctx.ast ty and width=Mem.element_bytes ctx.ast ty in
  let check_view b =
    let expected = make b.C.shape ~offset:b.offset ~layout:b.strides () in
    if expected.element_bytes<>b.element_bytes then invalid_arg "view changes element width";
    Mem.validate b in
  let eval = match op.opcode with
    | "memref.subview" ->
        let static = slice_attributes op in
        (function source::dynamic ->
          let offsets,sizes,steps = mixed static dynamic in
          let b = Mem.subview (Mem.buffer source) ~offsets ~sizes ~steps ty.shape in
          C.VBuffer (check_view b)
        | _ -> invalid_arg "missing source view")
    | "memref.reinterpret_cast" ->
        let static = slice_attributes op in
        (function source::dynamic ->
          let old = Mem.buffer source in
          (match mixed static dynamic with
           | [offset],shape,layout ->
               let b = make shape ~offset ~layout () in
               if b.element_bytes<>old.element_bytes then invalid_arg "reinterpret changes element width";
               C.VBuffer (Mem.validate {b with storage=old.storage;bytes=old.bytes;base_bytes=old.base_bytes})
           | _ -> invalid_arg "expected one reinterpret offset")
        | _ -> invalid_arg "missing source view")
    | "memref.cast" -> unary (fun source -> C.VBuffer (check_view (Mem.buffer source)))
    | "bufferization.to_tensor" | "bufferization.to_memref" | "bufferization.to_buffer" ->
        unary (fun source ->
          let b = Mem.buffer source in ignore (Mem.constrain_shape ty.shape b.shape);
          if width<>b.element_bytes then invalid_arg "view changes element width";
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
    ignore (Mem.constrain_shape ty.shape shape);
    let strides=if expand then
        List.concat (List.map2 (fun stride axes ->
          List.map (Z.mul stride) (Mem.strides (List.map (List.nth shape) axes))) b.strides groups)
      else List.map (fun axes ->
        let active=List.filter (fun axis -> List.nth b.shape axis>1) axes in
        let last=List.hd (List.rev (if active=[] then axes else active)) in
        let stride=List.nth b.strides last in
        let expected=List.map (Z.mul stride) (Mem.strides (List.map (List.nth b.shape) axes)) in
        if not (List.for_all2 (fun axis step -> List.nth b.shape axis<=1 || List.nth b.strides axis=step) axes expected)
        then invalid_arg "reshape merges discontinuous dimensions"; stride) groups in
    let view = Mem.validate {b with shape;strides} in
    (match source with C.VTensor (_,cell) ->
       C.VTensor (view,fun at ->
         let linear=List.fold_left2 (fun n width i -> n*width+i) 0 shape at in
         let _,coords=List.fold_right (fun width (n,is) -> n/width,n mod width::is) b.shape (linear,[]) in
         cell coords)
     | _ -> C.VBuffer view)
  | _ -> invalid_arg "missing reshape input" in
  scalar ctx op id (values op.operands) eval rest

let copy = binary (fun source target ->
  let a = Mem.buffer source and b = Mem.buffer target in
  if a.shape<>b.shape || a.element_bytes<>b.element_bytes then invalid_arg "copy shape or element width differs";
  accessed (Mem.addresses a) (Mem.addresses b))

let nz_rectangle view rows columns =
  match view.C.shape with
  | [cols;row_blocks;inner_r;inner_c] when inner_r>0 && inner_c>0 &&
      rows<=row_blocks*inner_r && columns<=cols*inner_c ->
      if rows=row_blocks*inner_r && columns=cols*inner_c then Mem.addresses view else
      List.concat_map (fun r -> List.concat_map (fun c ->
        Mem.addresses (Mem.at view (List.map Z.of_int [c/inner_c;r/inner_r;r mod inner_r;c mod inner_c])))
        (List.init columns Fun.id)) (List.init rows Fun.id)
  | _ -> invalid_arg "NZ view does not contain the requested tile"

let nd2nz = binary (fun source target ->
  let src=Mem.buffer source and dst=Mem.buffer target in
  match src.shape with [r;c] -> accessed (Mem.addresses src) (nz_rectangle dst r c)
  | _ -> invalid_arg "nd2nz requires a two-dimensional input")

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
    let descriptor = like_buffer ctx ty in
    scalar ctx op view (values op.operands) to_view
      (allocate ctx op temp ~space:0 id [var view] descriptor
         (issue ctx op whole S [var view;var id] copy rest)))
  else match op.operands with
    | source::destination::dynamic ->
        let source_shape = (shaped ctx source).shape in
        let descriptor = like_buffer ctx ty in
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

let hfusion_ops = ["hfusion.arange";"hfusion.cast";"hfusion.elemwise_binary";"hfusion.compare";
  "hfusion.select";"hfusion.bitcast"]

let vector_ops = ["hivm.hir.vadd";"hivm.hir.vsub";"hivm.hir.vmul";"hivm.hir.vdiv";
  "hivm.hir.vexp";"hivm.hir.vln";"hivm.hir.vcast";"hivm.hir.vbrc";"hivm.hir.vreduce";
  "hivm.hir.vand";"hivm.hir.vshr";"hivm.hir.vmin";"hivm.hir.vmax";
  "hivm.hir.vcmp";"hivm.hir.vsel";"hivm.hir.vabs";"hivm.hir.vtranspose"]

let dps_operands (op : M.operation) =
  let destinations = match attribute op "operandSegmentSizes" with
    | `List [`Int 1;`Int 1;`Int 1] when op.opcode="hfusion.arange" -> 1
    | `List [`Int 1;`Int 1;`Int 0;`Int 0;`Int 0;`Int 0;`Int 0;`Int 0;`Int 0;`Int 0;`Int 1]
        when op.opcode="hivm.hir.matmul" && List.length op.operands=3 -> 1
    | `List (`Int inputs::`Int 1::optional) when List.mem op.opcode vector_ops &&
          List.for_all ((=) (`Int 0)) optional && inputs+1=List.length op.operands -> 1
    | `List [`Int inputs;`Int n] when inputs+n=List.length op.operands -> n
    | `List [`Int 1;`Int 1;`Int 1;`Int 1;`Int 1;`Int 1;`Int 1;`Int 0;`Int 0;`Int 0]
      when op.opcode="hivm.hir.mmadL1" && List.length op.operands=7 -> 1
    | `Null -> 1
    | _ -> invalid_arg "unsupported destination operand segments" in
  if destinations<>1 then invalid_arg "expected a single destination";
  match List.rev op.operands with dst::ins -> List.rev ins,dst
  | _ -> invalid_arg "missing destination operand"

let tensor_cell ctx element =
  let load=load_value ctx element in fun v at -> match v with
  | C.VTensor (_,read) -> read at
  | VBuffer b -> load (Mem.addresses (Mem.at b (List.map Z.of_int at)))
  | scalar -> scalar

let computed_tensor ctx (op : M.operation) inputs =
  let opcode=op.opcode and attrs=op.decoded in
  let field name=enum (List.assoc name attrs) in
  let element=Mem.type_of ctx.ast (shaped ctx (result op)).element in
  let readers=Array.of_list (List.map (fun id ->
    let ty=match type_of ctx id with M.Shaped t -> t.element | _ -> type_name ctx id in
    tensor_cell ctx ty) inputs) in
  let axes=if opcode="linalg.broadcast" then List.map Z.to_int (integers (attribute op "dimensions")) else [] in
  let sign=List.exists (List.exists (fun (block : M.block) ->
    List.exists (fun (o : M.operation) -> o.opcode="arith.extsi") block.body)) op.regions in
  fun vs ->
  match List.rev vs with
  | out::args ->
      let args=List.rev args in
      let b=Mem.buffer out in
      let read i at = C.demand (readers.(i) (List.nth args i) at) in
      let scalar at = match opcode with
        | "linalg.fill" -> read 0 []
        | "hfusion.arange" ->
            let initial,steps = match args with
              | origin::steps when List.length steps=List.length at -> Mem.integer origin,steps
              | steps when List.length steps=List.length at -> Z.zero,steps
              | _ -> invalid_arg "range operands do not match tensor rank" in
            C.VInt (List.fold_left2 (fun n step i -> Z.add n (Z.mul (Mem.integer step) (Z.of_int i))) initial steps at)
        | "linalg.broadcast" ->
            read 0 (List.filter_map Fun.id (List.mapi (fun i x -> if List.mem i axes then None else Some x) at))
        | "hfusion.select" -> read (if Scalar.boolean (read 0 at) then 1 else 2) at
        | "hfusion.compare" ->
            let a=read 0 at and b=read 1 at in
            let compare op_float op_int = match a,b with
              | C.VFloat x,C.VFloat y -> op_float x y | _ -> op_int (Mem.integer a) (Mem.integer b) in
            C.VBool (match field "compare_fn" with "veq" -> compare (=) Z.equal | "vne" -> not (compare (=) Z.equal)
              | "vlt" -> compare (<) Z.lt | "vle" -> compare (<=) Z.leq | "vge" -> compare (>=) Z.geq
              | "vgt" -> compare (>) Z.gt | f -> invalid_arg ("unsupported comparison " ^ f))
        | "hfusion.cast" when field "cast"="cast_signed" ->
            (match element,read 0 at with
             | M.Integer width,C.VBool b ->
                 Scalar.int width (if not b then Z.zero else if sign then Z.minus_one else Z.one)
             | M.Integer width,C.VInt n -> Scalar.int width n
             | _ -> raise (C.Prefix_boundary "unsupported cast in a scheduling operand"))
        | "linalg.elemwise_binary" | "hfusion.elemwise_binary" ->
            let code = match field "fun" with
              | "add" -> "arith.addi" | "sub" -> "arith.subi" | "mul" -> "arith.muli"
              | "shrsi" -> "arith.shrsi" | "vand" -> "arith.andi" | "vor" -> "arith.ori"
              | "max_signed" -> "arith.maxsi" | "min_signed" -> "arith.minsi"
              | f -> raise (C.Prefix_boundary ("unsupported scheduling operand " ^ f)) in
            (match element with M.Integer width ->
               Scalar.integer_binary code width (read 0 at) (read 1 at)
             | _ -> raise (C.Prefix_boundary "floating-point tensor arithmetic controls scheduling"))
        | _ -> raise (C.Prefix_boundary (opcode ^ " tensor value controls scheduling")) in
      C.VTensor (b,scalar)
  | _ -> invalid_arg "missing result tensor"

let indirect ctx path (op : M.operation) rest =
  let load = op.opcode="hfusion.indirect_load" in
  let base,offsets,mask,data,destination = match load,op.generic,op.operands with
    | true,true,[base;offsets;out;mask;other] | true,false,[base;offsets;mask;other;out] ->
        base,offsets,mask,other,Some out
    | false,true,[base;offsets;data;mask] | false,false,[data;offsets;mask;base] ->
        base,offsets,mask,data,None
    | _ -> invalid_arg "invalid indirect memory operands" in
  let mask_cell=tensor_cell ctx (shaped ctx mask).element and offset_cell=tensor_cell ctx (shaped ctx offsets).element in
  let is_active m at = not (Z.equal Z.zero (Mem.integer (mask_cell m at))) in
  let address b o at =
    let index=Mem.integer (offset_cell o at) in
    Mem.addresses (Mem.at (Mem.buffer b) [index]) in
  let footprint = function b::o::m::v::output ->
    let shape=(Mem.buffer m).shape in
    if List.exists (fun a -> (Mem.buffer a).shape<>shape) (o::v::output) then invalid_arg "indirect tensor shapes differ";
    let reads=ref (bytes m) and writes=ref (read_values output) in
    let cell x at=Mem.addresses (Mem.at (Mem.buffer x) (List.map Z.of_int at)) in
    let rec visit rev = function
      | n::dims -> for i=0 to n-1 do visit (i::rev) dims done
      | [] -> let at=List.rev rev in
        if is_active m at then (
          reads := List.rev_append (cell o at) !reads;
          let target = address b o at in
          if load then reads := List.rev_append target !reads else (
            reads := List.rev_append (cell v at) !reads; writes := List.rev_append target !writes))
        else if load then reads := List.rev_append (cell v at) !reads in
    visit [] shape; accessed !reads !writes
    | _ -> invalid_arg "missing indirect operands" in
  let args=values [base;offsets;mask;data] in
  match destination with
  | None -> issue_on ctx op (point path op) C.async_pipe args footprint rest
  | Some dst ->
      let id=result op and ty=shaped ctx (result op) in
      let descriptor=like_buffer ctx ty and read=load_value ctx ty.element and other_cell=tensor_cell ctx ty.element in
      allocate ctx op (point ~part:"tensor allocation" ~synthetic:true path op) ~space:0 id [var dst] descriptor
        (issue ctx op (point path op) S (args@[var id]) footprint
           (scalar ctx op id (args@[var id]) (function
             | [b;o;m;other;out] -> C.VTensor (Mem.buffer out,fun at ->
                 if is_active m at then read (address b o at)
                 else other_cell other at)
             | _ -> invalid_arg "missing gather destination") rest))

let dps ctx path (op : M.operation) rest =
  let inputs,destination = dps_operands op in
  let rec pure_node (node : M.operation) =
    if not (List.mem node.opcode ["linalg.yield";"linalg.index"]) && not (String.starts_with ~prefix:"arith." node.opcode)
       && not (List.mem node.opcode ["math.exp";"math.log";"math.sqrt";"math.absf"]) then
      error node "unsupported effect in a structured computation region";
    List.iter (List.iter (fun b -> List.iter pure_node b.M.body)) node.regions in
  List.iter (List.iter (fun b -> List.iter pure_node b.M.body)) op.regions;
  let opcode=op.opcode in
  let reads_init args = match opcode,args with
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
      let descriptor = like_buffer ctx ty in
      let storage = point ~part:"tensor allocation" ~synthetic:true path op in
      allocate ctx op storage ~space:0 id [var destination] descriptor
        (issue ctx op origin S (values (inputs @ [destination;id])) footprint
          (scalar ctx op id (values (inputs @ [id])) (computed_tensor ctx op inputs) rest))
  | [] ->
      if (shaped ctx destination).kind<>M.Memref then invalid_arg "expected a memref destination";
      let pipe = if op.opcode="hivm.hir.vbrc" && space (shaped ctx destination).space=2 then use_pipe ctx C.Device.MTE2
        else if List.mem op.opcode vector_ops then use_pipe ctx C.Device.V
        else if ctx.launch.hfusion then C.async_pipe else C.scalar_pipe in
      issue_on ctx op origin pipe (values (inputs @ [destination;destination])) footprint rest
  | _ -> invalid_arg "multiple destination results are unsupported"

let matrix_macro ctx path (op : M.operation) rest =
  let inputs,destination,events=match attribute op "operandSegmentSizes" with
    | `List [`Int 1;`Int 1;`Int 1;`Int 1;`Int 1;`Int 1;`Int 1;`Int 7;`Int 0;`Int 0] ->
        List.take 6 op.operands,List.nth op.operands 6,List.drop 7 op.operands
    | _ -> let ins,dst=dps_operands op in ins,dst,[] in
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
      let flag stage mode from_ to_ id rest =
        prepend ~point:(part stage) (fun next -> C.Sync(mode,from_,C.Data to_,id,next)) rest in
      let optional stage mode from_ to_ operand rest =
        let enabled=fresh ctx and event=fresh ctx in
        let yes=scalar ctx op event [var operand] (unary (fun v -> C.VEvent (Mem.dimension (Mem.integer v))))
          (flag stage mode from_ to_ (var event) (terminal C.End)) in
        scalar ctx op enabled [var operand] (unary (fun v -> C.VBool (not (Z.equal (Mem.integer v) Z.minus_one))))
          {command=C.Branch(var enabled,yes.command,C.End,rest.command);points=child 0 yes @ child 2 rest} in
      let wrap before after finish rest =
        before (issue ctx op (part "load") MTE1 (values [a;b;m;k;n]) load
          (after (sync "signal_loaded" LocalSet
             (sync "wait_loaded" LocalWait
                (issue ctx op (part "compute") M (values [init;m;n;destination]) compute (finish rest)))))) in
      (match events with
       | [] -> wrap Fun.id Fun.id Fun.id rest
       | [wa;wb;sa;sb;db;back0;back1] ->
           let dma=use_pipe ctx MTE2 and back=C.Literal (C.VEvent 0) in
           let code=wrap
             (fun body -> optional "wait_a" LocalWait dma transfer wa
                 (optional "wait_b" LocalWait dma transfer wb (flag "wait_matrix" LocalWait matrix transfer back body)))
             (fun body -> optional "release_a" LocalSet transfer dma sa (optional "release_b" LocalSet transfer dma sb body))
             (flag "release_matrix" LocalSet matrix transfer back) rest in
           scalar ctx op (fresh ctx) (values [db;back0;back1]) (fun vs ->
             if not (List.for_all (fun v -> Z.equal (Mem.integer v) Z.minus_one) vs) then
               raise (C.Prefix_boundary "matrix transfer uses explicit double buffering");
             C.VBool true) code
       | _ -> invalid_arg "invalid matrix synchronization arguments")
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
  let send=mode=C.BlockSet in
  let peers=if cross then List.filter_map (fun (s:Launch.stream) ->
    let edge=if send then ctx.stream.id,s.id else s.id,ctx.stream.id in
    if List.mem edge (Option.get ctx.launch.edges) then Some s else None) ctx.launch.streams else [] in
  let paired=peers<>[] && List.for_all (fun (s:Launch.stream) ->
    s.location.block=ctx.stream.location.block && (s.location.core=C.Device.Cube)<>(ctx.stream.location.core=C.Device.Cube)) peers in
  let emit flag = prepend ~point:(point path op) (fun next -> if paired then
    C.Peer_sync (send,List.map (fun (s:Launch.stream) -> s.id) peers,source,target,flag,next)
    else C.Sync (mode,source,target,flag,next)) rest in
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

let function_types (block : M.block) =
  let types = Hashtbl.create 32 in
  let rec visit (b : M.block) =
    List.iter (fun (id,ty) -> Hashtbl.add types id ty) b.arguments;
    List.iter (fun (op : M.operation) ->
      List.iter (fun (id,ty) -> Hashtbl.add types id ty) op.results;
      List.iter (List.iter visit) op.regions) b.body in
  visit block;
  types,Hashtbl.fold (fun id _ n -> max (id+1) n) types 0

let rec lower_block ?(loop_body=false) ctx path (block : M.block) =
  let operations = List.mapi (fun i op -> i,op) block.body in
  let counters = List.filter_map (fun (_,op) ->
    if op.M.opcode="hivm.hir.multi_buffer_counter" then (
      if ctx.depth=0 || op.operands<>[] || bits ctx (result op)<>64 then
        error op "expected an i64 counter inside a loop";
      Some (result op)) else None) operations in
  let rec rotates (op:M.operation) =
    if op.opcode="hivm.hir.pointer_cast" then (match attribute op "operandSegmentSizes" with
      | `List [`Int n;_] -> n>1
      | _ -> List.length op.operands > 1+List.length (List.filter Option.is_none (shaped ctx (result op)).shape))
    else not (List.mem op.opcode ["scf.for";"scf.while"]) &&
      List.exists (List.exists (fun (b:M.block) -> List.exists rotates b.body)) op.regions in
  let counters=if counters=[] && loop_body && List.exists rotates block.body then [fresh ctx] else counters in
  let rotation=match counters with id::_ -> Some id | [] -> ctx.rotation in
  let inner={ctx with rotation} in
  let code=List.fold_right (fun (i,op) rest ->
    try checked op (fun () -> lower_op inner (path @ [i]) op rest) with
    | Source.Error (span,message) when ctx.partial ->
        let reason=Source.describe span ^ ": " ^ message in
        scalar inner op (fresh inner) [] (fun _ -> raise (C.Prefix_boundary reason)) (terminal C.End))
    operations (terminal C.End) in
  ctx.next<-inner.next; ctx.pipes<-inner.pipes;
  if counters=[] then code else prepend (fun rest -> C.Block_counter (counters,rest)) code

and lower_op ctx path (op : M.operation) rest =
  let args = values op.operands and origin = point path op in
  let block region b =
    let nested = List.mem op.opcode ["scf.for";"scf.while"] in
    let inner = {ctx with depth=ctx.depth + Bool.to_int nested} in
    let code = lower_block ~loop_body:nested inner (path @ [region;0]) b in
    ctx.next <- inner.next; ctx.pipes <- inner.pipes; code in
  match op.opcode,op.operands,op.regions with
  | "hivm.hir.multi_buffer_counter",[],[] -> rest
  | "hivm.hir.debug",[_],[] when attribute op "debugtype"=`String "print" ->
      issue ctx op origin S args (fun vs -> accessed (read_values vs) []) rest
  | ("vector.transfer_read"|"vector.transfer_write"|"ave.hir.masked_store"|"ave.hir.vload"|"ave.hir.store_with_stride"),_,_ ->
      let read=op.results<>[] in
      let transfer result_index=Mlir_vector.transfer ~result_index ~ast:ctx.ast ~types:ctx.types ~op
          ~load_value:(load_value ctx) () in
      let reads=List.mapi (fun i (id,_) -> id,transfer i) op.results in
      let rest=List.fold_right (fun (id,fn) -> scalar ctx op id args (fun vs -> (snd (fn vs)) ())) reads rest in
      let footprints=if read then List.map snd reads else [transfer 0] in
      issue ctx op origin S args (fun vs ->
        let cells=List.concat_map (fun fn -> fst (fn vs)) footprints in
        if read then accessed cells [] else accessed [] cells) rest
  | "ave.hir.plt",[v],[] ->
      (match op.results with [(mask,_);(remainder,_)] ->
        let width=Mlir_vector.length (Mlir_vector.dimensions (shaped ctx mask)) in
        scalar ctx op mask [var v] (unary (fun n -> C.VLanes (Array.init width (fun i ->
          C.VBool (Z.lt (Z.of_int i) (Mem.integer n))))))
          (scalar ctx op remainder [var v] (unary (fun n -> C.VInt (Z.sub (Mem.integer n) (Z.of_int width)))) rest)
       | _ -> invalid_arg "invalid predicate result count")
  | "ave.hir.vintlv",[a;b],[] ->
      (match op.results with [(lo,_);(hi,_)] ->
        let width=Mlir_vector.length (Mlir_vector.dimensions (shaped ctx lo)) in
        let half start=binary (fun a b -> C.VLanes (Array.init width (fun i ->
          Mlir_vector.lane (if i mod 2=0 then a else b) (start+i/2)))) in
        scalar ctx op lo (values [a;b]) (half 0) (scalar ctx op hi args (half (width/2)) rest)
       | _ -> invalid_arg "invalid interleave result count")
  | _,_,_ when (match op.results with [id,_] -> (match type_of ctx id with
      | M.Shaped {kind=Vector;_} -> true | _ -> false) | _ -> false) ->
      scalar ctx op (result op) args (Mlir_vector.compute ~ast:ctx.ast ~types:ctx.types ~op) rest
  | "hivm.hir.custom",_,_ -> indirect_atomic ctx path op rest
  | "hivm.hir.pointer_cast",_,_ -> pointer ctx op rest
  | "memref.extract_strided_metadata",[src],_ ->
      let rank=List.length (shaped ctx src).shape in
      if List.length op.results<>2+2*rank then invalid_arg "invalid strided metadata result count";
      List.fold_right (fun (i,(id,_)) -> scalar ctx op id args (unary (fun v ->
        let b=Mem.buffer v in
        if i=0 then C.VBuffer {b with shape=[];strides=[];offset=Z.zero}
        else C.VInt (if i=1 then b.offset else if i<2+rank then Z.of_int (List.nth b.shape (i-2))
                    else List.nth b.strides (i-2-rank)))))
        (List.mapi (fun i x -> i,x) op.results) rest
  | ("affine.min" | "affine.max" | "affine.apply"),_,_ ->
      scalar ctx op (result op) args (affine op) rest
  | "annotation.mark",_,_ when op.results=[] -> rest
  | "hivm.hir.set_mask_norm",[],_ | "hivm.hir.set_ctrl",[],_ ->
      issue ctx op origin S [] (fun _ -> accessed [] []) rest
  | "hfusion.print",_,_ -> issue ctx op origin S args (fun args -> accessed (read_values args) []) rest
  | ("hfusion.indirect_load" | "hfusion.indirect_store"),_,_ -> indirect ctx path op rest
  | "func.return",_,_ -> terminal (if ctx.parents=[] then C.Return args else C.Yield args)
  | ("scf.yield" | "scf.condition"),_,_ -> terminal (C.Yield args)
  | "func.call",_,_ ->
      let entry = J.to_string (attribute op "callee") in
      let parents = ctx.entry::ctx.parents in
      if List.mem entry parents then invalid_arg ("recursive call to " ^ entry);
      let body = M.entry ctx.ast entry in
      let types,next = function_types body in
      let inner = {ctx with entry;parents;depth=0;types;next;rotation=None} in
      let callee = lower_block inner [] body in
      ctx.pipes <- inner.pipes;
      let task = match attribute op "hivm.pipe",attribute op "vector_function",attribute op "hivm.vector_function" with
        | `Null,`Null,`Null -> None
        | pipe,_,_ ->
            if op.results<>[] then invalid_arg "asynchronous call with SSA results";
            let pipe = if pipe=`Null then C.Device.V else Launch.pipe (enum pipe) in
            let id = register ctx.registry.accesses (op.opcode,fun _ -> invalid_arg "call footprint is evaluated by its body") in
            Some (use_pipe ctx pipe,id) in
      let params = List.map2 (fun (id,_) arg -> id,arg) body.arguments args in
      let points = match task with
        | Some _ -> [[],origin]
        | None ->
            let frame = ctx.entry,path,ctx.depth,entry in
            List.map (fun (p,s) -> 0::p,{s with frames=frame::s.frames}) callee.points in
      {command=C.Call_values (params,List.map fst op.results,task,callee.command,rest.command);
       points=points @ child 1 rest}
  | "scf.while",_,[[before];[after]] ->
      let initial = List.map2 (fun (id,_) arg -> id,arg) before.arguments args in
      let test = block 0 before and body = block 1 after in
      {command=C.While_values (initial,List.map fst after.arguments,List.map fst op.results,
                               test.command,body.command,rest.command);
       points=child 0 test @ child 1 body @ child 2 rest}
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
  | ("memref.alloc" | "memref.alloca" | "tensor.empty"),_,_ ->
      let id = result op in
      let ty = shaped ctx id in
      let make=Mem.descriptor ctx.ast ty in
      let descriptor dims = make (Mem.dimensions ty.shape dims) () in
      let origin = if ty.kind=M.Tensor then {origin with synthetic=true} else origin in
      allocate ctx op origin ~space:(space ty.space) id args descriptor rest
  | ("memref.subview" | "memref.reinterpret_cast" | "memref.cast" | "bufferization.to_tensor"
     | "bufferization.to_memref" | "bufferization.to_buffer"),_,_ -> lower_view ctx op rest
  | ("tensor.expand_shape" | "tensor.collapse_shape" | "memref.expand_shape" | "memref.collapse_shape"),_,_ ->
      reshape ctx op rest
  | ("tensor.extract_slice" | "tensor.insert_slice"),_,_ -> tensor_slice ctx path op rest
  | "tensor.extract",src::_,_ ->
      let cells = function src::indices -> Mem.addresses (Mem.at (Mem.buffer src) (List.map Mem.integer indices))
        | _ -> invalid_arg "missing tensor source" in
      let cell=tensor_cell ctx (shaped ctx src).element in
      issue ctx op origin S args (fun vs -> accessed (cells vs) [])
        (scalar ctx op (result op) args (function v::indices ->
           C.VDeferred (lazy (cell v (List.map (fun i -> Z.to_int (Mem.integer i)) indices)))
           | _ -> invalid_arg "missing tensor source") rest)
  | "tensor.insert",_::dst::indices,_ ->
      let id = result op in
      let ty = shaped ctx id in
      let descriptor=like_buffer ctx ty and cell=tensor_cell ctx ty.element in
      let footprint = function dst::out::indices ->
        let b = Mem.buffer dst in
        let replaced = Mem.addresses (Mem.at b (List.map Mem.integer indices)) in
        accessed (List.filter (fun a -> not (List.mem a replaced)) (Mem.addresses b)) (bytes out)
        | _ -> invalid_arg "missing tensor.insert destination" in
      allocate ctx op (point ~part:"tensor allocation" ~synthetic:true path op) ~space:0 id [var dst] descriptor
        (issue ctx op origin S (values (dst::id::indices)) footprint
           (scalar ctx op id (var id::args) (function out::value::dst::indices ->
              let inserted=List.map (fun v -> Mem.dimension (Mem.integer v)) indices in
              C.VTensor (Mem.buffer out,fun at -> if at=inserted then value else cell dst at)
            | _ -> invalid_arg "missing tensor.insert operand") rest))
  | ("memref.dim" | "tensor.dim"),_,_ ->
      scalar ctx op (result op) args (binary (fun b axis ->
        let length = List.nth (Mem.buffer b).shape (Mem.dimension (Mem.integer axis)) in
        C.VInt (Z.of_int length))) rest
  | ("linalg.copy" | "memref.copy"),[_;_],_ when op.results=[] ->
      issue_on ctx op origin (if ctx.launch.hfusion then C.async_pipe else C.scalar_pipe) args copy rest
  | "bufferization.materialize_in_destination",_,_ ->
      issue ctx op origin S args copy rest
  | "hivm.hir.load",[_;_],_ when op.results=[] -> issue ctx op origin MTE2 args copy rest
  | "hivm.hir.load",[src;dst;_;left],_ when op.results=[] &&
      attribute op "operandSegmentSizes"=`List [`Int 1;`Int 1;`Int 1;`Int 1;`Int 0;`Int 0] &&
      enum (attribute op "pad_mode")="PadValue" ->
      issue ctx op origin MTE2 (values [src;dst;left]) (function
        | [src;dst;left] when Z.sign (Mem.integer left)>=0 -> accessed (bytes src) (bytes dst)
        | _ -> invalid_arg "invalid padded load") rest
  | "hivm.hir.nd2nz",[_;_],_ when op.results=[] -> issue ctx op origin MTE2 args nd2nz rest
  | "hivm.hir.copy",[src;dst],_ when op.results=[] ->
      let pipe=match space (shaped ctx src).space,space (shaped ctx dst).space with
        | 6,2 -> C.Device.MTE3 | 6,6 -> V | _ -> invalid_arg "unsupported device copy address spaces" in
      issue ctx op origin pipe args copy rest
  | "hivm.hir.fixpipe",[src;dst],_ when op.results=[] &&
      attribute op "dual_dst_mode"=`String "#hivm.fixpipe_dual_dst_mode<ROW_SPLIT>" ->
      if space (shaped ctx src).space<>5 || space (shaped ctx dst).space<>6 then
        invalid_arg "row split expects a CC input and UB destinations";
      let targets=List.init 2 (fun i -> C.Input (device_bank ctx (Some (C.Device.Vector i)) "#hivm.address_space<ub>")) in
      issue ctx op origin FIX args (binary (fun src dst ->
        let src=Mem.buffer src and dst=Mem.buffer dst in
        match dst.shape with [r;c] ->
          accessed (nz_rectangle src (2*r) c)
            (List.concat_map (fun bank -> Mem.addresses {dst with storage=Some bank}) targets)
        | _ -> invalid_arg "row split requires a two-dimensional destination")) rest
  | "hivm.hir.load",[src;dst;_],_ when op.results=[] &&
      attribute op "operandSegmentSizes"=`List [`Int 1;`Int 1;`Int 1;`Int 0;`Int 0;`Int 0] &&
      enum (attribute op "pad_mode")="PadValue" ->
      issue ctx op origin MTE2 (values [src;dst]) copy rest
  | "hivm.hir.store",[_;_],_ when op.results=[] -> issue ctx op origin MTE3 args copy rest
  | "hivm.hir.fixpipe",[src;dst],_ when op.results=[] &&
         attribute op "dual_dst_mode"=`Null && (shaped ctx src).shape=(shaped ctx dst).shape ->
      issue ctx op origin FIX args copy rest
  | ("hivm.hir.load" | "hivm.hir.store"),[source;destination],_ when op.results<>[] ->
      let id = result op in
      let ty = shaped ctx id in
      let descriptor=like_buffer ctx ty in
      let storage = point ~part:"tensor allocation" ~synthetic:true path op in
      allocate ctx op storage ~space:0 id [var destination] descriptor
        (issue ctx op origin S (values [source;id]) copy rest)
  | "memref.store",_::dst::_,_ ->
      let ty=(shaped ctx dst).element in
      let element=Mem.type_of ctx.ast ty in
      let footprint = function v::dst::indices ->
        let cells = Mem.addresses (Mem.at (Mem.buffer dst) (List.map Mem.integer indices)) in
        (match element,v with
         | M.Shaped {kind=Memref;_},C.VBuffer b -> Effect.perform (C.Store_descriptor (List.hd cells,b))
         | (M.Integer _ | M.Float _),_ when local_cells ctx cells ->
             Effect.perform (C.Store_local (cells,ty,v))
         | _ -> ());
        accessed [] cells
      | _ -> invalid_arg "missing scalar store operands" in
      issue ctx op origin S args footprint rest
  | "memref.load",_::_,_ ->
      let read=load_value ctx (type_name ctx (result op)) in
      let cells = function src::indices ->
        Mem.addresses (Mem.at (Mem.buffer src) (List.map Mem.integer indices))
        | _ -> invalid_arg "missing scalar load operands" in
      issue ctx op origin S args (fun vs -> accessed (cells vs) [])
        (scalar ctx op (result op) args (fun vs -> read (cells vs)) rest)
  | "memref.atomic_rmw",_::dst::_,_ ->
      let read=load_value ctx (shaped ctx dst).element in
      let cells = function _::target::indices -> Mem.addresses (Mem.at (Mem.buffer target) (List.map Mem.integer indices))
        | _ -> invalid_arg "missing atomic operands" in
      issue ctx op origin S args (fun vs -> let cells=cells vs in accessed cells cells)
        (scalar ctx op (result op) args (fun vs -> read (cells vs)) rest)
  | ("hivm.hir.set_flag" | "hivm.hir.wait_flag" | "hivm.hir.sync_block_set" | "hivm.hir.sync_block_wait"),_,_ ->
      synchronization ctx path op rest
  | "hfusion.barrier",[],[] ->
      prepend ~point:origin (fun rest -> C.Core_barrier rest) rest
  | "hivm.hir.pipe_barrier",[],_ ->
      let pipe = match enum (attribute op "pipe") with
        | "PIPE_ALL" -> C.All | name -> C.Pipe (use_pipe ctx (Launch.pipe name)) in
      prepend ~point:origin (fun rest -> C.Barrier (pipe,rest)) rest
  | "hivm.hir.get_block_idx",[],_ ->
      let value=C.VInt (Z.of_int ctx.stream.location.block) in
      scalar ctx op (result op) [] (fun _ -> value) rest
  | "hivm.hir.get_sub_block_idx",[],_ ->
      let index = match ctx.stream.location.core with C.Device.Cube -> 0 | Vector n -> n in
      scalar ctx op (result op) [] (fun _ -> C.VInt (Z.of_int index)) rest
  | "hivm.hir.mmadL1",_,_ when op.results=[] -> matrix_macro ctx path op rest
  | opcode,_,_ when List.mem opcode linalg_ops || List.mem opcode hfusion_ops || List.mem opcode vector_ops ||
                       (List.mem opcode ["hivm.hir.mmadL1";"hivm.hir.matmul"] && op.results<>[]) -> dps ctx path op rest
  | opcode,_,_ when String.starts_with ~prefix:"arith." opcode -> lower_arith ctx op rest
  | _ -> invalid_arg "unsupported operation for Core Language lowering"

let lower_with_launch ?(allow_prefix=false) ast (launch : Launch.t) =
  let registry = {banks=Hashtbl.create 8;initial=Array.of_list (List.map (initial_bytes ast) launch.storages);
                  scalars=Queue.create ();accesses=Queue.create ()} in
  let stream (s : Launch.stream) =
    let types,next = function_types s.ast in
    let ctx = {ast;types;launch;stream=s;registry;next;pipes=[];entry=s.entry;parents=[];depth=0;rotation=None;
               partial=allow_prefix;uses_async=ref false} in
    let code = lower_block ctx [] s.ast in
    let pipes = match s.pipes with
      | Some pipes ->
          if not (List.for_all (fun p -> List.mem p pipes) ctx.pipes) then
            invalid_arg (s.entry ^ " uses a pipe missing from its launch configuration");
          pipes
      | None -> ctx.pipes in
    let pipes = List.filter ((<>) C.Device.S) pipes |> List.map pipe_id |> List.sort_uniq compare in
    let pipes = if !(ctx.uses_async) then C.async_pipe::pipes else pipes in
    C.{id=s.id;params=s.arguments;pipes;body=code.command},
    List.map (fun (site,point) -> (s.id,site),point) code.points in
  let streams,sources = List.split (List.map stream launch.streams) in
  let scalars = Array.of_seq (Queue.to_seq registry.scalars) in
  let accesses = Array.of_seq (Queue.to_seq registry.accesses) in
  let edges=Option.value launch.edges ~default:[] in
  let program = C.{streams;scalar_eval=(fun _ id -> scalars.(id));
                   footprint=(fun _ _ id -> snd accesses.(id));
                   block_edge=(fun source _ target _ -> List.mem (source,target) edges)} in
  {ast_digest=ast.digest;launch;program;sources=validate_sources ast launch (List.concat sources);
   operation_names=Array.map fst accesses}

let lower ?entry ?configuration ast =
  lower_with_launch ast (Launch.bind ?entry ?configuration ast)
