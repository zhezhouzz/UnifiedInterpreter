open Core_lang
open Race_schedule
open Z3

type encoding = {
  ctx : context;
  solver : Solver.solver;
  present : Expr.expr array;
  clock : Expr.expr array;
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
    | Emit { action; predecessors } ->
        List.iter (requires n) predecessors;
        (match action with Scalar_wait k -> flag_event k false n
         | Immediate (Set keys) -> List.iter (fun k -> flag_event k true n) keys
         | Immediate (Wait_peers keys) -> List.iter (fun k -> flag_event k false n) keys | _ -> ())
    | Finish { item; submit; earlier; _ } ->
        requires n submit;
        List.iter (fun a -> match item, item_at schedule a with
          | (Set _ | Bar), _ | _, (Wait _ | Wait_peers _ | Bar) -> requires n a
          | _ -> ()) earlier;
        (match item with Set keys -> List.iter (fun k -> flag_event k true n) keys
         | Wait k -> flag_event k false n | Wait_peers keys -> List.iter (fun k -> flag_event k false n) keys | _ -> ())
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
  { ctx; solver; present; clock }

let check enc assumptions = match Solver.check enc.solver assumptions with
  | Solver.SATISFIABLE -> Some (Option.get (Solver.get_model enc.solver))
  | Solver.UNSATISFIABLE -> None
  | Solver.UNKNOWN -> raise (Inconclusive (Solver.get_reason_unknown enc.solver))

(* 在有限的确定前驱图上，出现的事件组成某个可达前缀。非法访问
   可以就绪并引发异常，但不能作为已成功执行的事件出现在前缀内。 *)
let terminal_fault ~timeout_ms schedule =
  let valid=Array.map (function Unallocated->false | Allocated_after _->true) schedule.allocations in
  let ordinary={schedule with allocations=Array.map (function
    | Unallocated->Allocated_after [] | x->x) schedule.allocations} in
  match Race_search.precedence ordinary with
  | None -> None
  | Some parents when Array.for_all Fun.id valid &&
      Array.length (Precedence.topological_order parents)=Array.length parents -> None
  | Some parents ->
      let enc=encode ~timeout_ms schedule in
      let open Boolean in
      let ready=Array.mapi (fun i ps -> mk_and enc.ctx (mk_not enc.ctx enc.present.(i)::
        List.map (fun j->if j<0 then mk_false enc.ctx else enc.present.(j)) ps)) parents in
      let order model =
        Array.to_list (Array.mapi (fun i var->
          if is_true (Option.get (Model.eval model var true)) then
            Some (Arithmetic.Integer.get_big_int (Option.get (Model.eval model enc.clock.(i) true)),i)
          else None) enc.present) |> List.filter_map Fun.id |> List.sort compare |> List.map snd in
      let pending=mk_or enc.ctx (Array.to_list (Array.map (mk_not enc.ctx) enc.present)) in
      match check enc (pending::Array.to_list (Array.map (mk_not enc.ctx) ready)) with
      | Some model->Some (`Deadlock,order model)
      | None->
          let faults=Array.to_list (Array.mapi (fun i enabled->if valid.(i) then mk_false enc.ctx else enabled) ready) in
          Option.map (fun model->
            let i=List.find_index (fun expr->is_true (Option.get (Model.eval model expr true))) faults |> Option.get in
            `Memory,order model @ [i]) (check enc [mk_or enc.ctx faults])

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
  let prefix_size=Arithmetic.mk_add enc.ctx (Array.to_list (Array.mapi (fun i time ->
    let before=(if i<=last then Arithmetic.mk_le else Arithmetic.mk_lt) enc.ctx time enc.clock.(last) in
    Boolean.mk_ite enc.ctx before (Arithmetic.Integer.mk_numeral_i enc.ctx 1)
      (Arithmetic.Integer.mk_numeral_i enc.ctx 0)) enc.clock)) in
  let rec minimize lower witness =
    let length = List.length witness in
    if lower >= length then replay_indices schedule witness else
    let bound = lower + (length - lower) / 2 in
    let cap = Arithmetic.mk_le enc.ctx prefix_size (Arithmetic.Integer.mk_numeral_i enc.ctx bound) in
    match check enc (cap :: assumptions) with
    | None -> minimize (bound + 1) witness
    | Some model -> minimize lower (prefix enc model last) in
  minimize 2 (prefix enc model last)

let solve_pair ?within enc schedule {a; b; addresses} =
  let direction a b =
    let after=Option.fold ~none:[] ~some:(fun mask -> Array.to_seqi mask |> Stdlib.Seq.filter_map
      (fun (i,allowed) -> if allowed then None else Some (Arithmetic.mk_lt enc.ctx enc.clock.(b) enc.clock.(i)))
      |> List.of_seq) within in
    Arithmetic.mk_lt enc.ctx enc.clock.(a) enc.clock.(b)::after in
  let ab = direction a b and ba = direction b a in
  Option.bind (check enc ab) (fun forward ->
    Option.map (fun reverse -> Result.{
      first = schedule.nodes.(a).id; second = schedule.nodes.(b).id; conflicts = addresses;
      first_then_second = shortest enc schedule ab b forward;
      second_then_first = shortest enc schedule ba a reverse
    }) (check enc ba))

let complete_encoding ?timeout_ms schedule =
  let enc=encode ?timeout_ms schedule in
  Solver.add enc.solver (Array.to_list enc.present);enc

let can_extend schedule =
  if schedule.blocked_control || schedule.boundaries<>[] || schedule.cutoffs<>[] then (fun _ -> false) else
  match Race_search.precedence schedule with
  | Some parents ->
      let complete=Array.length (Precedence.topological_order parents)=Array.length parents in
      (fun _ -> complete)
  | None ->
      let enc=complete_encoding schedule in
      fun prefix ->
        let positions=Array.make (Array.length enc.clock) None in
        List.iteri (fun t i -> positions.(i)<-Some t) prefix;
        let int=Arithmetic.Integer.mk_numeral_i enc.ctx and length=List.length prefix in
        let times=Array.mapi (fun i clock -> match positions.(i) with
          | None -> Arithmetic.mk_ge enc.ctx clock (int length)
          | Some t -> Boolean.mk_eq enc.ctx clock (int t)) enc.clock in
        Option.is_some (check enc (Array.to_list times))

let witness ?within ?timeout_ms schedule first second =
  let locate id=Array.find_index (fun n -> n.id=id && match n.phase with
    | Finish {item=Operation _;_} | Emit {action=Immediate (Operation _);_} -> true | _ -> false) schedule.nodes in
  match locate first,locate second with
  | Some x,Some y when x<>y && not schedule.blocked_control && schedule.boundaries=[] && schedule.cutoffs=[] ->
      let a=min x y and b=max x y in
      (match conflict_pairs [|schedule.nodes.(a);schedule.nodes.(b)|] with
       | [p] ->
           let pair={p with a;b} in
           (match Race_search.precedence schedule with
            | Some parents -> (match (Race_search.from_predecessors ?within Precedence.Bfs
                {schedule with pairs=[pair]} parents).races with [w] -> Some w | _ -> None)
            | None -> solve_pair ?within (complete_encoding ?timeout_ms schedule) schedule pair)
       | _ -> None)
  | _ -> None

let general ?within ?timeout_ms schedule =
  let enc = complete_encoding ?timeout_ms schedule in
  let races = List.filter_map (solve_pair ?within enc schedule) schedule.pairs in
  let truncated = List.exists (function
    | None -> true | Some n -> Option.is_some (check enc [enc.present.(n)])) schedule.cutoffs in
  Result.{races; truncated}

let generate ?within ?timeout_ms schedule = match Race_search.precedence schedule with
  | Some parents -> Race_search.from_predecessors ?within Precedence.Smt schedule parents
  | None -> general ?within ?timeout_ms schedule

(* 多发送者的令牌次序由模型决定。要求所有事件出现，避免选中无法继续的前缀。 *)
let complete_direction enc rounds a b =
  let ctx=enc.ctx in
  let k=Arithmetic.Integer.mk_const_s ctx "prefix_rounds" in
  let int=Arithmetic.Integer.mk_numeral_i ctx in
  let before i j=Arithmetic.mk_lt ctx enc.clock.(i) enc.clock.(j) in
  let limits=Array.to_list (Array.mapi (fun i round ->
    Boolean.mk_or ctx [Arithmetic.mk_le ctx (int round) k;before b i]) rounds) in
  let assumptions=before a b :: limits in
  let rec choose lo hi best =
    if lo>hi then best else
    let mid=lo+(hi-lo)/2 in
    match check enc (Arithmetic.mk_le ctx k (int mid)::assumptions) with
    | None -> choose (mid+1) hi best
    | Some model -> choose lo (mid-1) (Some model) in
  Option.map (fun model ->
    let ordered=Array.to_list (Array.mapi (fun i clock ->
      Arithmetic.Integer.get_big_int (Option.get (Model.eval model clock true)),i) enc.clock) in
    List.map snd (List.sort compare ordered)) (choose 0 (Array.fold_left max 0 rounds) None)
