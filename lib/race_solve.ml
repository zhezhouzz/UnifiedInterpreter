open Core_lang
open Race_schedule
open Z3

type encoding = {
  ctx : context;
  solver : Solver.solver;
  present : Expr.expr array;
  clock : Expr.expr array;
  size : Expr.expr;
}

exception Inconclusive of string

let new_solver ?timeout_ms ctx =
  let solver = Solver.mk_solver ctx None in
  Option.iter (fun ms ->
    let params = Params.mk_params ctx in
    Params.add_int params (Symbol.mk_string ctx "timeout") ms;
    Solver.set_parameters solver params) timeout_ms;
  solver

let encode ?timeout_ms schedule =
  let ctx = mk_context [] in
  let solver = new_solver ?timeout_ms ctx in
  let vars create prefix = Array.mapi (fun n _ -> create ctx (prefix ^ string_of_int n)) schedule.nodes in
  let present = vars Boolean.mk_const_s "present" and clock = vars Arithmetic.Integer.mk_const_s "clock" in
  let int = Arithmetic.Integer.mk_numeral_i ctx in
  let sum = function [] -> int 0 | terms -> Arithmetic.mk_add ctx terms in
  let indicator expr = Boolean.mk_ite ctx expr (int 1) (int 0) in
  let assert_if premise consequence = Solver.add solver [Boolean.mk_implies ctx premise consequence] in
  let before a b = Arithmetic.mk_lt ctx clock.(a) clock.(b) in
  let requires b a = assert_if present.(b) (Boolean.mk_and ctx [present.(a); before a b]) in
  let flags = Hashtbl.create 16 in
  let flag_event k set n =
    let sends, waits = Option.value ~default:([], []) (Hashtbl.find_opt flags k) in
    Hashtbl.replace flags k (if set then n :: sends, waits else sends, n :: waits) in
  Array.iteri (fun n node ->
    (match schedule.allocations.(n) with
     | Unallocated -> Solver.add solver [Boolean.mk_not ctx present.(n)]
     | Allocated_after reserves -> List.iter (requires n) reserves);
    match node.phase with
    | Emit { action; previous } ->
        Option.iter (requires n) previous;
        (match action with Scalar_wait k -> flag_event k false n
         | Immediate (Set keys) -> List.iter (fun k -> flag_event k true n) keys | _ -> ())
    | Finish { item; submit; earlier; _ } ->
        requires n submit;
        List.iter (fun a -> match item, item_at schedule a with
          | (Set _ | Bar), _ | _, (Wait _ | Bar) -> requires n a
          | _ -> ()) earlier;
        (match item with Set keys -> List.iter (fun k -> flag_event k true n) keys
         | Wait k -> flag_event k false n | _ -> ())
  ) schedule.nodes;
  let alternating sends waits =
    (* 同一发送流中的置位在队首完成。同一 key 的等待也按顺序消费。
       第 i 次等待需要第 i 次置位，下一次置位需要此次消费。 *)
    let predecessor n events i =
      if i < Array.length events then requires n events.(i)
      else Solver.add solver [Boolean.mk_not ctx present.(n)] in
    Array.iteri (fun i n -> predecessor n sends i) waits;
    Array.iteri (fun i n -> if i >= schedule.capacity then predecessor n waits (i - schedule.capacity)) sends in
  let shared_key sends waits =
    (* 多条流可向同一接收者置位。每个触及该 key 的事件之前，
       已发生的置位次数减去消费次数必须等于该事件所需的令牌值。 *)
    let touches = sends @ waits in
    List.iteri (fun i n ->
      List.iteri (fun j m -> if j < i then
        assert_if (Boolean.mk_and ctx [present.(m); present.(n)])
          (Boolean.mk_not ctx (Boolean.mk_eq ctx clock.(n) clock.(m)))) touches;
      let count_before events = sum (List.filter_map (fun m ->
        if m = n then None else Some (indicator (Boolean.mk_and ctx [present.(m); before m n]))
      ) events) in
      let balance = Arithmetic.mk_sub ctx [count_before sends; count_before waits] in
      assert_if present.(n) (if List.mem n waits then Arithmetic.mk_gt ctx balance (int 0)
        else Arithmetic.mk_lt ctx balance (int schedule.capacity))
    ) touches in
  Hashtbl.iter (fun _ (sends, waits) ->
    match List.sort_uniq compare (List.map (fun n -> schedule.nodes.(n).id.stream) sends) with
    | [] | [_] -> alternating (Array.of_list (List.rev sends)) (Array.of_list (List.rev waits))
    | _ -> shared_key sends waits
  ) flags;
  let size = sum (List.map indicator (Array.to_list present)) in
  { ctx; solver; present; clock; size }

let check enc assumptions = match Solver.check enc.solver assumptions with
  | Solver.SATISFIABLE -> Some (Option.get (Solver.get_model enc.solver))
  | Solver.UNSATISFIABLE -> None
  | Solver.UNKNOWN -> raise (Inconclusive (Solver.get_reason_unknown enc.solver))

let prefix enc model last =
  let eval var = Option.get (Model.eval model var true) in
  let events = Array.to_list (Array.mapi (fun n var ->
    if Boolean.is_true (eval var) then Some (Arithmetic.Integer.get_big_int (eval enc.clock.(n)), n)
    else None) enc.present) |> List.filter_map Fun.id in
  (* 无共同顺序约束的事件可以具有相同的时钟，以事件编号确定重放次序。 *)
  let rec through = function
    | [] -> failwith "Bug_traces.Solve: missing completion in model"
    | (_, n) :: rest -> if n = last then [n] else n :: through rest in
  through (List.sort compare events)

let shortest enc schedule assumptions last model =
  let rec minimize lower witness =
    let length = List.length witness in
    if lower >= length then replay_indices schedule witness else
    let bound = lower + (length - lower) / 2 in
    let cap = Arithmetic.mk_le enc.ctx enc.size (Arithmetic.Integer.mk_numeral_i enc.ctx bound) in
    match check enc (cap :: assumptions) with
    | None -> minimize (bound + 1) witness
    | Some model -> minimize lower (prefix enc model last) in
  minimize 2 (prefix enc model last)

let solve_pair enc schedule {a; b; addresses} =
  let direction a b =
    [enc.present.(a); enc.present.(b); Arithmetic.mk_lt enc.ctx enc.clock.(a) enc.clock.(b)] in
  let ab = direction a b and ba = direction b a in
  Option.bind (check enc ab) (fun forward ->
    Option.map (fun reverse -> Result.{
      first = schedule.nodes.(a).id; second = schedule.nodes.(b).id; conflicts = addresses;
      first_then_second = shortest enc schedule ab b forward;
      second_then_first = shortest enc schedule ba a reverse
    }) (check enc ba))

let witness ?timeout_ms schedule first second =
  let matches {a;b;_} =
    let x = schedule.nodes.(a).id and y = schedule.nodes.(b).id in
    (x = first && y = second) || (x = second && y = first) in
  Option.bind (List.find_opt matches schedule.pairs)
    (fun pair -> solve_pair (encode ?timeout_ms schedule) schedule pair)

let generate schedule =
  let enc = encode schedule in
  let races = List.filter_map (solve_pair enc schedule) schedule.pairs in
  let truncated = List.exists (function
    | None -> true | Some n -> Option.is_some (check enc [enc.present.(n)])) schedule.cutoffs in
  Result.{races; truncated}
