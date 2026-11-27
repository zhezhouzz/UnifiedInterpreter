open Stdlib
open Unified_interpreter
open Execution_value

type register_result = {element:element; input_type:element; count:int}
type _ Effect.t +=
  | Tensor_operation : M.operation * t list * (t -> t -> t) -> t list Effect.t
  | Register_operation : M.operation * t list * register_result -> t list Effect.t
  | Register_transfer : M.operation * t list * int list -> t list Effect.t
  | Allocate : element * int list -> view Effect.t
  | Load : view * int list -> t Effect.t
  | Store : view * int list * t -> unit Effect.t
  | Copy : view * view -> unit Effect.t

let compute (type a) (request : a Effect.t) : (unit -> a) option =
  match request with
  | Tensor_operation (op,args,combine) -> Some (fun () -> Execution_tensor.run op args ~combine)
  | Register_operation (op,args,{element;input_type;count}) ->
      Some (fun () -> Execution_vector.compute op ~element ~input_type ~count args)
  | _ -> None

let access (type a) (request : a Effect.t) : (unit -> a) option =
  match request with
  | Register_transfer (op,args,widths) -> Some (fun () -> Execution_vector.transfer op args widths)
  | Allocate (elem,shape) -> Some (fun () -> create elem shape)
  | Load (view,ix) -> Some (fun () -> read view (position view ix))
  | Store (view,ix,v) -> Some (fun () -> write view (position view ix) v)
  | Copy (src,dst) -> Some (fun () -> copy src dst)
  | _ -> None

let h3 = Interpreter.{interpret=compute}
let h4 = Interpreter.{interpret=access}
