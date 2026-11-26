open Stdlib
open Unified_interpreter
module C = Core_lang
module D = C.Device
module M = Hivm_module
module V = Device_value
module Shared = Mlir_lowering
module Launch = Mlir_launch
module Mem = Mlir_memory
module J = Yojson.Safe.Util

type t = {
  ast : M.t;
  launch : Launch.t;
  program : D.program;
  memory : V.memory;
  bindings : (string * V.value) list;
  sources : ((int * int list) * Shared.source) list;
}

let indexed_ops = ["hivm.hir.indirect_load";"hivm.hir.indirect_store";
                   "hfusion.indirect_load";"hfusion.indirect_store";"vector.maskedstore"]

let required (launch : Launch.t) =
  let rec block (b : M.block) = List.exists (fun (op : M.operation) ->
    List.mem op.opcode indexed_ops || List.exists (List.exists block) op.regions) b.body in
  List.exists (fun (s : Launch.stream) -> block s.ast) launch.streams

let dtype = function
  | "i1" -> D.I1 | "i8" -> I8 | "i16" -> I16 | "i32" -> I32 | "i64" | "index" -> I64
  | "f16" -> F16 | "f32" -> F32 | s -> invalid_arg ("unsupported device type " ^ s)

let i64 z = Z.to_int64 (Mlir_scalar.signed 64 z)
let index n = D.Int (I64,i64 n)
let index_int n = index (Z.of_int n)
let name stream id = Printf.sprintf "stream%d.ssa%d" stream id

type code = { instructions : D.instruction list; points : (int list * Shared.source) list }

let single ?point instruction =
  {instructions=[instruction];points=Option.to_list (Option.map (fun p -> [0],p) point)}

let join codes =
  let _,rev_instructions,rev_points = List.fold_left (fun (index,instructions,points) code ->
    let origins = List.map (function (i::path),p -> (index+i)::path,p | _ -> assert false) code.points in
    index+List.length code.instructions,List.rev_append code.instructions instructions,
    List.rev_append origins points) (0,[],[]) codes in
  {instructions=List.rev rev_instructions;points=List.rev rev_points}

let empty = {instructions=[];points=[]}

let strip_yield (b : M.block) = match List.rev b.body with
  | {opcode="scf.yield";operands;_} :: body -> {b with body=List.rev body},operands
  | _ -> b,[]

let binop = function
  | "arith.addi" -> D.Add | "arith.subi" -> Sub | "arith.muli" -> Mul
  | "arith.divsi" -> Div | "arith.remsi" -> Rem | "arith.minsi" -> Min | "arith.maxsi" -> Max
  | "arith.andi" -> And | "arith.ori" -> Or | "arith.xori" -> Xor | "arith.shrsi" -> Shr
  | opcode -> invalid_arg ("unsupported device scalar operation " ^ opcode)

let comparison = function
  | 0 -> D.Eq | 1 -> Ne | 2 -> Lt | 3 -> Le | 4 -> Gt | 5 -> Ge
  | _ -> invalid_arg "unsupported device comparison predicate"

let tensor_comparison = function
  | "veq" -> D.Eq | "vne" -> Ne | "vlt" -> Lt | "vle" -> Le | "vgt" -> Gt | "vge" -> Ge
  | _ -> invalid_arg "unsupported HFusion comparison predicate"

let slice_operands static dynamic =
  let dynamic = ref dynamic in
  let convert n = if not (Z.equal n (Z.of_int64 Int64.min_int)) then index n else
    match !dynamic with
    | x::rest -> dynamic := rest; x
    | [] -> invalid_arg "missing dynamic slice component" in
  let offsets,sizes,steps = static in
  let offsets = List.map convert offsets in
  let sizes = List.map convert sizes in
  let steps = List.map convert steps in
  if !dynamic<>[] then invalid_arg "extra dynamic slice components";
  offsets,sizes,steps

let seed memory (s : Launch.storage) =
  let bank = V.Allocation s.name in
  Hashtbl.add memory bank (Bytes.make s.bytes '\000');
  Option.iter (fun (element,values) ->
    let ty = dtype element in
    let width = D.bits ty in
    let view = V.{bank;ty;bit=0;shape=[|List.length values|];strides=[|1|]} in
    List.iteri (fun i value ->
      let raw = if V.is_float ty then V.encode ty (J.to_number value) else
        match value with `Bool b -> if b then 1L else 0L | _ -> i64 (Launch.z_of_json value) in
      V.write_bits memory view (i*width) raw) values) s.initial

let launch_bindings ast (launch : Launch.t) memory =
  List.concat_map (fun (stream : Launch.stream) ->
    List.map (fun (id,v) ->
      let type_name = List.assoc id stream.ast.arguments in
      let value = match v with
        | C.VInt n -> V.scalar (dtype type_name) (i64 n)
        | VBool b -> V.scalar I1 (if b then 1L else 0L)
        | VFloat f -> let ty = dtype type_name in V.scalar ty (V.encode ty f)
        | VBuffer ({storage=Some (Input i);_} as b) ->
            let ty = Mem.shaped ast type_name in
            let element = dtype ty.element in
            let bank = V.Allocation (List.nth launch.storages i).name in
            let bit = Mem.dimension (Z.add (Z.mul (Z.of_int 8) (Z.of_int b.base_bytes))
                                       (Z.mul (Z.of_int (D.bits element)) b.offset)) in
            let shape = Array.of_list b.shape and strides = Array.of_list (List.map Z.to_int b.strides) in
            let view = V.{bank;ty=element;bit;shape;strides} in
            if ty.kind=M.Vector then (
              let lanes = Array.init (V.product shape) (fun i ->
                V.read_bits memory view (V.index view (V.coords shape i))) in
              V.vec element lanes)
            else V.View view
        | _ -> invalid_arg "unsupported device launch binding" in
      name stream.id id,value) stream.arguments) launch.streams

let lower_with_launch ast (launch : Launch.t) =
  if launch.capacity<>1 then invalid_arg "device scheduling requires flag capacity 1";
  let memory = Hashtbl.create 12 in
  List.iter (seed memory) launch.storages;
  let bindings = launch_bindings ast launch memory in
  let register_bytes = ref 256 in
  let stream (stream : Launch.stream) =
    let types = Hashtbl.create 32 and owned_tensors = Hashtbl.create 8 and pipes = ref [] in
    let rec scan (b : M.block) =
      List.iter (fun (id,ty) -> Hashtbl.add types id ty) b.arguments;
      List.iter (fun (op : M.operation) ->
        List.iter (fun (id,ty) -> Hashtbl.add types id ty) op.results;
        if List.mem op.opcode ["tensor.empty";"tensor.insert";"linalg.fill";"hfusion.arange";
                              "hfusion.compare";"hfusion.indirect_load";"hivm.hir.indirect_load"] then
          List.iter (fun (id,_) -> Hashtbl.add owned_tensors id ()) op.results;
        List.iter (List.iter scan) op.regions) b.body in
    scan stream.ast;
    let name = name stream.id in
    let expr id = D.Var (name id) and type_name id = Hashtbl.find types id in
    let use pipe = if not (List.mem pipe !pipes) then pipes := pipe :: !pipes in
    let rec block path (body : M.block) =
      List.mapi (fun i op -> Shared.checked op (fun () -> lower (path @ [i]) op)) body.body |> join
    and lower path (op : M.operation) =
      let attr = Shared.attribute op and point = Shared.point path op in
      let loc instruction = single ~point instruction in
      let args = List.map expr op.operands in
      let result expression = loc (D.Let (name (Shared.result op),expression)) in
      let emit pipe command = use pipe; loc (D.Issue (pipe,op.opcode,[command])) in
      let memory_op pipe command =
        if op.results<>[] then invalid_arg "device memory operation requires bufferized operands";
        emit pipe command in
      match op.opcode,args,op.regions with
      | "func.return",[],_ | "scf.yield",[],_ -> empty
      | "scf.if",[test],[[yes];no] when op.results=[] ->
          let yes = block (path@[0;0]) yes in
          let no = match no with [] -> empty | [b] -> block (path@[1;0]) b
            | _ -> invalid_arg "invalid branch region" in
          {instructions=[D.If (test,yes.instructions,no.instructions)];
           points=([0],point) ::
             (List.map (fun (p,source) -> 0::0::p,source) yes.points @
              List.map (fun (p,source) -> 0::1::p,source) no.points)}
      | "scf.for",lo::hi::step::init,[[body]] ->
          if attr "unsignedCmp"<>`Null then invalid_arg "unsigned induction comparisons are unsupported";
          (match body.arguments with
           | (iv,iv_type)::arguments when List.length arguments=List.length init &&
                                          List.length arguments=List.length op.results ->
               let body,yield = strip_yield body in
               let loop = block (path@[0;0]) body in
               let carried = List.map2 (fun (id,_) initial -> name id,initial) arguments init in
               let assign = List.map2 (fun (out,_) (carried,_) -> D.Let (name out,expr carried))
                   op.results arguments in
               {instructions=D.For {index=name iv;index_type=dtype iv_type;lo;hi;step;carried;
                                    body=loop.instructions;yield=List.map expr yield} :: assign;
                points=([0],point) :: List.map (fun (p,source) -> 0::p,source) loop.points}
           | _ -> invalid_arg "mismatched device loop-carried values")
      | "arith.constant",[],_ ->
          let ty = dtype (type_name (Shared.result op)) in
          result (match attr "value" with
            | `String text when V.is_float ty -> D.Float (ty,float_of_string text)
            | `Bool value -> D.Int (ty,if value then 1L else 0L)
            | j -> D.Int (ty,i64 (Launch.z_of_json j)))
      | "arith.select",[cond;yes;no],_ -> result (D.Select (cond,yes,no))
      | "arith.cmpi",[a;b],_ -> result (D.Compare (comparison (J.to_int (attr "predicate")),a,b))
      | cast,[arg],_ when List.mem cast ["arith.index_cast";"arith.extsi";"arith.extui";"arith.trunci"] ->
          if cast="arith.extui" then invalid_arg "unsigned extensions require an explicit device conversion";
          if cast="arith.extsi" && type_name (List.hd op.operands)="i1" then
            invalid_arg "sign extension of a predicate requires an explicit device conversion";
          result (D.Cast (dtype (type_name (Shared.result op)),arg))
      | opcode,[a;b],_ when List.mem opcode Mlir_scalar.binary_opcodes ->
          (match attr "overflowFlags" with `Null | `String "#arith.overflow<none>" -> ()
            | _ -> invalid_arg "unsupported device overflow flags");
          result (D.Binary (binop opcode,a,b))
      | "hivm.hir.get_block_idx",[],_ -> result (D.Cast (dtype (type_name (Shared.result op)),D.Block))
      | "hivm.hir.get_sub_block_idx",[],_ -> result (D.Cast (dtype (type_name (Shared.result op)),D.Subblock))
      | ("memref.cast" | "bufferization.to_tensor"),[source],_ -> result source
      | "memref.subview",source::dynamic,_ ->
          let offsets,sizes,steps = slice_operands (Shared.slice_attributes op) dynamic in
          let ty = Mem.shaped ast (type_name (Shared.result op)) in
          if List.length sizes<>List.length ty.shape then invalid_arg "rank-changing device subview";
          result (D.Slice (source,offsets,sizes,steps))
      | "memref.reinterpret_cast",source::dynamic,_ ->
          (match slice_operands (Shared.slice_attributes op) dynamic with
           | [offset],sizes,steps -> result (D.Reinterpret_view (source,offset,sizes,steps))
           | _ -> invalid_arg "expected one reinterpret offset")
      | "tensor.empty",dynamic,_ ->
          let ty = Mem.shaped ast (type_name (Shared.result op)) in
          let dims = ref dynamic in
          let dimensions = List.map (function Some n -> index_int n | None -> match !dims with
            | d::rest -> dims := rest; d | [] -> invalid_arg "missing dynamic tensor dimension") ty.shape in
          if !dims<>[] then invalid_arg "extra dynamic tensor dimensions";
          result (D.Empty_tensor (dtype ty.element,dimensions))
      | "tensor.extract",source::indices,_ -> result (D.Tensor_get (source,indices))
      | "tensor.insert",value::source::indices,_ -> result (D.Tensor_insert (value,indices,source))
      | "linalg.fill",[scalar;out],_ when op.results<>[] -> result (D.Tensor_fill (scalar,out))
      | "linalg.fill",[scalar;out],_ -> memory_op S (D.Fill (out,scalar))
      | "hfusion.arange",_,_ ->
          let declared = Mem.shaped ast (type_name (Shared.result op)) in
          let rank = List.length declared.shape in
          (match List.rev args with output::rest ->
            let offset,strides = match List.rev rest with
              | values when List.length values=rank -> index_int 0,values
              | offset::strides when List.length strides=rank -> offset,strides
              | _ -> invalid_arg "range operands do not match tensor rank" in
            result (D.Tensor_range (offset,strides,output))
          | _ -> invalid_arg "missing tensor range destination")
      | "hfusion.compare",[a;b;out],_ ->
          let predicate = tensor_comparison (Shared.enum (attr "compare_fn")) in
          result (D.Tensor_compare (predicate,a,b,out))
      | "bufferization.materialize_in_destination",[src;dst],_ ->
          let command = if Hashtbl.mem owned_tensors (List.hd op.operands) then D.Copy_tensor (src,dst)
            else D.Copy (src,dst) in
          memory_op S command
      | "memref.copy",[src;dst],_ -> memory_op S (D.Copy (src,dst))
      | "hivm.hir.load",[src;dst],_ -> memory_op MTE2 (D.Copy (src,dst))
      | "hivm.hir.store",[src;dst],_ -> memory_op MTE3 (D.Copy (src,dst))
      | "memref.store",element::target::indices,_ -> memory_op S (D.Store (target,indices,element))
      | "memref.load",source::indices,_ -> loc (D.Let (name (Shared.result op),D.Read (source,indices,1)))
      | ("hivm.hir.indirect_load" | "hfusion.indirect_load"),[source;offsets;a;b;c],_ ->
          let source_type = Mem.shaped ast (type_name (List.hd op.operands)) in
          if List.length source_type.shape<>1 then invalid_arg "indirect source must be one-dimensional";
          let mask,other,destination = if op.generic && op.opcode="hivm.hir.indirect_load" then b,c,a else a,b,c in
          let pipe = if op.opcode="hivm.hir.indirect_load" then D.V else D.S in
          if op.results=[] then memory_op pipe (D.Indirect_load (source,offsets,mask,other,destination))
          else (
            let id = name (Shared.result op) in
            loc (D.Let (id,D.Gather_tensor (source,offsets,mask,other,destination))))
      | ("hivm.hir.indirect_store" | "hfusion.indirect_store"),[a;offsets;b;c],_ ->
          let generic = op.generic && op.opcode="hivm.hir.indirect_store" in
          let destination_id = List.nth op.operands (if generic then 0 else 3) in
          let destination_type = Mem.shaped ast (type_name destination_id) in
          if List.length destination_type.shape<>1 then invalid_arg "indirect destination must be one-dimensional";
          let source,mask,destination = if generic then b,c,a else a,b,c in
          let pipe = if op.opcode="hivm.hir.indirect_store" then D.V else D.S in
          let source_id = List.nth op.operands (if generic then 2 else 0) in
          let command = if Hashtbl.mem owned_tensors source_id then D.Scatter_tensor (source,offsets,mask,destination)
            else D.Indirect_store (source,offsets,mask,destination) in
          memory_op pipe command
      | "vector.maskedstore",destination::operands,_ ->
          (match List.rev operands,List.rev op.operands with
           | value::mask::indices, data::_ ->
               let ty = Mem.shaped ast (type_name data) in
               let element = dtype ty.element in
               let lanes = match ty.shape with [Some n] -> n | _ -> invalid_arg "expected fixed-width vector" in
               register_bytes := max !register_bytes ((lanes*D.bits element+7)/8);
               let mask = D.Layout_cast ({element=I1;lane_bits=D.bits element},mask) in
               memory_op S (D.Masked_store (destination,List.rev indices,mask,value,Norm))
           | _ -> invalid_arg "invalid masked store operands")
      | ("hivm.hir.set_flag" | "hivm.hir.wait_flag"),_,_ ->
          let source = Launch.pipe (Shared.enum (attr "set_pipe")) in
          let target = Launch.pipe (Shared.enum (attr "wait_pipe")) in
          use source; use target;
          let event = match args,attr "static_event_id" with
            | [arg],`Null -> arg
            | [],`String raw ->
                let label = Shared.enum (`String raw) and prefix = "EVENT_ID" in
                if not (String.starts_with ~prefix label) then invalid_arg "invalid static event id";
                index (Z.of_string (String.sub label (String.length prefix) (String.length label-String.length prefix)))
            | _ -> invalid_arg "expected one static or dynamic event id" in
          loc (if op.opcode="hivm.hir.set_flag" then D.Set (Local,source,target,event)
               else D.Wait (Local,source,target,event))
      | "hivm.hir.pipe_barrier",[],_ ->
          let pipes = match Shared.enum (attr "pipe") with "PIPE_ALL" -> []
          | p -> let pipe = Launch.pipe p in use pipe; [pipe] in
          loc (D.Barrier pipes)
      | _ -> invalid_arg "unsupported operation for device lowering" in
    let code = block [] stream.ast in
    let declared = Option.value stream.pipes ~default:!pipes |> List.sort_uniq compare in
    if not (List.for_all (fun p -> List.mem p declared) !pipes) then
      invalid_arg (stream.entry ^ " uses a pipe missing from its launch configuration");
    let rec set_pipes = function
      | D.Barrier [] -> D.Barrier declared
      | D.For loop -> D.For {loop with body=List.map set_pipes loop.body}
      | D.If (cond,yes,no) -> D.If (cond,List.map set_pipes yes,List.map set_pipes no)
      | instruction -> instruction in
    D.{location=stream.location;body=List.map set_pipes code.instructions},
    List.map (fun (path,point) -> (stream.id,path),point) code.points in
  let instructions,sources = List.split (List.map stream launch.streams) in
  let name = String.concat "," (List.map (fun (s : Launch.stream) -> s.entry) launch.streams) in
  let program = D.{name;register_bytes= !register_bytes;streams=instructions} in
  {ast;launch;program;memory;bindings;sources=List.concat sources}
