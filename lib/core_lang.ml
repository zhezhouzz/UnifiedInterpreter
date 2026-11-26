module Device = struct
  include Device_ast
  module Value = Device_value
  module Execution = Device_run
end

type occurrence = { stream : int; site : int list; iterations : int list }
type storage = Input of int | Allocated of occurrence | Invalid_address
type address = storage * int
type view = address list
type buffer = {
  storage : storage option;
  bytes : int;
  base_bytes : int;
  offset : Z.t;
  shape : int list;
  strides : Z.t list;
  element_bytes : int;
}
type value =
  | VInt of Z.t | VFloat of float | VBool of bool | VEvent of int | VView of view
  | VBuffer of buffer
  | VTensor of buffer * (int list -> value)
  | VMemory_read of address list * value Lazy.t
  | VLanes of value array
  | VDeferred of value Lazy.t

type _ Effect.t +=
  | Read_geometry : address list * value Lazy.t -> value Effect.t
  | Load_descriptor : address -> buffer Effect.t
  | Store_descriptor : address * buffer -> unit Effect.t
  | Store_local : address list * string * value -> unit Effect.t
  | Capture_local : address list * string -> value option Effect.t
  | Use_local : address list -> unit Effect.t

let rec demand = function VMemory_read (cells,initial) -> Effect.perform (Read_geometry (cells,initial))
  | VDeferred v -> demand (Lazy.force v)
  | value -> value
exception Prefix_boundary of string
type operand = Literal of value | Var of int
type endpoint = Data of int | ScalarEnd
type barrier = Pipe of int | All
type signal = LocalSet | LocalWait | BlockSet | BlockWait

type command =
  | End
  | Return of operand list
  | Yield of operand list
  | Scalar of int * int * operand list * command
  | Block_counter of int list * command
  | Alloc of int * int * operand list * command
  | Issue of int * int * operand list * command
  | Sync of signal * int * endpoint * operand * command
  | Peer_sync of bool * int list * int * endpoint * operand * command
  | Barrier of barrier * command
  | Core_barrier of command
  | Branch of operand * command * command * command
  | Branch_values of int list * operand * command * command * command
  | For of int * operand * operand * operand * command * command
  | For_values of int * operand * operand * operand * (int * operand) list * int list * command * command
  | While_values of (int * operand) list * int list * int list * command * command * command
  | Call_values of (int * operand) list * int list * (int * int) option * command * command

type footprint = { reads : address list; writes : address list }
type stream = { id : int; pipes : int list; params : (int * value) list; body : command }

(** 两个解释函数均须为纯函数。视图共享底层地址时保留别名关系。 *)
type program = {
  streams : stream list;
  scalar_eval : int -> int -> value list -> value;
  footprint : int -> int -> int -> value list -> footprint;
  block_edge : int -> int -> int -> endpoint -> bool;
}

type key = { block : bool; sender : int option; receiver : int; source : int; target : endpoint; flag : int }
type item = Operation of int * footprint | Set of key list | Wait of key | Wait_peers of key list | Bar
type action =
  | Control
  | Reserve of int * view
  | Submit of int * item
  | Fence of int list
  | Scalar_wait of key
  | Immediate of item

type event =
  | Issued of occurrence * action
  | Done of { id : occurrence; pipe : int; position : int; item : item }

let integer value = match demand value with VInt n -> n | _ -> invalid_arg "Core_lang: expected integer"
let lookup env = function Literal v -> v | Var x -> List.assoc x env

type stream_plan = { actions : (occurrence * action) list; cutoff : bool; boundary : string option }

let scalar_pipe = -1
let async_pipe = -2
let scalar_endpoint stream pipe = pipe=scalar_pipe && not (List.mem pipe stream.pipes)

(** 每条流的控制序列只取决于入口值和标量计算。End 恢复词法作用域，
    Return 结束整条流。site 的子节点按构造器中的命令顺序编号。 *)
let stream_plan ?loop_bound program stream =
  if Option.fold ~none:false ~some:(fun bound -> bound < 0) loop_bound then
    invalid_arg "Core_lang: negative loop bound";
  let actions = ref [] in
  let enclosing_actions = ref None in
  let counters = ref (Hashtbl.create 4) in
  let evaluate f =
    if Option.is_none !enclosing_actions then f () else
      match f () with
      | value -> value
      | effect (Capture_local _), k -> Effect.Deep.continue k None
      | effect (Store_local _), k -> Effect.Deep.continue k () in
  let bind variables values env =
    if List.length variables <> List.length values then invalid_arg "Core_lang: invalid region yield";
    List.combine variables values @ env in
  let rec run env path iterations command continue =
    let occurrence = { stream = stream.id; site = List.rev path; iterations = List.rev iterations } in
    let emit id action = actions := (id, action) :: !actions in
    let issue = emit occurrence in
    let next env cmd = run env (0 :: path) iterations cmd continue in
    let value = lookup env in
    let args = List.map value in
    let branch results test yes no rest =
      let arm, cmd = match demand (value test) with
        | VBool true -> 0, yes | VBool false -> 1, no
        | _ -> invalid_arg "Core_lang: expected branch condition" in
      issue Control;
      run env (arm :: path) iterations cmd
        (fun values -> run (bind results values env) (2 :: path) iterations rest continue) in
    let for_loop x lo hi stride carried results body rest =
      let lo, hi, stride = integer (value lo), integer (value hi), integer (value stride) in
      let variables = List.map fst carried in
      let rec loop ordinal index values =
        let another = if Z.sign stride > 0 then Z.lt index hi else Z.gt index hi in
        if not another then (
          issue Control;
          run (bind results values env) (1 :: path) iterations rest continue)
        else if loop_bound = Some ordinal then true
        else (
          emit { occurrence with iterations = List.rev (ordinal :: iterations) } Control;
          let local = bind variables values ((x, VInt index) :: env) in
          run local (0 :: path) (ordinal :: iterations) body
            (loop (ordinal + 1) (Z.add index stride))) in
      Z.sign stride <> 0 && loop 0 lo (args (List.map snd carried)) in
    match command with
    | While_values (inputs,after,results,before,body,rest) ->
        let rec loop ordinal values =
          let iters = ordinal::iterations in
          run (bind (List.map fst inputs) values env) (0::path) iters before (function
            | condition::values -> (match demand condition with
                | VBool false ->
                    issue Control; run (bind results values env) (2::path) iterations rest continue
                | VBool true when loop_bound=Some ordinal -> true
                | VBool true -> run (bind after values env) (1::path) iters body (loop (ordinal+1))
                | _ -> invalid_arg "while condition must yield a boolean")
            | _ -> invalid_arg "while condition must yield a boolean and its carried values") in
        loop 0 (args (List.map snd inputs))
    | Call_values (params,results,task,body,rest) ->
        let locals = bind (List.map fst params) (args (List.map snd params)) [] in
        let caller_counters = !counters in
        counters := Hashtbl.create 4;
        let outer = !actions in
        if Option.is_some task then (
          if Option.is_some !enclosing_actions then invalid_arg "nested asynchronous call";
          enclosing_actions := Some outer; actions := []);
        run locals (0::path) iterations body (fun values ->
          counters := caller_counters;
          Option.iter (fun (pipe,op) ->
            let reads,writes = List.fold_left (fun (reads,writes) (_,action) ->
              match action with
              | Control -> reads,writes
              | Immediate (Operation (_,fp)) -> List.rev_append fp.reads reads,List.rev_append fp.writes writes
              | _ -> invalid_arg "unsupported nested task or synchronization in asynchronous call")
              ([],[]) !actions in
            enclosing_actions := None; actions := outer;
            issue (Submit (pipe,Operation (op,{reads;writes})))) task;
          run (bind results values env) (1::path) iterations rest continue)
    | End -> continue []
    | Yield vs -> continue (args vs)
    | Return vs -> ignore (args vs); false
    | Scalar (x, op, vs, rest) ->
        let v = evaluate (fun () -> program.scalar_eval stream.id op (args vs)) in
        issue Control;
        next ((x, v) :: env) rest
    | Block_counter (results,rest) ->
        let ordinal=Option.value (Hashtbl.find_opt !counters path) ~default:Z.zero in
        Hashtbl.replace !counters path (Z.signed_extract (Z.succ ordinal) 0 64);
        next (List.fold_left (fun env id -> (id,VInt ordinal)::env) env results) rest
    | Alloc (x, space, dims, rest) ->
        let size = List.fold_left (fun product v ->
          let n = integer (value v) in
          if Z.sign n < 0 then invalid_arg "Core_lang: negative allocation dimension";
          Z.mul product n) Z.one dims in
        let view = List.init (Z.to_int size) (fun offset -> Allocated occurrence, offset) in
        issue (Reserve (space, view));
        next ((x, VView view) :: env) rest
    | Issue (pipe, op, vs, rest) ->
        let access = evaluate (fun () -> program.footprint stream.id pipe op (args vs)) in
        let item = Operation (op, access) in
        issue (if scalar_endpoint stream pipe then Immediate item else Submit (pipe, item));
        next env rest
    | Sync (mode, source, target, e, rest) ->
        let flag = match value e with VEvent k -> k | _ -> invalid_arg "Core_lang: expected flag" in
        let key receiver = { block = (mode = BlockSet || mode = BlockWait);sender=None;
                             receiver; source; target; flag } in
        let action = match mode, target with
          | LocalSet, _ ->
              let item = Set [key stream.id] in
              if scalar_endpoint stream source then Immediate item else Submit (source, item)
          | BlockSet, _ ->
              let receivers = List.filter_map (fun s ->
                if program.block_edge stream.id source s.id target then Some (key s.id) else None
              ) program.streams in
              let item = Set receivers in
              if scalar_endpoint stream source then Immediate item else Submit (source, item)
          | (LocalWait | BlockWait), Data pipe -> Submit (pipe, Wait (key stream.id))
          | (LocalWait | BlockWait), ScalarEnd -> Scalar_wait (key stream.id) in
        issue action;
        next env rest
    | Peer_sync (sending,peers,source,target,e,rest) ->
        let flag=match value e with VEvent k -> k | _ -> invalid_arg "expected cross-core flag" in
        let keys=List.map (fun peer -> {block=true;sender=Some (if sending then stream.id else peer);
          receiver=(if sending then peer else stream.id);source;target;flag}) peers in
        let item=if sending then Set keys else Wait_peers keys in
        let pipe=if sending then source else match target with ScalarEnd -> scalar_pipe | Data p -> p in
        issue (if scalar_endpoint stream pipe then Immediate item else Submit (pipe,item));
        next env rest
    | Core_barrier rest ->
        issue (Immediate Bar);
        next env rest
    | Barrier (b, rest) ->
        issue (Fence (match b with Pipe p -> [p] | All -> List.filter ((<>) async_pipe) stream.pipes));
        next env rest
    | Branch (test, yes, no, rest) -> branch [] test yes no rest
    | Branch_values (results, test, yes, no, rest) -> branch results test yes no rest
    | For (x, lo, hi, stride, body, rest) -> for_loop x lo hi stride [] [] body rest
    | For_values (x, lo, hi, stride, carried, results, body, rest) ->
        for_loop x lo hi stride carried results body rest
  in
  match run stream.params [] [] stream.body (fun _ -> false) with
  | cutoff -> {actions=List.rev (Option.value !enclosing_actions ~default:!actions);cutoff;boundary=None}
  | exception Prefix_boundary reason ->
      {actions=List.rev (Option.value !enclosing_actions ~default:!actions);cutoff=true;boundary=Some reason}
