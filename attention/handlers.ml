module E = Extracted_semantics.Unified_semantics

type tensor = float E.value
type hfusion =
  | Fill of E.mlir_type * float * tensor
  | Transpose of tensor * tensor * int list
  | Broadcast of tensor * tensor * int list
  | Unary of bool * tensor * tensor
  | Matmul of tensor * tensor * tensor
  | Binary of E.linalg_binary_fn * float E.elementwise_operand *
      float E.elementwise_operand * tensor
  | Cast of tensor * tensor
  | Reduce of float E.reduction_combiner * int list * tensor * tensor

type _ common =
  | Empty : int list * E.mlir_type -> tensor common
  | Reshape : bool * tensor * int list * int list list -> tensor common
  | Integer_constant : E.mlir_type * E.z -> E.z common
  | Integer_binary : E.arith_binary_operator * E.mlir_type * E.z * E.z -> E.z common
  | Integer_cast : E.arith_cast_operator * E.mlir_type * E.mlir_type * E.z -> E.z common
  | Float_constant : E.mlir_type * E.float_literal -> float common
  | Scalar_binary : E.scalar_operation * float * float -> float common

type _ Effect.t +=
  | HFusion : hfusion -> tensor Effect.t
  | HIVM : float E.request -> tensor Effect.t
  | Common : 'a common -> 'a Effect.t
  | Memory : string * (float, (E.runtime_error, 'a) E.result) E.memory_computation ->
      'a Effect.t

exception Semantic_error of E.runtime_error
let unwrap = function E.Ok x -> x | E.Error e -> raise (Semantic_error e)
let packed v = match v with
  | E.DefinedTensor (E.PackTensor (sh, ty, xs)) -> sh, ty, xs
  | E.EmptyTensor _ -> raise (Semantic_error E.ReadUninitialized)

let hfusion = function
  | Fill (ty,x,dst) -> E.sem_linalg_fill ty x dst
  | Transpose (src,dst,dims) -> E.sem_linalg_transpose src dst dims
  | Broadcast (src,dst,dims) -> E.sem_linalg_broadcast src dst dims
  | Unary (exp,src,dst) -> E.sem_linalg_unary Numeric.scalar exp src dst
  | Matmul (a,b,dst) -> E.sem_linalg_matmul Numeric.scalar a b dst
  | Binary (op,a,b,dst) ->
      let sh = E.shape0 dst and ty = E.element_type dst in
      (match E.sem_linalg_elemwise_binary Numeric.scalar op E.LinalgCastSigned sh ty a b with
      | E.Error e -> E.Error e
      | E.Ok xs -> E.Ok (E.DefinedTensor (E.PackTensor (sh,ty,xs))))
  | Cast (src,dst) ->
      let sh,ty,xs = packed src in
      if sh <> E.shape0 dst then E.Error E.InvalidShape else
      (match E.sem_hfusion_cast sh ty Numeric.scalar E.HFusionCastSigned
        E.HFusionRint true false E.HFusionSI2SI (E.element_type dst) xs with
      | E.Error e -> E.Error e
      | E.Ok xs -> E.Ok (E.DefinedTensor (E.PackTensor (sh,E.element_type dst,xs))))
  | Reduce (combine,dims,src,dst) ->
      let sh,ty,xs = packed src in
      let outsh,outty,init = packed dst in
      if E.result_shape sh dims <> outsh then E.Error E.InvalidShape else
      (match E.sem_linalg_reduce combine dims sh
        [E.ShapedTensor (ty,xs)] [E.ShapedTensor (outty,init)] with
      | E.Ok [E.ShapedTensor (ty,xs)] ->
          E.Ok (E.DefinedTensor (E.PackTensor (outsh,ty,xs)))
      | E.Ok _ -> E.Error E.InvalidShape
      | E.Error e -> E.Error e)

let hfusion_entry = function
  | Fill _ -> "sem_linalg_fill" | Transpose _ -> "sem_linalg_transpose"
  | Broadcast _ -> "sem_linalg_broadcast" | Unary _ -> "sem_linalg_unary"
  | Matmul _ -> "sem_linalg_matmul" | Binary _ -> "sem_linalg_elemwise_binary"
  | Cast _ -> "sem_hfusion_cast" | Reduce _ -> "sem_linalg_reduce"

let common_entry : type a. a common -> string = function
  | Empty _ -> "sem_empty" | Reshape _ -> "sem_reshape"
  | Integer_constant _ -> "sem_integer_constant"
  | Integer_binary _ -> "sem_integer_binary" | Integer_cast _ -> "sem_integer_cast"
  | Float_constant _ -> "sem_float_constant" | Scalar_binary _ -> "eval_scalar_operation"

let common : type a. a common -> (E.runtime_error,a) E.result = function
  | Empty (sh,ty) -> E.sem_empty sh ty
  | Reshape (expand,src,sh,groups) -> E.sem_reshape expand src sh groups
  | Integer_constant (ty,n) -> E.sem_integer_constant ty n
  | Integer_binary (op,ty,a,b) -> E.sem_integer_binary op ty a b
  | Integer_cast (op,src,dst,n) -> E.sem_integer_cast op src dst n
  | Float_constant (ty,x) -> E.sem_float_constant Numeric.hivm ty x
  | Scalar_binary (op,a,b) ->
      (match E.eval_scalar_operation Numeric.scalar op a b with
      | E.Ok x -> E.Ok x | E.Error _ -> E.Error E.NumericFailure)

type state = { memory : float E.memory_state; marker : int }
let memory_lens : (float,state) E.hasMemory =
  { E.lens_get = (fun s -> s.memory);
    lens_put = (fun memory s -> {s with memory}) }

(* A callback evaluates reduction regions while the outer handler is suspended.
   Re-entering these handlers around that callback gives its scalar effects the
   same semantics; no fallback evaluation is introduced. *)
let run ?(enable_hfusion=true) ?(enable_hivm=true) ?(enable_common=true)
    ?(enable_memory=true) ~state ~on_call f =
  Effect.Deep.match_with f () {
    retc = Fun.id;
    exnc = raise;
    effc = (fun (type a) (request_effect : a Effect.t) ->
      let answer thunk = Some (fun (k : (a,_) Effect.Deep.continuation) ->
        match thunk () with
        | value -> Effect.Deep.continue k value
        | exception exn -> Effect.Deep.discontinue k exn) in
      match request_effect with
      | HFusion request when enable_hfusion -> answer (fun () ->
          on_call (hfusion_entry request); unwrap (hfusion request))
      | HIVM request when enable_hivm -> answer (fun () ->
          on_call "HIVM.evaluate"; unwrap (E.evaluate Numeric.hivm request))
      | Common request when enable_common -> answer (fun () ->
          on_call (common_entry request); unwrap (common request))
      | Memory (entry,program) when enable_memory -> answer (fun () ->
          on_call entry;
          let ((value,_events),next) =
            unwrap (E.run_memory memory_lens 1000000 program !state) in
          state := next; value)
      | _ -> None);
  }

let memory name program =
  Effect.perform (Memory (name, E.bind program (fun x -> E.Return (E.Ok x))))
