open Parser
module E = Extracted_semantics.Unified_semantics

let supported = [
  "arith.constant";"arith.addi";"arith.muli";"arith.divsi";"arith.remsi";
  "arith.subi";"arith.maxsi";"arith.minsi";"arith.cmpi";
  "scf.if";"memref.subview";"tensor.extract_slice";
  "arith.extsi";"arith.index_cast";"arith.addf";"arith.maxnumf";"arith.maximumf";"arith.ori";
  "tensor.empty";"tensor.expand_shape";"tensor.collapse_shape";
  "tensor.insert";"tensor.extract";"tensor.insert_slice";
  "memref.alloc";"memref.copy";"memref.reinterpret_cast";"memref.load";
  "bufferization.to_tensor";"bufferization.materialize_in_destination";
  "linalg.fill";"linalg.transpose";"linalg.matmul";"linalg.broadcast";
  "linalg.elemwise_binary";"linalg.elemwise_unary";"linalg.reduce";"linalg.yield";
  "hfusion.cast";"hivm.hir.vadd";"hivm.hir.vsub";"hivm.hir.vmul";"hivm.hir.vdiv";
  "hivm.hir.vexp";"hivm.hir.vln";"hivm.hir.vbrc";"hivm.hir.vreduce";
  "hivm.hir.vcast";"hivm.hir.mmadL1";"scf.for";"scf.yield";"func.return";
  "hfusion.arange";"hfusion.compare";"hfusion.select";"hfusion.bitcast";"hfusion.elemwise_binary";
  "hfusion.print";"hfusion.indirect_load";"hfusion.indirect_store";
  "hivm.hir.varange";"hivm.hir.vtranspose";"hivm.hir.vcmp";"hivm.hir.vsel";"hivm.hir.bitcast";
  "hivm.hir.vand";"hivm.hir.vshr";"hivm.hir.vmin";"hivm.hir.vmax";
  "hivm.hir.debug";"hivm.hir.indirect_load";"hivm.hir.indirect_store"
]

let fail op message = Source.fail op.span message
let is_integer ty = E.integer_width ty <> None
let i1 = scalar_type "i1"
let index = ScalarType E.IndexType

let attributes op =
  let allowed = match op.opcode with
    | "arith.constant" -> ["value"]
    | "arith.cmpi" -> ["predicate"]
    | "scf.if" -> ["hivm.unlikely_condition"]
    | "memref.subview" | "tensor.extract_slice" | "tensor.insert_slice"
    | "memref.reinterpret_cast" -> ["offsets";"sizes";"strides"]
    | "linalg.matmul" -> ["input_precision";"input_precison"]
    | "linalg.elemwise_binary" | "linalg.elemwise_unary" | "hfusion.elemwise_binary" -> ["fun"]
    | "linalg.transpose" | "hivm.hir.vtranspose" -> ["permutation"]
    | "linalg.reduce" | "linalg.broadcast" -> ["dimensions"]
    | "hfusion.cast" -> ["cast";"round_mode";"enable_overflow"]
    | "hivm.hir.vcast" -> ["enable_overflow";"enable_saturate";"hivm.unsigned_mode"]
    | "hivm.hir.vbrc" -> ["broadcast_dims"]
    | "hivm.hir.vreduce" -> ["kind";"reduce_dims"]
    | "hivm.hir.mmadL1" -> ["b_transpose"]
    | "hfusion.compare" -> ["compare_fn"]
    | "hivm.hir.vcmp" -> ["compare_mode"]
    | "hfusion.print" -> ["prefix";"hex"]
    | "hivm.hir.debug" -> ["prefix";"hex";"debugtype"]
    | "hfusion.indirect_load" -> ["isVolatile"]
    | "hivm.hir.indirect_load" -> ["isVolatile";"hivm.vf_mode"]
    | "hivm.hir.indirect_store" -> ["hivm.vf_mode"]
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
  | "linalg.elemwise_binary" ->
      check_enum "fun" "linalg.binary_fn" ["add";"sub";"mul";"div";"min_signed";"max_signed"]
  | "linalg.elemwise_unary" -> check_enum "fun" "linalg.unary_fn" ["exp";"log"]
  | "hfusion.cast" ->
      List.iter (fun (key,tag,value) -> if List.mem_assoc key op.attributes then
        check_enum key tag [value])
        ["cast","hfusion.type_fn","cast_signed";"round_mode","hfusion.round_mode","rint"]
  | "hivm.hir.vcast" ->
      if Runner.flag "enable_saturate" op then fail op "unsupported saturating cast";
      if List.mem_assoc "hivm.unsigned_mode" op.attributes then
        check_enum "hivm.unsigned_mode" "hivm.unsigned_mode" ["si2si"]
  | "hfusion.compare" ->
      check_enum "compare_fn" "hfusion.compare_fn" ["veq";"vne";"vlt";"vle";"vgt";"vge"]
  | "hivm.hir.vcmp" ->
      if not (List.mem (Yojson.Safe.Util.to_string (Runner.attribute op "compare_mode"))
        ["eq";"ne";"lt";"le";"gt";"ge"]) then fail op "unsupported compare_mode"
  | "hfusion.elemwise_binary" ->
      check_enum "fun" "hfusion.binary_fn" ["vand";"shrsi";"maxf"]
  | "hivm.hir.debug" ->
      if Runner.attribute op "debugtype" <> `String "print" then fail op "unsupported debug type"
  | "linalg.matmul" ->
      List.iter (fun key -> match List.assoc_opt key op.attributes with
        | None | Some (`String "ieee") -> () | _ -> fail op "unsupported input precision")
        ["input_precision";"input_precison"]
  | "hivm.hir.vreduce" ->
      if not (List.mem (Runner.attribute op "kind") [`String "sum";`String "max"])
      then fail op "unsupported reduction kind"
  | _ -> ()

let bitcast_type src dst =
  let i32 = scalar_type "i32" in
  src = E.Float32Type && dst = i32 || src = i32 && dst = E.Float32Type

let indirect_index_types shape offsets mask =
  let offset_type = function
    | ShapedType ("tensor",dims,ty) ->
        dims = shape && List.mem ty [scalar_type "i32";scalar_type "i64"]
    | _ -> false in
  let mask_type = function
    | ShapedType ("tensor",dims,ty) ->
        dims = shape && List.mem ty [i1;scalar_type "i8"]
    | _ -> false in
  offset_type offsets && Option.fold ~none:true ~some:mask_type mask

let structured_shape op inputs dst =
  let bad () = fail op "unsupported structured operand shapes or types" in
  let f32 = E.Float32Type in
  let shaped = function ShapedType ("tensor",sh,ty) -> sh,ty | _ -> bad () in
  let out,ty = shaped dst in
  if List.exists ((>) 0) out then bad ();
  let dims name = Runner.dims name op in
  let element_type = function
    | ScalarType t -> t
    | ShapedType ("tensor",sh,t) when sh = out -> t
    | _ -> bad () in
  let same v = element_type v = ty in
  let broadcast insert_axes src =
    let sh,t = shaped src in
    let axes = dims (if insert_axes then "dimensions" else "broadcast_dims") in
    let indexed = List.mapi (fun i n -> i,n) out in
    let expected =
      if insert_axes then
        List.filter_map (fun (i,n) -> if List.mem i axes then None else Some n) indexed
      else List.map (fun (i,n) -> if List.mem i axes then 1 else n) indexed in
    t = ty && sh = expected && List.for_all (fun i -> i >= 0 && i < List.length out) axes &&
    List.length axes = List.length (List.sort_uniq Int.compare axes) in
  let valid = match op.opcode,inputs with
    | "linalg.fill",[ScalarType t] -> t = ty
    | ("linalg.elemwise_binary" | "hivm.hir.vadd" | "hivm.hir.vsub" |
       "hivm.hir.vmul" | "hivm.hir.vdiv" | "hivm.hir.vmin" | "hivm.hir.vmax"),[a;b] ->
      (Numeric.is_float ty || is_integer ty) && same a && same b
  | "hfusion.elemwise_binary",[a;b] ->
      let fn = Runner.enum op "fun" "hfusion.binary_fn" in
      (if fn = "maxf" then Numeric.is_float ty else is_integer ty) && same a && same b
  | ("hivm.hir.vand" | "hivm.hir.vshr"),[a;b] -> is_integer ty && same a && same b
    | ("linalg.elemwise_unary" | "hivm.hir.vexp" | "hivm.hir.vln"),[src] ->
        ty = f32 && same src
    | ("hfusion.cast" | "hivm.hir.vcast"),[src] ->
        let sh,t = shaped src in
        sh = out && ((is_integer t && (is_integer ty || ty = f32)) ||
          (t = f32 && E.matrix_element_type ty) ||
          (op.opcode = "hfusion.cast" && Numeric.is_float t && Numeric.is_float ty))
  | ("linalg.transpose" | "hivm.hir.vtranspose"),[src] ->
        let sh,t = shaped src in List.length sh = 2 && List.rev sh = out &&
          t = ty && dims "permutation" = [1;0]
  | "linalg.broadcast",[src] -> broadcast true src
  | "hivm.hir.vbrc",[ScalarType t] -> t = ty && dims "broadcast_dims" = []
  | "hivm.hir.vbrc",[src] -> broadcast false src
  | ("hfusion.arange" | "hivm.hir.varange"),bounds ->
      let rank = List.length out in
      rank > 0 && (List.length bounds = rank || List.length bounds = rank + 1) &&
      List.for_all ((=) index) bounds && (is_integer ty || Numeric.is_float ty)
  | ("hfusion.compare" | "hivm.hir.vcmp"),[a;b] ->
      ty = i1 && element_type a = element_type b
  | ("hfusion.select" | "hivm.hir.vsel"),[mask;a;b] ->
      element_type mask = i1 && same a && same b
  | "hfusion.bitcast",[src] ->
      let sh,t = shaped src in sh = out && bitcast_type t ty
  | ("hfusion.indirect_load" | "hivm.hir.indirect_load"),
      [ShapedType ("memref",[_],t);offsets;mask;fallback] ->
      t = ty && fallback = dst && indirect_index_types out offsets (Some mask)
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
          controls && m=m' && n=n' && k=k' &&
          E.matrix_element_type at && at=bt && ty=f32 | _ -> false)
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
      let result = result_type op in
      if List.length op.results > 1 && op.opcode <> "scf.for" then fail op "unexpected multiple results";
      if op.outputs <> [] then begin
        let dst = match op.outputs with [name] -> lookup name | _ -> fail op "expected one output" in
        if op.inputs @ op.outputs <> op.operands then fail op "invalid structured operand groups";
        let inputs = List.map lookup op.inputs in
        match op.opcode,dst with
        | ("hfusion.indirect_store" | "hivm.hir.indirect_store"),
          ShapedType ("memref",[_],ty) ->
            (match inputs with
            | ShapedType ("tensor",shape,source_ty)::offsets::masks ->
                let mask = match masks with [] -> None | [mask] -> Some mask
                  | _ -> fail op "invalid indirect store mask" in
                if op.results <> [] || source_ty <> ty || not (indirect_index_types shape offsets mask)
                then fail op "invalid indirect store types"
            | _ -> fail op "invalid indirect store types")
        | ("linalg.fill" | "hivm.hir.vbrc" | "hfusion.arange" | "hivm.hir.varange" |
           "hfusion.indirect_load" | "hivm.hir.indirect_load"),ShapedType ("memref",shape,ty) ->
            if op.results <> [] then fail op "memref destination returns no value";
            structured_shape op inputs (ShapedType ("tensor",shape,ty))
        | _ ->
            if result <> Some dst then fail op "result/destination type mismatch";
            structured_shape op inputs dst
      end;
      let index_exprs ?(signed=false) key rank =
        let entries = Runner.expressions op key in
        if List.length entries <> rank then fail op "slice rank mismatch";
        List.iter (function
          | Static n when not signed && (n < 0 || key = "strides" && n = 0) ->
              fail op "invalid static slice index"
          | Dynamic name when lookup name <> index -> fail op "slice index must have index type"
          | _ -> ()) entries;
        entries in
      let check_sizes shape sizes =
        List.iter2 (fun dim size -> match size with
          | Static n when dim <> -1 && dim <> n -> fail op "slice result shape mismatch"
          | _ -> ()) shape sizes in
      let check_dynamic operands groups =
        let dynamic = List.filter_map (function Dynamic name -> Some name | Static _ -> None)
            (List.concat groups) in
        if operands <> dynamic then fail op "slice operand groups mismatch" in
      (match op.opcode with
      | "arith.addi" | "arith.subi" | "arith.maxsi" | "arith.minsi"
      | "arith.muli" | "arith.divsi" | "arith.remsi" | "arith.cmpi" | "arith.ori" ->
          (match op.operand_types with
          | [ScalarType ty;ScalarType ty'] when ty = ty' && E.integer_width ty <> None ->
              let result_ty = if op.opcode = "arith.cmpi" then i1 else ty in
              if result <> Some (ScalarType result_ty) then fail op "invalid integer result type";
              if op.opcode = "arith.cmpi" then
                (match Runner.attribute op "predicate" with
                | `Int n when n >= 0 && n <= 9 -> ()
                | _ -> fail op "invalid comparison predicate")
          | _ -> fail op "invalid integer operands")
      | "scf.if" ->
          if op.operand_types <> [ScalarType i1] ||
             op.results <> [] || op.region_arguments <> [] then fail op "invalid if signature"
      | "tensor.extract" | "memref.load" ->
          let kind = if op.opcode = "memref.load" then "memref" else "tensor" in
          (match op.operand_types,result with
          | ShapedType (source_kind,shape,ty)::coords,Some (ScalarType result_ty)
            when kind = source_kind && ty = result_ty &&
                 coords = List.map (fun _ -> index) shape -> ()
          | _ -> fail op "invalid element read types")
      | "tensor.insert" ->
          (match op.operand_types,result with
          | ScalarType ty::(ShapedType ("tensor",shape,elem) as target)::coords,Some result
            when ty = elem && target = result && coords = List.map (fun _ -> index) shape -> ()
          | _ -> fail op "invalid tensor.insert types")
      | "memref.subview" | "tensor.extract_slice" ->
          let kind = if op.opcode = "memref.subview" then "memref" else "tensor" in
          (match op.operand_types,result with
          | ShapedType (source_kind,shape,ty)::_,Some (ShapedType (target_kind,target,ty'))
            when kind = source_kind && kind = target_kind && ty = ty' &&
                 List.length shape = List.length target ->
              let rank = List.length shape in
              let offsets = index_exprs "offsets" rank and sizes = index_exprs "sizes" rank
              and strides = index_exprs "strides" rank in
              check_sizes target sizes;
              check_dynamic (List.tl op.operands) [offsets;sizes;strides]
          | _ -> fail op "unsupported slice types or rank reduction")
      | "tensor.insert_slice" ->
          (match op.operand_types,result,op.operands with
          | ShapedType ("tensor",source,ty)::(ShapedType ("tensor",target,ty') as dest)::_,
            Some result,_::_::operands
            when result = dest && ty = ty' && List.length source = List.length target ->
              let rank = List.length target in
              let offsets = index_exprs "offsets" rank and sizes = index_exprs "sizes" rank
              and strides = index_exprs "strides" rank in
              check_sizes source sizes;
              check_dynamic operands [offsets;sizes;strides]
          | _ -> fail op "invalid tensor.insert_slice types")
      | "scf.for" ->
          let carried_types = List.map snd op.results in
          (match op.operand_types,op.region_arguments with
          | ScalarType a::ScalarType b::ScalarType c::inits,(_,ScalarType d)::args
            when a=b && b=c && c=d && is_integer a && inits=carried_types &&
                 List.map snd args=carried_types -> ()
          | _ -> fail op "invalid for signature");
          (match List.rev op.region with
          | yield::_ when yield.opcode = "scf.yield" && yield.operand_types = carried_types -> ()
          | _ when carried_types = [] -> ()
          | _ -> fail op "invalid scf.yield signature")
      | "linalg.reduce" ->
          if List.map snd op.region_arguments <> [ScalarType E.Float32Type;ScalarType E.Float32Type]
          then fail op "invalid reduction region arguments";
          (match List.rev op.region with
          | yield :: _ when yield.opcode = "linalg.yield" && yield.operand_types = [ScalarType E.Float32Type] -> ()
          | _ -> fail op "reduction must yield one f32")
      | "tensor.empty" | "memref.alloc" ->
          (match result with Some (ShapedType (_,sh,_))
            when List.for_all ((<=) 0) sh && op.operands = [] -> ()
          | _ -> fail op "invalid allocation shape")
      | "memref.copy" ->
          (match op.operand_types with [ShapedType ("memref",_,_) as a;b] when a=b -> ()
          | _ -> fail op "copy type mismatch")
      | "memref.reinterpret_cast" ->
          (match op.operand_types,result with
          | ShapedType ("memref",_,src)::_ , Some (ShapedType ("memref",sh,dst)) when src=dst ->
              let rank = List.length sh in
              let offset = index_exprs ~signed:true "offsets" 1
              and sizes = index_exprs "sizes" rank
              and strides = index_exprs ~signed:true "strides" rank in
              check_sizes sh sizes;
              check_dynamic (List.tl op.operands) [offset;sizes;strides]
          | _ -> fail op "invalid reinterpret result")
      | "hivm.hir.bitcast" ->
          (match op.operand_types,result with
          | [ShapedType ("tensor",a,src)],Some (ShapedType ("tensor",b,dst))
            when a=b && bitcast_type src dst -> ()
          | _ -> fail op "invalid bitcast types")
      | "hfusion.print" | "hivm.hir.debug" ->
          (match op.operand_types,Runner.attribute op "prefix" with
          | [ScalarType _ | ShapedType ("tensor",_,_)],`String _ when op.results = [] -> ()
          | _ -> fail op "invalid print operands")
      | "tensor.expand_shape" | "tensor.collapse_shape" ->
          (match op.operand_types,result with
          | [ShapedType ("tensor",src,ty)],Some (ShapedType ("tensor",dst,ty')) ->
              let groups = Yojson.Safe.Util.(Runner.attribute op "reassociation" |> to_list
                |> List.map (fun row -> row |> to_list |> List.map to_int)) in
              let expanded,collapsed = if op.opcode = "tensor.expand_shape" then dst,src else src,dst in
              if ty <> ty' || List.exists ((>) 0) (expanded @ collapsed) ||
                 not (E.valid_reassociation expanded collapsed groups)
              then fail op "invalid reassociation"
          | _ -> fail op "invalid reshape types")
      | "func.return" ->
          if op.operands <> [] then fail op "unsupported terminator operands"
      | _ -> ());
      let names = List.map fst op.region_arguments in
      if List.length names <> List.length (List.sort_uniq String.compare names)
      then fail op "duplicate region argument";
      ignore (block (op.region_arguments @ env) names op.region);
      if op.else_region <> [] && op.opcode <> "scf.if" then fail op "unexpected else region";
      ignore (block env [] op.else_region);
      List.fold_left (fun (env,local) (name,ty) ->
          if List.mem name local then fail op ("duplicate SSA result " ^ name);
          (name,ty)::env,name::local
      ) (env,local) op.results
    ) (env,local) ops
  in
  ignore (block p.arguments (List.map fst p.arguments) p.body)

let attention_abi ?stage p =
  let abi = Attention_abi.parse p in
  kernel ?stage p;
  abi

let program ?stage p = ignore (attention_abi ?stage p)
