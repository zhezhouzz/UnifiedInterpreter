type occurrence = { stream : int; site : int list; iterations : int list }
type storage = Input of int | Allocated of occurrence
type address = storage * int
type view = address list
type value = VInt of Z.t | VFloat of float | VBool of bool | VEvent of int | VView of view
type operand = Literal of value | Var of int
type endpoint = Data of int | ScalarEnd
type barrier = Pipe of int | All
type signal = LocalSet | LocalWait | BlockSet | BlockWait

type command =
  | End
  | Return of operand list
  | Scalar of int * int * operand list * command
  | Alloc of int * int * operand list * command
  | Issue of int * int * operand list * command
  | Sync of signal * int * endpoint * operand * command
  | Barrier of barrier * command
  | Branch of operand * command * command * command
  | For of int * operand * operand * operand * command * command

type footprint = { reads : address list; writes : address list }
type stream = { id : int; pipes : int list; params : (int * value) list; body : command }

(** 两个解释函数均须为纯函数。视图共享底层地址时保留别名关系。 *)
type program = {
  streams : stream list;
  scalar_eval : int -> int -> value list -> value;
  footprint : int -> int -> int -> value list -> footprint;
  block_edge : int -> int -> int -> endpoint -> bool;
}

type key = { block : bool; receiver : int; source : int; target : endpoint; flag : int }
type item = Operation of int * footprint | Set of key list | Wait of key | Bar
type action =
  | Control
  | Reserve of int * view
  | Submit of int * item
  | Fence of int list
  | Scalar_wait of key

type event =
  | Issued of occurrence * action
  | Done of { id : occurrence; pipe : int; position : int; item : item }

let integer = function VInt n -> n | _ -> invalid_arg "Core_lang: expected integer"
let lookup env = function Literal v -> v | Var x -> List.assoc x env

type stream_plan = { actions : (occurrence * action) list; cutoff : bool }

(** 每条流的控制序列只取决于入口值和标量计算。End 恢复词法作用域，
    Return 结束整条流。site 的子节点按构造器中的命令顺序编号。 *)
let stream_plan ?loop_bound program stream =
  if Option.fold ~none:false ~some:(fun bound -> bound < 0) loop_bound then
    invalid_arg "Core_lang: negative loop bound";
  let actions = ref [] in
  let rec run env path iterations command continue =
    let occurrence = { stream = stream.id; site = List.rev path; iterations = List.rev iterations } in
    let emit id action = actions := (id, action) :: !actions in
    let issue = emit occurrence in
    let next env cmd = run env (0 :: path) iterations cmd continue in
    let value = lookup env in
    let args = List.map value in
    match command with
    | End -> continue ()
    | Return vs -> ignore (args vs); false
    | Scalar (x, op, vs, rest) ->
        let v = program.scalar_eval stream.id op (args vs) in
        issue Control;
        next ((x, v) :: env) rest
    | Alloc (x, space, dims, rest) ->
        let size = List.fold_left (fun product v ->
          let n = integer (value v) in
          if Z.sign n < 0 then invalid_arg "Core_lang: negative allocation dimension";
          Z.mul product n) Z.one dims in
        let view = List.init (Z.to_int size) (fun offset -> Allocated occurrence, offset) in
        issue (Reserve (space, view));
        next ((x, VView view) :: env) rest
    | Issue (pipe, op, vs, rest) ->
        let access = program.footprint stream.id pipe op (args vs) in
        issue (Submit (pipe, Operation (op, access)));
        next env rest
    | Sync (mode, source, target, e, rest) ->
        let flag = match value e with VEvent k -> k | _ -> invalid_arg "Core_lang: expected flag" in
        let key receiver = { block = (mode = BlockSet || mode = BlockWait);
                             receiver; source; target; flag } in
        let action = match mode, target with
          | LocalSet, Data _ -> Submit (source, Set [key stream.id])
          | BlockSet, _ ->
              let receivers = List.filter_map (fun s ->
                if program.block_edge stream.id source s.id target then Some (key s.id) else None
              ) program.streams in
              Submit (source, Set receivers)
          | (LocalWait | BlockWait), Data pipe -> Submit (pipe, Wait (key stream.id))
          | BlockWait, ScalarEnd -> Scalar_wait (key stream.id)
          | (LocalSet | LocalWait), ScalarEnd -> invalid_arg "Core_lang: local scalar flag" in
        issue action;
        next env rest
    | Barrier (b, rest) ->
        issue (Fence (match b with Pipe p -> [p] | All -> stream.pipes));
        next env rest
    | Branch (test, yes, no, rest) ->
        let branch, cmd = match value test with
          | VBool true -> 0, yes | VBool false -> 1, no
          | _ -> invalid_arg "Core_lang: expected branch condition" in
        issue Control;
        run env (branch :: path) iterations cmd
          (fun () -> run env (2 :: path) iterations rest continue)
    | For (x, lo, hi, stride, body, rest) ->
        let lo, hi, stride = integer (value lo), integer (value hi), integer (value stride) in
        let rec loop ordinal index =
          let another = if Z.sign stride > 0 then Z.lt index hi else Z.gt index hi in
          if not another then (
            issue Control;
            run env (1 :: path) iterations rest continue)
          else if loop_bound = Some ordinal then true
          else (
            emit { occurrence with iterations = List.rev (ordinal :: iterations) } Control;
            run ((x, VInt index) :: env) (0 :: path) (ordinal :: iterations) body
              (fun () -> loop (ordinal + 1) (Z.add index stride))) in
        Z.sign stride <> 0 && loop 0 lo
  in
  let cutoff = run stream.params [] [] stream.body (fun () -> false) in
  { actions = List.rev !actions; cutoff }
