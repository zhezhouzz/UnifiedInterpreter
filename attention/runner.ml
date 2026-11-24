module E = Extracted_semantics.Unified_semantics
module H = Handlers
open Parser

type value =
  | Int of E.mlir_type * E.z
  | Float of E.mlir_type * float
  | Tensor of H.tensor
  | View of Numeric.cell E.runtime_tensor
  | Memref of int * int list * E.mlir_type

type context = {
  state : H.state ref;
  mutable steps : int;
  max_steps : int;
  mutable current : operation option;
  mutable pid : int;
  mutable calls : int;
  mutable loops : (string * int) list;
  trace : Yojson.Basic.t -> unit;
}

let error op message = Source.fail op.span message
let scalar_type = Parser.scalar_type
let attribute op key =
  match List.assoc_opt key op.attributes with
  | Some value -> value | None -> error op ("missing attribute " ^ key)
let dims key op =
  match List.assoc_opt key op.attributes with
  | None -> []
  | Some json -> Yojson.Safe.Util.(json |> to_list |> List.map to_int)
let flag key op =
  match List.assoc_opt key op.attributes with
  | Some (`Bool value) -> value
  | Some (`Int n) -> n <> 0
  | _ -> false
let enum op key tag =
  let json = attribute op key in
  if Yojson.Safe.Util.(json |> member "enum" |> to_string) <> tag
  then error op ("unexpected enum for " ^ key);
  Yojson.Safe.Util.(json |> member "value" |> to_string)
let last_type (op : operation) =
  match result_type op with
  | Some (ShapedType (_,sh,ty)) -> sh,ty
  | _ -> error op "missing shaped result type"
let check_result_shape op shape =
  let expected,_ = last_type op in
  if List.length expected <> List.length shape ||
     not (List.for_all2 (fun declared actual -> declared = -1 || declared = actual) expected shape)
  then error op "runtime slice result shape mismatch"
let trailing_scalar (op : operation) =
  match result_type op with
  | Some (ScalarType ty) -> ty | _ -> error op "missing scalar result type"
let get env op name =
  match List.assoc_opt name env with
  | Some v -> v | None -> error op ("undefined SSA value " ^ name)
let integer op = function Int (ty,x) -> ty,x | _ -> error op "expected integer"
let floating op = function Float (ty,x) -> ty,x | _ -> error op "expected float"
let scalar op = function
  | Float (ty,x) -> ty,Numeric.Floating x
  | Int (ty,x) -> ty,Numeric.cell_of_z ty x
  | _ -> error op "expected scalar"
let of_cell ty cell =
  if Numeric.is_float ty then Float (ty,Numeric.as_float cell)
  else Int (ty,Numeric.z_of_cell cell)
let index op v = Numeric.int_of_z (snd (integer op v))
let expressions op key =
  Yojson.Safe.Util.(attribute op key |> to_list) |> List.map Parser.index_expr
let index_values env op key =
  expressions op key |> List.map (function
    | Static n -> Numeric.z_of_int n
    | Dynamic name -> snd (integer op (get env op name)))
let indices env op key =
  index_values env op key |> List.map (fun value ->
    let value = Numeric.int_of_z value in
    if value < 0 || (key = "strides" && value = 0) then
      error op ("invalid slice " ^ key);
    value)
let memref op = function Memref (id,sh,ty) -> id,sh,ty | _ -> error op "expected memref"
let tensor op = function
  | Tensor t -> t
  | View view -> Effect.perform (H.Memory ("materialize", E.materialize view))
  | _ -> error op "expected tensor"
let operand op = function
  | (Float _ | Int _) as value -> let ty,x = scalar op value in E.ScalarOperand (ty,x)
  | x -> E.TensorOperand (tensor op x)
let elementwise op dst = function
  | (Float _ | Int _) as value -> let ty,x = scalar op value in E.ElementwiseScalar (ty,x)
  | x ->
      let sh,ty,xs = H.packed (tensor op x) in
      if sh <> E.shape0 dst then error op "elementwise operand shape mismatch";
      E.ElementwiseTensor (ty,xs)
let common request = Effect.perform (H.Common request)
let hivm request = Tensor (Effect.perform (H.HIVM request))
let hfusion request = Tensor (Effect.perform (H.HFusion request))
let vector op request = Tensor (Effect.perform (H.Vector (op.stage,request)))

let emit_call ctx entry extra =
  ctx.calls <- ctx.calls + 1;
  let fields = ["program_id", `Int ctx.pid; "entry", `String entry;
    "loops", `Assoc (List.map (fun (name,i) -> name,`Int i) ctx.loops)] in
  let fields = match ctx.current with
    | None -> ("ir_stage",`Null) :: fields
    | Some op ->
        ("ir_stage",`String (Stage.name op.stage)) ::
        ("file",`String op.span.file) :: ("line",`Int op.span.start.line) ::
        ("column",`Int op.span.start.column) :: ("opcode",`String op.opcode) ::
        ("result", match op.results with
          | [] -> `Null | [name,_] -> `String name
          | results -> `List (List.map (fun (name,_) -> `String name) results)) :: fields
  in ctx.trace (`Assoc (fields @ extra))

let on_call ctx entry = emit_call ctx entry []

let with_handlers ctx f =
  H.run ~enable_hfusion:false ~enable_hivm:false
    ~state:ctx.state ~on_call:(on_call ctx) f

let with_operation_handlers ctx op f =
  if op.stage <> Stage.of_opcode op.opcode then error op "operation stage mismatch";
  H.run ~enable_hfusion:(op.stage = Stage.HFusion)
    ~enable_hivm:(op.stage = Stage.HIVM)
    ~state:ctx.state ~on_call:(on_call ctx) f

let float_literal x =
  if Float.is_nan x then E.NotANumber else if x = infinity then E.PositiveInfinity
  else if x = neg_infinity then E.NegativeInfinity
  else
    let q = Q.of_float x in
    E.FiniteFloat {E.qnum = Numeric.z_of_big (Q.num q);
      qden = Numeric.positive_of_big (Q.den q)}

let tick ctx op =
  if op.stage <> Stage.of_opcode op.opcode then error op "operation stage mismatch";
  ctx.current <- Some op;
  ctx.steps <- ctx.steps + 1;
  if ctx.steps > ctx.max_steps then error op "execution step budget exhausted"

let bind_results op env values =
  if List.length op.results <> List.length values then error op "operation result count mismatch";
  List.fold_left2 (fun env (name,_) value -> (name,value) :: env) env op.results values

let integer64 op v = Numeric.Big.to_int64 (Numeric.big_of_z (snd (integer op v)))

let lane_indices op offsets mask =
  let shape,_,offsets = H.packed (tensor op offsets) in
  let active = match mask with
    | None -> List.map (fun _ -> true) offsets
    | Some value ->
        let mask_shape,_,cells = H.packed (tensor op value) in
        if mask_shape <> shape then error op "indirect access mask shape mismatch";
        List.map (fun x -> Numeric.as_int x <> 0L) cells in
  let lanes = List.map2 (fun offset active ->
    if not active then None else
    let offset = Numeric.as_int offset in
    if offset < 0L || offset > Int64.of_int max_int then error op "indirect offset out of bounds";
    Some [Int64.to_int offset]) offsets active in
  shape,lanes

let debug ctx op value =
  let shape,ty,cells = match value with
    | Int _ | Float _ -> let ty,x = scalar op value in [],ty,[x]
    | _ -> H.packed (tensor op value) in
  let hex = flag "hex" op in
  let show = function
    | Numeric.Integer x when hex ->
        let width = Numeric.width ty in
        let bits = if width = 64 then x else Int64.logand x (Int64.pred (Int64.shift_left 1L width)) in
        `String (Printf.sprintf "0x%Lx" bits)
    | Numeric.Integer x when x >= Int64.of_int min_int && x <= Int64.of_int max_int ->
        `Int (Int64.to_int x)
    | Numeric.Integer x -> `String (Int64.to_string x)
    | Numeric.Floating x when hex && ty = E.Float32Type ->
        `String (Printf.sprintf "0x%08lx" (Int32.bits_of_float x))
    | Numeric.Floating _ when hex -> error op "unsupported hexadecimal float type"
    | Numeric.Floating x when Float.is_finite x -> `Float x
    | Numeric.Floating x -> `String (Printf.sprintf "%g" x)
    | Numeric.Undefined -> error op "read uninitialized tensor element" in
  let prefix = Yojson.Safe.Util.to_string (attribute op "prefix") in
  emit_call ctx "device_print" [
    "prefix",`String prefix;
    "shape",`List (List.map (fun n -> `Int n) shape);
    "values",`List (List.map show cells)]

let rec execute_block ctx env ops =
  match ops with
  | [] -> env, []
  | op :: rest ->
      tick ctx op;
      let run () =
        if List.mem op.opcode ["func.return";"scf.yield";"linalg.yield"] then
          env, List.map (get env op) op.operands
        else if op.opcode = "scf.if" then begin
          let condition = match op.operands with
            | [name] -> snd (integer op (get env op name))
            | _ -> error op "invalid if condition" in
          ignore (execute_block ctx env
            (if condition = E.Z0 then op.else_region else op.region));
          execute_block ctx env rest
        end
        else if op.opcode = "scf.for" then begin
          let values = match op.operands,op.region_arguments with
          | lo::hi::step::inits,(iv,_)::args ->
              let ty,start = integer op (get env op lo) in
              let hty,stop = integer op (get env op hi) in
              let sty,stride = integer op (get env op step) in
              if ty <> hty || ty <> sty || Numeric.Big.sign (Numeric.big_of_z stride) <= 0
              then error op "invalid for bounds or step";
              let rec loop i values =
                if Numeric.Big.compare (Numeric.big_of_z i) (Numeric.big_of_z stop) < 0 then begin
                  tick ctx op;
                  let saved = ctx.loops in
                  ctx.loops <- (iv,Numeric.int_of_z i) :: saved;
                  let bindings = List.map2 (fun (name,_) value -> name,value) args values in
                  let _,values = Fun.protect ~finally:(fun () -> ctx.loops <- saved) (fun () ->
                    execute_block ctx ((iv,Int (ty,i)) :: bindings @ env) op.region) in
                  if List.length args <> List.length values then error op "invalid scf.yield arity";
                  ctx.current <- Some op;
                  let next = common (H.Integer_binary (E.ArithAddI,ty,i,stride)) in
                  if Numeric.Big.compare (Numeric.big_of_z next) (Numeric.big_of_z i) <= 0
                  then error op "loop induction overflow";
                  loop next values
                end else values
              in loop start (List.map (get env op) inits)
          | _ -> error op "unsupported for signature" in
          execute_block ctx (bind_results op env values) rest
        end else
          let value = with_operation_handlers ctx op (fun () -> execute_op ctx env op) in
          execute_block ctx (bind_results op env (Option.to_list value)) rest
      in
      (try run () with
      | H.Semantic_error e ->
          let kind = match e with
            | E.InvalidShape -> "InvalidShape" | E.InvalidDescriptor -> "InvalidDescriptor"
            | E.InvalidMemoryAccess -> "InvalidMemoryAccess" | E.StaticProgramError -> "StaticProgramError"
            | E.ReadUninitialized -> "ReadUninitialized" | E.UndefinedBehavior -> "UndefinedBehavior"
            | E.UnsupportedInstruction -> "UnsupportedInstruction" | E.NumericFailure -> "NumericFailure"
            | E.OutOfFuel -> "OutOfFuel" | E.RuntimeMemoryError _ -> "RuntimeMemoryError" in
          error op (Printf.sprintf "%s: %s (program_id=%d)" op.opcode kind ctx.pid)
      | Invalid_argument s | Failure s -> error op s)

and execute_op ctx env op =
  let lookup = get env op in
  let values = List.map lookup op.operands in
  let some v = Some v in
  let one () = match values with [x] -> x | _ -> error op "expected one operand" in
  let two () = match values with [x;y] -> x,y | _ -> error op "expected two operands" in
  match op.opcode with
  | "arith.constant" ->
      let ty = trailing_scalar op in
      (match attribute op "value" with
      | `String literal when Numeric.is_float ty ->
          let value = if String.starts_with ~prefix:"0x" literal then
              Int32.float_of_bits (Int32.of_string literal) else float_of_string literal in
          let interpreted = common (H.Float_constant (ty,float_literal value)) in
          (* Rational literals do not carry the sign of zero. Preserve the
             parsed sign so a subsequent bitcast observes the IEEE value. *)
          some (Float (ty,if value = 0. then value else interpreted))
      | `Int n -> some (Int (ty,common (H.Integer_constant (ty,Numeric.z_of_int n))))
      | _ -> error op "invalid constant payload")
  | "arith.addi" | "arith.subi" | "arith.maxsi" | "arith.minsi"
  | "arith.muli" | "arith.divsi" | "arith.remsi" | "arith.ori" ->
      let a,b = two () in
      let ty,a = integer op a and ty',b = integer op b in
      if ty <> ty' || ty <> trailing_scalar op then error op "integer type mismatch";
      let operator = match op.opcode with
        | "arith.addi" -> E.ArithAddI | "arith.muli" -> E.ArithMulI
        | "arith.subi" -> E.ArithSubI | "arith.maxsi" -> E.ArithMaxSI
        | "arith.minsi" -> E.ArithMinSI
        | "arith.divsi" -> E.ArithDivSI | "arith.ori" -> E.ArithOrI
        | _ -> E.ArithRemSI in
      some (Int (ty,common (H.Integer_binary (operator,ty,a,b))))
  | "arith.cmpi" ->
      let a,b = two () in
      let ty,a = integer op a and ty',b = integer op b in
      if ty <> ty' then error op "comparison type mismatch";
      let predicate = Yojson.Safe.Util.to_int (attribute op "predicate") in
      some (Int (scalar_type "i1",common (H.Integer_compare (predicate,ty,a,b))))
  | "arith.extsi" | "arith.index_cast" ->
      let src,x = integer op (one ()) and dst = trailing_scalar op in
      let operator = if op.opcode = "arith.extsi" then E.ArithExtSI else E.ArithIndexCast in
      some (Int (dst,common (H.Integer_cast (operator,src,dst,x))))
  | "arith.addf" | "arith.maxnumf" | "arith.maximumf" ->
      let a,b = two () in
      let ty,a = floating op a and ty',b = floating op b in
      if ty <> ty' || ty <> trailing_scalar op then error op "float type mismatch";
      let request = match op.opcode with
        | "arith.addf" -> H.Scalar_binary (E.ScalarAdd,a,b)
        | "arith.maxnumf" -> H.Scalar_binary (E.ScalarMax,a,b)
        | _ -> H.Maximum_float (a,b) in
      some (Float (ty,common request))
  | "tensor.empty" ->
      let sh,ty = last_type op in
      ignore (Tensor_ops.size sh);
      some (Tensor (common (H.Empty (sh,ty))))
  | "tensor.extract" ->
      (match values with
      | src::coordinates ->
          let cell = common (H.Tensor_extract (tensor op src,List.map (index op) coordinates)) in
          some (of_cell (trailing_scalar op) cell)
      | [] -> error op "missing tensor.extract source")
  | "tensor.insert" ->
      (match values with
      | value::dst::coordinates ->
          let _,cell = scalar op value in
          some (Tensor (common (H.Tensor_insert (cell,tensor op dst,List.map (index op) coordinates))))
      | _ -> error op "missing tensor.insert operands")
  | "tensor.extract_slice" ->
      let src = tensor op (lookup (List.hd op.operands)) in
      let sizes = indices env op "sizes" in
      check_result_shape op sizes;
      some (Tensor (common (H.Extract_slice (src,indices env op "offsets",
        sizes,indices env op "strides"))))
  | "tensor.insert_slice" ->
      (match values with
      | src::dst::_ ->
          some (Tensor (common (H.Insert_slice (tensor op src,tensor op dst,
            indices env op "offsets",indices env op "sizes",indices env op "strides"))))
      | _ -> error op "missing tensor.insert_slice operands")
  | "memref.subview" ->
      let id,_,ty = memref op (lookup (List.hd op.operands)) in
      let sizes = indices env op "sizes" in
      check_result_shape op sizes;
      let id = H.memory "sem_memref_subview" (E.sem_memref_subview id
        (indices env op "offsets") sizes (indices env op "strides")) in
      some (Memref (id,sizes,ty))
  | "tensor.expand_shape" | "tensor.collapse_shape" ->
      let src = tensor op (one ()) in
      let target,_ = last_type op in
      let groups = Yojson.Safe.Util.(attribute op "reassociation" |> to_list
        |> List.map (fun row -> row |> to_list |> List.map to_int)) in
      some (Tensor (common (H.Reshape (op.opcode = "tensor.expand_shape",src,target,groups))))
  | "memref.alloc" ->
      let sh,ty = last_type op in
      ignore (Tensor_ops.size sh);
      let id = H.memory "sem_memref_alloc" (E.sem_memref_alloc E.ASDefault ty sh) in
      some (Memref (id,sh,ty))
  | "memref.reinterpret_cast" ->
      let source = lookup (List.hd op.operands) in
      let id,_,ty = memref op source in
      let offset = match index_values env op "offsets" with
        | [offset] -> offset
        | _ -> error op "invalid reinterpret offset" in
      let sh = indices env op "sizes" in
      check_result_shape op sh;
      let strides = index_values env op "strides" in
      let id = H.memory "sem_memref_reinterpret_cast"
          (E.sem_memref_reinterpret_cast id offset sh strides) in
      some (Memref (id,sh,ty))
  | "memref.load" ->
      (match values with
      | src::coordinates ->
          let id,_,ty = memref op src in
          let coordinates = List.map (index op) coordinates in
          if List.exists (fun i -> i < 0) coordinates then error op "negative memref index";
          let cell = H.memory "sem_memref_load" (E.perform (E.Read (id,coordinates))) in
          some (of_cell ty cell)
      | [] -> error op "missing memref.load source")
  | "memref.copy" ->
      let a,b = two () in
      let a,sh,ty = memref op a and b,sh',ty' = memref op b in
      if sh <> sh' || ty <> ty' then error op "copy type mismatch";
      H.memory "sem_memref_copy" (E.sem_memref_copy sh a b); None
  | "bufferization.to_tensor" ->
      let id,sh,ty = memref op (one ()) in
      let access = {E.access_restrict = flag "restrict" op;
        access_writable = flag "writable" op} in
      some (View (H.memory "sem_bufferization_to_tensor"
        (E.sem_bufferization_to_tensor id sh ty access)))
  | "bufferization.materialize_in_destination" ->
      let src,dst = two () in
      let src = tensor op src and id,_,_ = memref op dst in
      if not (flag "writable" op) then error op "destination is not writable";
      Effect.perform (H.Memory ("write_result", E.write_result src id)); None
  | "hfusion.print" | "hivm.hir.debug" -> debug ctx op (one ()); None
  | "hivm.hir.bitcast" ->
      let shape,ty = last_type op in
      some (vector op (H.Bitcast (tensor op (one ()),E.EmptyTensor (shape,ty))))
  | "hfusion.indirect_store" | "hivm.hir.indirect_store" ->
      (match List.map lookup op.inputs,List.map lookup op.outputs with
      | src::offsets::mask,[dst] ->
          let id,_,ty = memref op dst in
          let mask = match mask with [] -> None | [mask] -> Some mask
            | _ -> error op "invalid indirect store mask" in
          let shape,lanes = lane_indices op offsets mask in
          let src_shape,src_ty,cells = H.packed (tensor op src) in
          if src_shape <> shape || src_ty <> ty then error op "indirect store source type mismatch";
          let entries = List.filter_map Fun.id (List.map2 (fun lane cell ->
            Option.map (fun index -> index,cell) lane) lanes cells) in
          let coordinates,selected = List.split entries in
          let () = H.memory "indirect_store" (E.perform (E.WriteRange (id,coordinates,selected))) in
          None
      | _ -> error op "invalid indirect store operands")
  | _ ->
      let ins = List.map lookup op.inputs in
      let outs = List.map lookup op.outputs in
      let destination = match outs with [x] -> x | _ -> error op "expected one destination" in
      let dst = match destination with
        | Memref (_,shape,ty) ->
            E.EmptyTensor (shape,ty)
        | x -> tensor op x in
      let input () = match ins with [x] -> x | _ -> error op "expected one input" in
      let unary () = tensor op (input ()) in
      let unary_elementwise () = match operand op (input ()) with
        | E.ScalarOperand (ty,x) -> H.unwrap (E.sem_linalg_fill ty x dst)
        | E.TensorOperand value -> value in
      let binary () = match ins with [a;b] -> a,b | _ -> error op "expected two inputs" in
      let result = match op.opcode with
      | "linalg.fill" ->
          let ty,x = scalar op (input ()) in
          hfusion (H.Fill (ty,x,dst))
      | "linalg.transpose" -> hfusion (H.Transpose (unary (),dst,dims "permutation" op))
      | "linalg.broadcast" -> hfusion (H.Broadcast (unary (),dst,dims "dimensions" op))
      | "linalg.matmul" ->
          let a,b = binary () in hfusion (H.Matmul (tensor op a,tensor op b,dst))
      | "linalg.elemwise_binary" ->
          let a,b = binary () in
          let operator = match enum op "fun" "linalg.binary_fn" with
            | "add" -> E.LinalgAdd | "sub" -> E.LinalgSub | "mul" -> E.LinalgMul
            | "div" -> E.LinalgDiv | "min_signed" -> E.LinalgMinSigned
            | "max_signed" -> E.LinalgMaxSigned | _ -> error op "unsupported binary function" in
          hfusion (H.Binary (operator,elementwise op dst a,elementwise op dst b,dst))
      | "linalg.elemwise_unary" ->
          let exp = match enum op "fun" "linalg.unary_fn" with "exp" -> true | "log" -> false
            | _ -> error op "unsupported unary function" in
          hfusion (H.Unary (exp,unary_elementwise (),dst))
      | "hfusion.cast" -> hfusion (H.Cast (unary (),dst))
      | "linalg.reduce" ->
          let combine inputs accumulators =
            let bindings = List.map2 (fun (name,ty) x -> match ty with
              | ScalarType ty -> name,of_cell ty x
              | _ -> error op "reduction region requires scalar arguments")
                op.region_arguments (inputs @ accumulators) in
            let saved = ctx.current in
            Fun.protect ~finally:(fun () -> ctx.current <- saved) (fun () ->
              with_handlers ctx (fun () ->
                let _,ys = execute_block ctx (bindings @ env) op.region in
                E.Ok (List.map (fun x -> snd (scalar op x)) ys)))
          in hfusion (H.Reduce (combine,dims "dimensions" op,unary (),dst))
      | "hivm.hir.vadd" | "hivm.hir.vsub" | "hivm.hir.vmul" | "hivm.hir.vdiv"
      | "hivm.hir.vand" | "hivm.hir.vshr" | "hivm.hir.vmin" | "hivm.hir.vmax" ->
          let a,b = binary () in
          let operator = match op.opcode with
            | "hivm.hir.vadd" -> E.VAdd | "hivm.hir.vsub" -> E.VSub
            | "hivm.hir.vmul" -> E.VMul | "hivm.hir.vdiv" -> E.VDiv
            | "hivm.hir.vand" -> E.VAnd | "hivm.hir.vshr" -> E.VShr
            | "hivm.hir.vmin" -> E.VMin | _ -> E.VMax in
          hivm (E.BinaryRequest (operator,operand op a,operand op b,dst))
      | "hivm.hir.vexp" | "hivm.hir.vln" ->
          hivm (E.UnaryRequest ((if op.opcode = "hivm.hir.vexp" then E.VExp else E.VLn),unary_elementwise (),dst))
      | "hfusion.elemwise_binary" ->
          let a,b = binary () in
          let operator = match enum op "fun" "hfusion.binary_fn" with
            | "vand" -> E.VAnd | "shrsi" -> E.VShr | "maxf" -> E.VMax
            | _ -> error op "unsupported HFusion binary function" in
          vector op (H.Vector_binary (operator,operand op a,operand op b,dst))
      | "hfusion.arange" | "hivm.hir.varange" ->
          let args = List.map (integer64 op) ins in
          let rank = List.length (E.shape0 dst) in
          let offset,strides = match args with
            | offset::strides when List.length strides = rank -> offset,strides
            | strides -> 0L,strides in
          vector op (H.Range (offset,strides,dst))
      | "hfusion.compare" | "hivm.hir.vcmp" ->
          let a,b = binary () in
          let mode = if op.opcode = "hfusion.compare" then
              let kind = enum op "compare_fn" "hfusion.compare_fn" in
              String.sub kind 1 (String.length kind - 1)
            else Yojson.Safe.Util.to_string (attribute op "compare_mode") in
          vector op (H.Compare (mode,operand op a,operand op b,dst))
      | "hfusion.select" | "hivm.hir.vsel" ->
          (match ins with
          | [mask;a;b] -> vector op (H.Select (operand op mask,operand op a,operand op b,dst))
          | _ -> error op "invalid select operands")
      | "hfusion.bitcast" -> vector op (H.Bitcast (unary (),dst))
      | "hivm.hir.vtranspose" -> vector op (H.Vector_transpose (unary (),dst,dims "permutation" op))
      | "hfusion.indirect_load" | "hivm.hir.indirect_load" ->
          (match ins with
          | [src;offsets;mask;fallback] ->
              let id,_,ty = memref op src in
              let shape,lanes = lane_indices op offsets (Some mask) in
              let fallback_shape,fallback_ty,cells = H.packed (tensor op fallback) in
              if shape <> E.shape0 dst || fallback_shape <> shape || fallback_ty <> ty ||
                 E.element_type dst <> ty then error op "indirect load type mismatch";
              let loaded = H.memory "indirect_load"
                  (E.perform (E.ReadRange (id,List.filter_map Fun.id lanes))) in
              let remaining = ref loaded in
              let result = List.map2 (fun lane fallback ->
                match lane,!remaining with
                | None,_ -> fallback
                | Some _,x::xs -> remaining := xs; x
                | Some _,[] -> error op "indirect load result count mismatch") lanes cells in
              Tensor (H.unwrap (E.make_value shape ty result))
          | _ -> error op "invalid indirect load operands")
      | "hivm.hir.vcast" -> hivm (E.CastRequest (E.default_cast,unary (),dst))
      | "hivm.hir.vbrc" ->
          let src = match ins with [x] -> operand op x | _ -> error op "broadcast input" in
          hivm (E.BroadcastRequest (src,dst,dims "broadcast_dims" op))
      | "hivm.hir.vreduce" ->
          let operator = match attribute op "kind" with
            | `String "sum" -> E.ReduceSum
            | `String "max" -> E.ReduceMax
            | _ -> error op "unsupported reduction kind" in
          hivm (E.ReduceRequest (operator,unary (),dst,dims "reduce_dims" op))
      | "hivm.hir.mmadL1" ->
          (match ins with
          | [a;b;init;m;k;n] ->
              let spec = {E.mm_b_transpose = flag "b_transpose" op;
                mm_init = Numeric.int_of_z (snd (integer op init)) <> 0;
                mm_real_m = snd (integer op m); mm_real_k = snd (integer op k);
                mm_real_n = snd (integer op n)} in
              hivm (E.MmadRequest (spec,tensor op a,tensor op b,dst))
          | _ -> error op "invalid matrix operands")
      | _ -> error op ("unsupported operation " ^ op.opcode)
      in match destination with
      | Memref (id,_,_) ->
          Effect.perform (H.Memory ("write_result",E.write_result (tensor op result) id)); None
      | _ -> some result
