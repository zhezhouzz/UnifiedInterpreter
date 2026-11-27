open Z3
open Historical_lang
open Formula
open Historical_events

type outcome =
  | Race of { n : Z.t; witness : Race_schedule.Result.race_witness }
  | No_race
  | Unknown of string

let solve ?launch_n ~timeout_ms family =
  if timeout_ms < 0 then invalid_arg "negative solver timeout";
  if launch_n=None && family.parameter=[] then invalid_arg "symbolic N needs an entry parameter";
  Option.iter (fun count -> if Z.sign count < 0 then invalid_arg "negative launch N") launch_n;
  let ctx = mk_context [] in
  let solver () = Race_solve.new_solver ~timeout_ms ctx in
  let n = fresh ctx "N" in
  let input,prefix_rounds = match launch_n with
    | Some count -> num ctx count,Some n
    | None -> n,None in
  let sites = compile ?prefix_rounds ctx family input in
  let accesses = List.filter (fun s -> match s.kind with Access _ -> true | _ -> false) sites in
  let barriers = List.filter (fun s -> s.kind = Barrier) sites in
  let has_flags = Historical_order.touches sites <> [] in
  let candidates = solver () in
  let counts = lazy (Historical_fifo.counters ctx (solver ()) n sites) in
  (* 两个解释独立选择合法前缀，共享入口参数及目标操作的动态身份。 *)
  let full = lazy (
    let s = solver () in
    let actual=if launch_n=None then sites else compile ctx family input in
    let forward = Historical_order.execution ctx s ~visible:sites actual in
    let reverse = Historical_order.execution ctx s ~visible:sites actual in
    s, forward, reverse) in
  let concretize solver assumptions a b =
    (* 整数模型可任意选取很大的 N。收紧已满足公式中 N 的上界，
       减少构造见证所需的事件数。每次查询仍同时求解 N 和迭代坐标。 *)
    let rec shrink lo model =
      let hi = numeral (Option.get (Model.eval model n true)) in
      if Z.geq lo hi then model else
      let mid = Z.div (Z.add lo hi) (Z.of_int 2) in
      match Solver.check solver (le ctx n (num ctx mid) :: assumptions) with
      | Solver.SATISFIABLE -> shrink lo (Option.get (Solver.get_model solver))
      | Solver.UNSATISFIABLE -> shrink (Z.succ mid) model
      | Solver.UNKNOWN -> model in
    let model = shrink Z.zero (Option.get (Solver.get_model solver)) in
    let value e = numeral (Option.get (Model.eval model e true)) in
    let id (i : instance) = Core_lang.{stream = i.site.stream; site = i.site.path;
                          iterations = List.map (fun e -> Z.to_int (value e)) i.args} in
    let count = value n in
    let program = instantiate family (Option.value launch_n ~default:count) in
    let loop_bound = Option.map (fun _ -> Z.to_int count) launch_n in
    let schedule = Race_schedule.compile ~pair_limit:0 program in
    let within=Option.map (fun loop_bound ->
      Race_schedule.visibility (Race_schedule.compile ~loop_bound ~pair_limit:0 program) schedule) loop_bound in
    Option.map (fun witness -> Race {n = count; witness})
      (Race_solve.witness ?within ~timeout_ms schedule (id a) (id b)) in
  let pair left right =
    if left == right && left.indices = [] then No_race else
    let a = instance ctx left and b = instance ctx right in
    let separate fence =
      if left.stream <> right.stream || fence.stream <> left.stream ||
         fence.pipe <> left.pipe || fence.pipe <> right.pipe then bool ctx false else
      let f = instance ctx fence in
      let between x y = and_ ctx [earlier ctx x f; earlier ctx f y] in
      exists ctx f.args (and_ ctx [valid f; or_ ctx [between a b; between b a]]) in
    let overlap = simplify (and_ ctx [
      le ctx (int ctx 0) n; valid a; valid b; conflicts ctx a b;
      (if left == right then lex ctx a.args b.args else bool ctx true);
      Boolean.mk_not ctx (or_ ctx (List.map separate barriers))]) in
    let exact () =
      let s,forward,reverse = Lazy.force full in
      let query = [overlap; forward a b; reverse b a] in
      match Solver.check s query with
      | Solver.UNSATISFIABLE -> No_race
      | Solver.UNKNOWN -> Unknown (Solver.get_reason_unknown s)
      | Solver.SATISFIABLE ->
          (match concretize s query a b with
           | Some found -> found
           | None -> Unknown "the symbolic model has no validated complete execution") in
    if Boolean.is_false overlap then No_race else
    match Solver.check candidates [overlap] with
    | Solver.UNSATISFIABLE -> No_race
    | Solver.UNKNOWN -> exact ()
    | Solver.SATISFIABLE ->
        let query,status = if has_flags then
          let query = [overlap; Historical_fifo.orders ctx sites (Lazy.force counts) a b] in
          query,Solver.check candidates query
          else [overlap],Solver.SATISFIABLE in
        match status with
        | Solver.UNSATISFIABLE -> No_race
        | Solver.UNKNOWN -> exact ()
        | Solver.SATISFIABLE ->
            (* 只为模型给出的 N 构造具体见证。被同步条件排除的模型
               交给完整的双轨迹查询，N 和两个迭代序号仍然都是符号变量。 *)
            (match concretize candidates query a b with
             | Some found -> found | None -> exact ()) in
  let rec pairs unknown = function
    | [] -> Option.fold ~none:No_race ~some:(fun reason -> Unknown reason) unknown
    | left :: rest as remaining ->
        let rec check unknown = function
          | [] -> pairs unknown rest
          | right :: tail ->
              let outcome = try pair left right with
                | Race_solve.Inconclusive reason -> Unknown reason
                | Z.Overflow -> Unknown "witness exceeds the concrete OCaml index range" in
              match outcome with
              | Race _ as found -> found
              | No_race -> check unknown tail
              | Unknown reason -> check (Some reason) tail in
        check unknown remaining in
  pairs None accesses

let find ?launch_n ?(timeout_ms = 5000) family =
  try solve ?launch_n ~timeout_ms family with
  | Unsupported reason -> Unknown reason
