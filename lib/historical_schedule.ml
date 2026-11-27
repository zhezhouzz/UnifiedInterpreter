(* 已登记的 Core Lang 模型提供循环事件模板和同一程序的具体实例。 *)
let analyze_instance ?(timeout_ms=5000) ~input ~capacity backend template program =
  let probe=Concrete_schedule.probe ~capacity program in
  let concrete ()=Concrete_schedule.from_probe ~timeout_ms ~capacity backend program probe in
  if capacity<>1 || (probe.cutoffs=[] && not (Concrete_schedule.large probe)) then concrete ()
  else match Bug_traces.find_symbolic_race ~timeout_ms ~launch_n:input template with
    | Race {witness;_} ->
        Concrete_schedule.finish ~timeout_ms ~target:(witness.first,witness.second)
          ~capacity backend program probe
    | No_race when probe.boundaries=[] ->
        let schedule=Concrete_schedule.full_schedule ~capacity program probe in
        if schedule.boundaries=[] then schedule,Concrete_schedule.Race_free,[]
        else Concrete_schedule.finish ~timeout_ms ~capacity backend program schedule
    | No_race | Unknown _ -> concrete ()

let family ?timeout_ms ~input ~capacity backend template =
  analyze_instance ?timeout_ms ~input ~capacity backend template (Historical_lang.instantiate template input)

let symbolic_witness ~timeout_ms ~capacity template input (witness:Race_schedule.Result.race_witness) =
  let schedule=Race_schedule.compile ~pair_limit:Loop_trace.threshold ~capacity
    (Historical_lang.instantiate template input) in
  if Concrete_schedule.large schedule then
    let coverage,races=Concrete_schedule.analyze ~timeout_ms ~target:(witness.first,witness.second)
      Bug_traces.Solve schedule in
    schedule,coverage,races
  else schedule,Concrete_schedule.All_pairs,[witness]
