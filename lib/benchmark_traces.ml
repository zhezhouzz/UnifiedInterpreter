open Race_benchmarks
module Json = Yojson.Safe.Util

type method_ = Concrete of Bug_traces.backend | Symbolic

let find catalog name = match List.assoc_opt name catalog with
  | Some load -> load () | None -> invalid_arg ("unknown benchmark " ^ name)

let generate ?n ?(kv_heads=1) ?(timeout_ms=5000) catalog method_ name =
  let backend = match method_ with Concrete Search -> "bfs" | Concrete Solve -> "smt" | Symbolic -> "symbolic" in
  let report n status races fixture details =
    `Assoc (["format",`String "core-race-1";"benchmark",`String name;"backend",`String backend;
      "n",Option.fold ~none:`Null ~some:(fun i -> `Int i) n;"status",`String status;
      "races",`List races;"fixture",fixture] @ details) in
  if method_=Symbolic && n<>None then invalid_arg "symbolic analysis requires a free N";
  match find catalog name with
  | Core launch ->
      if launch.family.parameter=[] && (n<>None || method_=Symbolic) then invalid_arg "benchmark has fixed entry parameters";
      let details schedule = ["events",Race_report.events launch schedule;"capacity",`Int launch.capacity;
                              "address_unit",`String launch.unit_name] in
      (match method_ with
       | Concrete backend ->
           let count=Option.value ~default:launch.default_n n in
           let n=Z.of_int count in
           let schedule,coverage,races=Historical_schedule.family ~timeout_ms ~input:n
             ~capacity:launch.capacity backend launch.family in
           let status,fields=Concrete_schedule.fields coverage in
           let encode=Race_report.core_race ~full:(Concrete_schedule.full coverage) schedule (Race_report.index schedule) in
           report (Some count) status (List.map encode races) launch.fixture (fields @ details schedule)
       | Symbolic ->
           match Bug_traces.find_symbolic_race ~timeout_ms launch.family with
           | No_race -> report None "no-race" [] launch.fixture []
           | Unknown reason -> report None "unknown" [] launch.fixture ["reason",`String reason]
           | Race {n;witness} ->
               let schedule,coverage,races=Historical_schedule.symbolic_witness ~timeout_ms ~capacity:launch.capacity
                 launch.family n witness in
               let status,fields=match coverage with All_pairs -> "race",[] | result -> Concrete_schedule.fields result in
               let encode=Race_report.core_race ~full:(Concrete_schedule.full coverage) schedule (Race_report.index schedule) in
               report (Some (Z.to_int n)) status (List.map encode races) launch.fixture (fields @ details schedule))
  | Device variant ->
      let config={Vectorlayout_input.default with length=Option.value ~default:Vectorlayout_input.default.length n;kv_heads} in
      let found (fixture : Vectorlayout_input.config) status races events =
        report (Some fixture.length) status races (Device_trace.config fixture)
          ["events",events;"address_unit",`String "bit"] in
      match method_ with
      | Concrete backend ->
          let model=Device_races.compile ~backend variant (Vectorlayout_input.make config) in
          let coverage,rows=Device_races.analyze ~timeout_ms model in
          let status,fields=Concrete_schedule.fields coverage in
          `Assoc (fields @ Json.to_assoc (found config status rows (Device_races.events model)))
      | Symbolic ->
          match Device_symbolic.find ~timeout_ms variant config with
          | Error reason -> report None "unknown" [] (Device_trace.config config) ["reason",`String reason]
          | Ok (fixture,witness,events) -> found fixture "race" [witness] events

let replay catalog doc =
  let field name=Json.member name doc in
  if field "format"<>`String "core-race-1" then invalid_arg "unknown report format";
  let name=Json.to_string (field "benchmark") and races=Json.to_list (field "races") in
  (match find catalog name with
   | Core launch ->
       if launch.fixture<>field "fixture" then invalid_arg "launch or program differs";
       if races<>[] then (
         let schedule=Race_report.schedule ~pair_limit:Loop_trace.threshold launch (Z.of_int (Json.to_int (field "n"))) in
         if Race_report.events launch schedule<>field "events" then invalid_arg "event dictionary differs";
         List.iter (Race_report.replay_core ~full:(field "trace_extent"=`String "program_end") schedule) races)
   | Device variant ->
       let config=Device_trace.parse_config (field "fixture") in
       if races<>[] then (
         if field "n"<>`Int config.length then invalid_arg "trace length parameter differs";
         let model=Device_races.compile variant (Vectorlayout_input.make config) in
         if Device_races.events model<>field "events" then invalid_arg "event dictionary differs";
         List.iter (Device_races.replay_witness ~full:(field "trace_extent"=`String "program_end") model) races));
  2*List.length races
