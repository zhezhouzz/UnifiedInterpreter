open Parser
module E = Extracted_semantics.Unified_semantics

let supported = [
  "arith.constant";"arith.addi";"arith.muli";"arith.divsi";"arith.remsi";
  "arith.extsi";"arith.index_cast";"arith.addf";"arith.maxnumf";
  "tensor.empty";"tensor.expand_shape";"tensor.collapse_shape";
  "memref.alloc";"memref.copy";"memref.reinterpret_cast";
  "bufferization.to_tensor";"bufferization.materialize_in_destination";
  "linalg.fill";"linalg.transpose";"linalg.matmul";"linalg.broadcast";
  "linalg.elemwise_binary";"linalg.elemwise_unary";"linalg.reduce";"linalg.yield";
  "hfusion.cast";"hivm.hir.vadd";"hivm.hir.vsub";"hivm.hir.vmul";"hivm.hir.vdiv";
  "hivm.hir.vexp";"hivm.hir.vln";"hivm.hir.vbrc";"hivm.hir.vreduce";
  "hivm.hir.vcast";"hivm.hir.mmadL1";"scf.for";"scf.yield";"func.return"
]

let fail op message = Source.fail op.span message
let attributes op =
  let allowed = match op.opcode with
    | "arith.constant" -> ["value"]
    | "linalg.matmul" -> ["input_precison"]
    | "linalg.elemwise_binary" | "linalg.elemwise_unary" -> ["fun"]
    | "linalg.transpose" -> ["permutation"]
    | "linalg.reduce" | "linalg.broadcast" -> ["dimensions"]
    | "hfusion.cast" -> ["cast";"round_mode"]
    | "hivm.hir.vbrc" -> ["broadcast_dims"]
    | "hivm.hir.vreduce" -> ["kind";"reduce_dims"]
    | "hivm.hir.mmadL1" -> ["b_transpose"]
    | "memref.reinterpret_cast" -> ["offsets";"sizes";"strides"]
    | "tensor.expand_shape" -> ["reassociation";"static_output_shape"]
    | "tensor.collapse_shape" -> ["reassociation"]
    | "bufferization.to_tensor" | "bufferization.materialize_in_destination" ->
        ["restrict";"writable"]
    | _ -> [] in
  List.iter (fun (key,_) -> if not (List.mem key allowed) then
    fail op ("unsupported attribute " ^ key)) op.attributes;
  let check_enum key tag values =
    if not (List.mem (Runner.enum op key tag) values) then fail op ("unsupported " ^ key) in
  match op.opcode with
  | "linalg.elemwise_binary" -> check_enum "fun" "linalg.binary_fn" ["add";"sub";"mul";"div"]
  | "linalg.elemwise_unary" -> check_enum "fun" "linalg.unary_fn" ["exp";"log"]
  | "hfusion.cast" ->
      List.iter (fun (key,tag,value) -> if List.mem_assoc key op.attributes then
        check_enum key tag [value])
        ["cast","hfusion.type_fn","cast_signed";"round_mode","hfusion.round_mode","rint"]
  | "linalg.matmul" ->
      (match List.assoc_opt "input_precison" op.attributes with
      | None | Some (`String "ieee") -> () | _ -> fail op "unsupported input precision")
  | "hivm.hir.vreduce" ->
      if not (List.mem (Runner.attribute op "kind") [`String "sum";`String "max"])
      then fail op "unsupported reduction kind"
  | _ -> ()

let structured_shape op inputs dst =
  let bad () = fail op "unsupported structured operand shapes or types" in
  let f16 = E.Float16Type and f32 = E.Float32Type in
  let shaped = function ShapedType ("tensor",sh,ty) -> sh,ty | _ -> bad () in
  let out,ty = shaped dst in
  if not (List.mem (List.length out) [1;2]) || List.exists ((>=) 0) out then bad ();
  let dims name = Runner.dims name op in
  let same = function ScalarType t -> t = ty
    | ShapedType ("tensor",sh,t) -> sh = out && t = ty | _ -> false in
  let valid = match op.opcode,inputs with
    | "linalg.fill",[ScalarType t] -> t = ty
    | ("linalg.elemwise_binary" | "hivm.hir.vadd" | "hivm.hir.vsub" |
       "hivm.hir.vmul" | "hivm.hir.vdiv"),[a;b] -> ty = f32 && same a && same b
    | ("linalg.elemwise_unary" | "hivm.hir.vexp" | "hivm.hir.vln"),[src] ->
        let sh,t = shaped src in sh = out && t = f32 && ty = f32
    | ("hfusion.cast" | "hivm.hir.vcast"),[src] ->
        let sh,t = shaped src in sh = out && t = f32 && ty = f16
    | "linalg.transpose",[src] ->
        let sh,t = shaped src in List.length sh = 2 && List.rev sh = out &&
          t = ty && dims "permutation" = [1;0]
    | "linalg.broadcast",[src] ->
        let sh,t = shaped src in
        (match sh,out with [m],[m';_] -> m = m' && t = ty && dims "dimensions" = [1] | _ -> false)
    | "hivm.hir.vbrc",[ScalarType t] -> t = f32 && ty = f32 && dims "broadcast_dims" = []
    | "hivm.hir.vbrc",[src] ->
        let sh,t = shaped src in
        (match sh,out with [m;1],[m';_] ->
          m = m' && t = f32 && ty = f32 && dims "broadcast_dims" = [1] | _ -> false)
    | "linalg.reduce",[src] ->
        let sh,t = shaped src in
        (match sh,out with [m;_],[m'] -> m = m' && t = f32 && ty = f32 && dims "dimensions" = [1] | _ -> false)
    | "hivm.hir.vreduce",[src] ->
        let sh,t = shaped src in
        (match sh,out with [m;_],[m';1] -> m = m' && t = f32 && ty = f32 && dims "reduce_dims" = [1] | _ -> false)
    | ("linalg.matmul" | "hivm.hir.mmadL1"),a::b::rest ->
        let ash,at = shaped a and bsh,bt = shaped b in
        let bsh = if Runner.flag "b_transpose" op then List.rev bsh else bsh in
        let controls = if op.opcode = "linalg.matmul" then rest = []
          else rest = [ScalarType (scalar_type "i1");ScalarType E.IndexType;
            ScalarType E.IndexType;ScalarType E.IndexType] in
        (match ash,bsh,out with [m;k],[k';n],[m';n'] ->
          controls && m=m' && n=n' && k=k' && at=f16 && bt=f16 && ty=f32 | _ -> false)
    | _ -> false in
  if not valid then bad ()

let kernel ?stage p =
  (match stage with
  | None | Some ("hfusion" | "hivm" | "mixed") -> ()
  | Some _ -> invalid_arg "invalid execution stage");
  let rec block env local ops =
    List.fold_left (fun (env,local) op ->
      if not (List.mem op.opcode supported) then fail op ("unsupported operation " ^ op.opcode);
      if op.stage <> Stage.of_opcode op.opcode then fail op "operation stage mismatch";
      (match stage with
      | Some "hfusion" when op.stage = Stage.HIVM ->
          fail op "HIVM operation in HFusion input"
      | Some "hivm" when op.stage = Stage.HFusion -> fail op "HFusion operation in HIVM input"
      | _ -> ());
      attributes op;
      let lookup name = match List.assoc_opt name env with
        | Some ty -> ty | None -> fail op ("undefined SSA value " ^ name) in
      if List.map lookup op.operands <> op.operand_types then fail op "operand type mismatch";
      if op.outputs <> [] then begin
        let dst = match op.outputs with [name] -> lookup name | _ -> fail op "expected one output" in
        if op.result_type <> Some dst then fail op "result/destination type mismatch";
        if op.inputs @ op.outputs <> op.operands then fail op "invalid structured operand groups";
        structured_shape op (List.map lookup op.inputs) dst
      end;
      (match op.opcode with
      | "scf.for" ->
          (match op.operand_types,op.region_arguments with
          | [ScalarType a;ScalarType b;ScalarType c],[_,ScalarType d]
            when a=b && b=c && c=d -> ()
          | _ -> fail op "invalid for signature")
      | "linalg.reduce" ->
          if List.map snd op.region_arguments <> [ScalarType E.Float32Type;ScalarType E.Float32Type]
          then fail op "invalid reduction region arguments";
          (match List.rev op.region with
          | yield :: _ when yield.opcode = "linalg.yield" && yield.operand_types = [ScalarType E.Float32Type] -> ()
          | _ -> fail op "reduction must yield one f32")
      | "tensor.empty" | "memref.alloc" ->
          (match op.result_type with Some (ShapedType (_,sh,_))
            when sh <> [] && List.for_all ((<) 0) sh && op.operands = [] -> ()
          | _ -> fail op "invalid allocation shape")
      | "memref.copy" ->
          (match op.operand_types with [ShapedType ("memref",_,_) as a;b] when a=b -> ()
          | _ -> fail op "copy type mismatch")
      | "memref.reinterpret_cast" ->
          (match op.result_type with Some (ShapedType ("memref",sh,_)) ->
            if sh <> Runner.dims "sizes" op || List.length sh <> List.length (Runner.dims "strides" op)
            then fail op "reinterpret view shape mismatch"
          | _ -> fail op "invalid reinterpret result")
      | "tensor.expand_shape" | "tensor.collapse_shape" ->
          (match op.operand_types,op.result_type with
          | [ShapedType ("tensor",src,ty)],Some (ShapedType ("tensor",dst,ty')) ->
              let groups = Yojson.Safe.Util.(Runner.attribute op "reassociation" |> to_list
                |> List.map (fun row -> row |> to_list |> List.map to_int)) in
              let expanded,collapsed = if op.opcode = "tensor.expand_shape" then dst,src else src,dst in
              if ty <> ty' || not (E.valid_reassociation expanded collapsed groups)
              then fail op "invalid reassociation"
          | _ -> fail op "invalid reshape types")
      | "func.return" | "scf.yield" ->
          if op.operands <> [] then fail op "unsupported terminator operands"
      | _ -> ());
      let names = List.map fst op.region_arguments in
      if List.length names <> List.length (List.sort_uniq String.compare names)
      then fail op "duplicate region argument";
      ignore (block (op.region_arguments @ env) names op.region);
      match op.result,op.result_type with
      | Some name,Some ty ->
          if List.mem name local then fail op ("duplicate SSA result " ^ name);
          (name,ty)::env,name::local
      | None,None -> env,local
      | _ -> fail op "result count mismatch"
    ) (env,local) ops
  in
  ignore (block p.arguments (List.map fst p.arguments) p.body)

let program ?stage p =
  let expected = List.init 16 (fun i ->
    let ty = if i = 0 then ScalarType (scalar_type "i64")
      else if i = 1 || i = 2 then ShapedType ("memref",[-1],scalar_type "i8")
      else if List.mem i [3;4;5;7] then ShapedType ("memref",[-1],E.Float16Type)
      else if List.mem i [6;8] then ShapedType ("memref",[-1],E.Float32Type)
      else if i = 9 then ScalarType E.Float32Type
      else ScalarType (scalar_type "i32") in
    "%arg" ^ string_of_int i,ty) in
  if p.arguments <> expected then invalid_arg "unsupported attention entry signature";
  kernel ?stage p
