module E = Extracted_semantics.Unified_semantics
module H = Handlers
open Parser

type value =
  | Int of E.mlir_type * E.z
  | Float of E.mlir_type * float
  | Tensor of H.tensor
  | View of float E.runtime_tensor
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
let flag key op = List.assoc_opt key op.attributes = Some (`Bool true)
let enum op key tag =
  let json = attribute op key in
  if Yojson.Safe.Util.(json |> member "enum" |> to_string) <> tag
  then error op ("unexpected enum for " ^ key);
  Yojson.Safe.Util.(json |> member "value" |> to_string)
let last_type (op : operation) =
  match op.result_type with
  | Some (ShapedType (_,sh,ty)) -> sh,ty
  | _ -> error op "missing shaped result type"
let trailing_scalar (op : operation) =
  match op.result_type with
  | Some (ScalarType ty) -> ty | _ -> error op "missing scalar result type"
let get env op name =
  match List.assoc_opt name env with
  | Some v -> v | None -> error op ("undefined SSA value " ^ name)
let integer op = function Int (ty,x) -> ty,x | _ -> error op "expected integer"
let floating op = function Float (ty,x) -> ty,x | _ -> error op "expected float"
let memref op = function Memref (id,sh,ty) -> id,sh,ty | _ -> error op "expected memref"
let tensor op = function
  | Tensor t -> t
  | View view -> Effect.perform (H.Memory ("materialize", E.materialize view))
  | _ -> error op "expected tensor"
let operand op = function
  | Float (ty,x) -> E.ScalarOperand (ty,x)
  | x -> E.TensorOperand (tensor op x)
let elementwise op dst = function
  | Float (ty,x) -> E.ElementwiseScalar (ty,x)
  | x ->
      let sh,ty,xs = H.packed (tensor op x) in
      if sh <> E.shape0 dst then error op "elementwise operand shape mismatch";
      E.ElementwiseTensor (ty,xs)
let common request = Effect.perform (H.Common request)
let hivm request = Tensor (Effect.perform (H.HIVM request))
let hfusion request = Tensor (Effect.perform (H.HFusion request))

let on_call ctx entry =
  ctx.calls <- ctx.calls + 1;
  let fields = ["program_id", `Int ctx.pid; "entry", `String entry;
    "loops", `Assoc (List.map (fun (name,i) -> name,`Int i) ctx.loops)] in
  let fields = match ctx.current with
    | None -> ("ir_stage",`Null) :: fields
    | Some op ->
        ("ir_stage",`String (Stage.name op.stage)) ::
        ("file",`String op.span.file) :: ("line",`Int op.span.start.line) ::
        ("column",`Int op.span.start.column) :: ("opcode",`String op.opcode) ::
        ("result", match op.result with None -> `Null | Some s -> `String s) :: fields
  in ctx.trace (`Assoc fields)

let with_handlers ctx f =
  H.run ~enable_hfusion:false ~enable_hivm:false
    ~state:ctx.state ~on_call:(on_call ctx) f

let with_operation_handlers ctx op f =
  if op.stage <> Stage.of_opcode op.opcode then error op "operation stage mismatch";
  H.run ~enable_hfusion:(op.stage = Stage.HFusion)
    ~enable_hivm:(op.stage = Stage.HIVM)
    ~state:ctx.state ~on_call:(on_call ctx) f

let float_literal s =
  let x = if String.starts_with ~prefix:"0x" s then
      Int32.float_of_bits (Int32.of_string s) else float_of_string s in
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

let rec execute_block ctx env ops =
  match ops with
  | [] -> env, []
  | op :: rest ->
      tick ctx op;
      let run () =
        if op.opcode = "func.return" || op.opcode = "scf.yield" then env, []
        else if op.opcode = "linalg.yield" then
          env, List.map (get env op) op.operands
        else if op.opcode = "scf.for" then begin
          (match op.operands,op.region_arguments with
          | [lo;hi;step],[(iv,_)] ->
              let ty,start = integer op (get env op lo) in
              let hty,stop = integer op (get env op hi) in
              let sty,stride = integer op (get env op step) in
              if ty <> hty || ty <> sty || Numeric.Big.sign (Numeric.big_of_z stride) <= 0
              then error op "invalid for bounds or step";
              let rec loop i =
                if Numeric.Big.compare (Numeric.big_of_z i) (Numeric.big_of_z stop) < 0 then begin
                  tick ctx op;
                  let saved = ctx.loops in
                  ctx.loops <- (iv,Numeric.int_of_z i) :: saved;
                  Fun.protect ~finally:(fun () -> ctx.loops <- saved) (fun () ->
                    ignore (execute_block ctx ((iv,Int (ty,i)) :: env) op.region));
                  ctx.current <- Some op;
                  let next = common (H.Integer_binary (E.ArithAddI,ty,i,stride)) in
                  if Numeric.Big.compare (Numeric.big_of_z next) (Numeric.big_of_z i) <= 0
                  then error op "loop induction overflow";
                  loop next
                end
              in loop start
          | _ -> error op "unsupported for signature");
          execute_block ctx env rest
        end else
          let value = with_operation_handlers ctx op (fun () -> execute_op ctx env op) in
          let env = match op.result,value with
            | Some name,Some v -> (name,v) :: env
            | None,None -> env
            | _ -> error op "operation result count mismatch"
          in execute_block ctx env rest
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
      | `String literal when ty = E.Float32Type ->
          some (Float (ty,common (H.Float_constant (ty,float_literal literal))))
      | `Int n -> some (Int (ty,common (H.Integer_constant (ty,Numeric.z_of_int n))))
      | _ -> error op "invalid constant payload")
  | "arith.addi" | "arith.muli" | "arith.divsi" | "arith.remsi" ->
      let a,b = two () in
      let ty,a = integer op a and ty',b = integer op b in
      if ty <> ty' || ty <> trailing_scalar op then error op "integer type mismatch";
      let operator = match op.opcode with
        | "arith.addi" -> E.ArithAddI | "arith.muli" -> E.ArithMulI
        | "arith.divsi" -> E.ArithDivSI | _ -> E.ArithRemSI in
      some (Int (ty,common (H.Integer_binary (operator,ty,a,b))))
  | "arith.extsi" | "arith.index_cast" ->
      let src,x = integer op (one ()) and dst = trailing_scalar op in
      let operator = if op.opcode = "arith.extsi" then E.ArithExtSI else E.ArithIndexCast in
      some (Int (dst,common (H.Integer_cast (operator,src,dst,x))))
  | "arith.addf" | "arith.maxnumf" ->
      let a,b = two () in
      let ty,a = floating op a and ty',b = floating op b in
      if ty <> ty' || ty <> trailing_scalar op then error op "float type mismatch";
      let operator = if op.opcode = "arith.addf" then E.ScalarAdd else E.ScalarMax in
      some (Float (ty,common (H.Scalar_binary (operator,a,b))))
  | "tensor.empty" ->
      let sh,ty = last_type op in some (Tensor (common (H.Empty (sh,ty))))
  | "tensor.expand_shape" | "tensor.collapse_shape" ->
      let src = tensor op (one ()) in
      let target,_ = last_type op in
      let groups = Yojson.Safe.Util.(attribute op "reassociation" |> to_list
        |> List.map (fun row -> row |> to_list |> List.map to_int)) in
      some (Tensor (common (H.Reshape (op.opcode = "tensor.expand_shape",src,target,groups))))
  | "memref.alloc" ->
      let sh,ty = last_type op in
      let id = H.memory "sem_memref_alloc" (E.sem_memref_alloc E.ASDefault ty sh) in
      some (Memref (id,sh,ty))
  | "memref.reinterpret_cast" ->
      let source = lookup (List.hd op.operands) in
      let id,_,ty = memref op source in
      let offset = match attribute op "offsets" with
        | `List [`String name] ->
            if String.starts_with ~prefix:"%" name then
              snd (integer op (lookup name)) else Numeric.z_of_big (Numeric.Big.of_string name)
        | _ -> error op "invalid reinterpret offset" in
      let sh = dims "sizes" op in
      let strides = dims "strides" op |> List.map Numeric.z_of_int in
      let id = H.memory "sem_memref_reinterpret_cast"
          (E.sem_memref_reinterpret_cast id offset sh strides) in
      some (Memref (id,sh,ty))
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
  | _ ->
      let ins = List.map lookup op.inputs in
      let outs = List.map lookup op.outputs in
      let dst = match outs with [x] -> tensor op x | _ -> error op "expected one destination" in
      let unary () = match ins with [x] -> tensor op x | _ -> error op "expected one input" in
      let binary () = match ins with [a;b] -> a,b | _ -> error op "expected two inputs" in
      let result = match op.opcode with
      | "linalg.fill" ->
          let ty,x = match ins with [x] -> floating op x | _ -> error op "fill input" in
          hfusion (H.Fill (ty,x,dst))
      | "linalg.transpose" -> hfusion (H.Transpose (unary (),dst,dims "permutation" op))
      | "linalg.broadcast" -> hfusion (H.Broadcast (unary (),dst,dims "dimensions" op))
      | "linalg.matmul" ->
          let a,b = binary () in hfusion (H.Matmul (tensor op a,tensor op b,dst))
      | "linalg.elemwise_binary" ->
          let a,b = binary () in
          let operator = match enum op "fun" "linalg.binary_fn" with
            | "add" -> E.LinalgAdd | "sub" -> E.LinalgSub | "mul" -> E.LinalgMul
            | "div" -> E.LinalgDiv | _ -> error op "unsupported binary function" in
          hfusion (H.Binary (operator,elementwise op dst a,elementwise op dst b,dst))
      | "linalg.elemwise_unary" ->
          let exp = match enum op "fun" "linalg.unary_fn" with "exp" -> true | "log" -> false
            | _ -> error op "unsupported unary function" in
          hfusion (H.Unary (exp,unary (),dst))
      | "hfusion.cast" -> hfusion (H.Cast (unary (),dst))
      | "linalg.reduce" ->
          let combine inputs accumulators =
            let bindings = List.map2 (fun (name,ty) x -> match ty with
              | ScalarType ty -> name,Float (ty,x)
              | _ -> error op "reduction region requires scalar arguments")
                op.region_arguments (inputs @ accumulators) in
            let saved = ctx.current in
            Fun.protect ~finally:(fun () -> ctx.current <- saved) (fun () ->
              with_handlers ctx (fun () ->
                let _,ys = execute_block ctx (bindings @ env) op.region in
                E.Ok (List.map (fun x -> snd (floating op x)) ys)))
          in hfusion (H.Reduce (combine,dims "dimensions" op,unary (),dst))
      | "hivm.hir.vadd" | "hivm.hir.vsub" | "hivm.hir.vmul" | "hivm.hir.vdiv" ->
          let a,b = binary () in
          let operator = match op.opcode with
            | "hivm.hir.vadd" -> E.VAdd | "hivm.hir.vsub" -> E.VSub
            | "hivm.hir.vmul" -> E.VMul | _ -> E.VDiv in
          hivm (E.BinaryRequest (operator,operand op a,operand op b,dst))
      | "hivm.hir.vexp" | "hivm.hir.vln" ->
          hivm (E.UnaryRequest ((if op.opcode = "hivm.hir.vexp" then E.VExp else E.VLn),unary (),dst))
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
      in some result
