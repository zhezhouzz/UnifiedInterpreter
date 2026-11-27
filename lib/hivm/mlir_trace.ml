open Stdlib
open Unified_interpreter
open Hivm_event
open Trace_projection
module J = Yojson.Safe.Util
module Mlir = Mlir_lowering

type lowered_mlir = Core_mlir of Mlir.t | Device_mlir of Mlir_device.t

let lower_mlir ?entry ?configuration ?(allow_prefix=true) ast =
  let launch = Mlir.Launch.bind ?entry ?configuration ast in
  if Mlir_device.required launch then Device_mlir (Mlir_device.lower_with_launch ast launch)
  else Core_mlir (Mlir.lower_with_launch ~allow_prefix ast launch)

let mlir_schedule ?pair_limit (lowered : Mlir.t) =
  Race_report.prefix_schedule ?pair_limit ~capacity:lowered.launch.capacity lowered.program

let mlir_inputs digest launch =
  `Assoc (["ast_format",`String "mlir-module-1";"ast_digest",`String digest;
           "stage",`String (if launch.Mlir.Launch.hfusion then "hfusion" else "hivm")] @
          J.to_assoc (Mlir.Launch.inputs launch))

let mlir_source (p : Mlir.source) =
  let span = match p.span with
    | None -> `Null
    | Some s -> `Assoc ["file",`String s.file;"line",`Int s.start.line;"column",`Int s.start.column] in
  `Assoc ["path",ints p.origin.path;"opcode",`String p.origin.opcode;
          "part",optional (fun part -> `String part) p.origin.part;
          "span",span;"synthetic",`Bool p.synthetic]

let mlir_events (lowered : Mlir.t) (schedule : Race_report.Schedule.t) =
  let points = List.to_seq lowered.sources |> Hashtbl.of_seq in
  let events = Race_report.events_of (Array.get lowered.operation_names) schedule |> J.to_list in
  let annotate event (node : Race_report.Schedule.node) =
    match Hashtbl.find_opt points (node.id.stream,node.id.site) with
    | None -> event
    | Some (p : Mlir.source) -> `Assoc (J.to_assoc event @ ["origin",mlir_source p]) in
  `List (List.map2 annotate events (Array.to_list schedule.nodes))

let mlir_entries (lowered : Mlir.t) =
  List.map (fun (s : Mlir.Launch.stream) -> s.id,s.entry) lowered.launch.streams

let mlir_projection (lowered : Mlir.t) =
  let points = List.to_seq lowered.sources |> Hashtbl.of_seq in
  let source stream site = match Hashtbl.find_opt points (stream,site) with
    | Some p when p.synthetic || List.mem p.origin.opcode ["memref.alloc";"memref.alloca"] -> Ordinary
    | Some p -> Nested p
    | None -> invalid "missing source in lowered stream %d at %s" stream (path_name site) in
  let pipes = List.map (fun p -> Mlir.pipe_id p,p) [S;V;M;MTE1;MTE2;MTE3;FIX] in
  pipes,source

let source_event_order (lowered : Mlir.t) =
  let open Race_report.Schedule in
  let schedule = mlir_schedule lowered in
  if schedule.boundaries<>[] then invalid "incomplete module event graph";
  let parents = match Race_report.predecessors schedule with
    | Some parents -> parents | None -> invalid "module event graph requires deterministic prerequisites" in
  let pipes,source = mlir_projection lowered in
  let convert = project_node ~pipes ~entries:(mlir_entries lowered) ~source schedule in
  let graph = Precedence.build parents in
  let visible = ref [] and ids = Array.make (Array.length parents) None in
  (* 跳过 Core 内部节点时，将它依赖的源事件传给后继。 *)
  let frontier = Array.make (Array.length parents) [] and count = ref 0 in
  Array.iter (fun i ->
    let requirements = List.concat_map (Array.get frontier) parents.(i) |> List.sort_uniq Int.compare in
    match convert schedule.nodes.(i) with
    | None -> frontier.(i) <- requirements
    | Some event ->
        ids.(i) <- Some !count;
        frontier.(i) <- [!count];
        incr count;
        visible := (encode_event event,requirements)::!visible) graph.order;
  let pairs = List.filter_map (fun p -> match ids.(p.a),ids.(p.b) with
    | Some a,Some b -> Some (a,b) | _ -> None)
    (if Array.length graph.order=Array.length parents then schedule.pairs else []) in
  Array.of_list (List.rev !visible),pairs

let core_mlir_report ~coverage ~(backend : Bug_traces.backend) ~hivm (lowered : Mlir.t) (schedule : Race_report.Schedule.t) races =
  let coverage = match schedule.boundaries with
    | [] -> coverage
    | reasons ->
        if races<>[] then invalid "race lacks a complete continuation";
        Concrete_schedule.Unresolved (String.concat "\n" reasons) in
  let status=coverage_status coverage and label,details=Concrete_schedule.fields coverage in
  let entries = mlir_entries lowered in
  let name = String.concat "," (List.map snd entries) and inputs = mlir_inputs lowered.ast_digest lowered.launch in
  if hivm then (
    let pipes,source = mlir_projection lowered in
    let races = export_races ~full:(Concrete_schedule.full coverage) ~pipes ~entries ~source schedule races in
    to_json {benchmark=name;streams=entries;n=None;inputs;status;races})
  else
    let index = Race_report.index schedule in
    `Assoc (["format",`String "core-race-1";"benchmark",`String name;
            "backend",`String (match backend with Search -> "bfs" | Solve -> "smt");
            "status",`String label;"capacity",`Int lowered.launch.capacity;
            "inputs",inputs;"address_unit",`String "byte";"events",mlir_events lowered schedule;
            "races",`List (List.map (Race_report.core_race ~full:(Concrete_schedule.full coverage) schedule index) races)] @ details)

let mlir_device_model ~backend (lowered : Mlir_device.t) =
  let points = List.to_seq lowered.sources |> Hashtbl.of_seq in
  let rec describe stream path message = match Hashtbl.find_opt points (stream,path) with
    | Some (p : Mlir.source) ->
        let location = Stdlib.Option.fold p.span ~none:"" ~some:(fun span ->
          Attention_runtime.Source.describe span ^ ": ") in
        location ^ p.origin.opcode ^ ": " ^ message
    | None -> (match List.rev path with
        | _::parent -> describe stream (List.rev parent) message | [] -> message) in
  Device_races.compile_memory ~backend ~iteration_ordinals:true ~describe ~readonly:lowered.readonly
    ~immutable_views:lowered.immutable_views
    lowered.program lowered.memory lowered.bindings

let device_mlir_report ~coverage ~(backend : Bug_traces.backend) ~hivm (lowered : Mlir_device.t) model races =
  let inputs = mlir_inputs lowered.ast_digest lowered.launch and name = lowered.program.name in
  if hivm then (
    let entries = Array.of_list (List.map (fun (s : Mlir.Launch.stream) -> s.entry) lowered.launch.streams) in
    let points = List.to_seq lowered.sources |> Hashtbl.of_seq in
    let location (id : Device_races.identity) =
      let origin = (Hashtbl.find points (id.stream,id.path) : Mlir.source).origin in
      {stream=id.stream;entry=entries.(id.stream);origin;iterations=id.loops;calls=[]} in
    let logical_async op=lowered.launch.hfusion && Mlir_device.bulk_operation op in
    let atomic op=List.mem op ["hivm.hir.debug";"memref.store"] in
    let streams,races = Device_projection.export_events ~full:(Concrete_schedule.full coverage)
      ~logical_async ~atomic ~entries ~location model races in
    to_json {benchmark=name;streams;n=None;inputs;status=coverage_status coverage;races})
  else
    let sources = List.map (fun ((stream,path),source) ->
        `Assoc ["stream",`Int stream;"path",ints path;"origin",mlir_source source]) lowered.sources in
    let status,details=Concrete_schedule.fields coverage in
    `Assoc (["format",`String "core-race-1";"benchmark",`String name;
            "backend",`String (match backend with Search -> "bfs" | Solve -> "smt");
            "status",`String status;"capacity",`Int lowered.launch.capacity;
            "inputs",inputs;"address_unit",`String "bit";"events",Device_races.events model;
            "sources",`List sources;"races",`List races] @ details)

let analyze_mlir ?(timeout_ms=5000) ~backend ?(hivm=false) = function
  | Core_mlir p ->
      let schedule,coverage,races=Concrete_schedule.program ~timeout_ms ~capacity:p.launch.capacity backend p.program in
      core_mlir_report ~coverage ~backend ~hivm p schedule races
  | Device_mlir p ->
      let model=mlir_device_model ~backend p in
      let coverage,races=Device_races.analyze ~timeout_ms model in
      device_mlir_report ~coverage ~backend ~hivm p model races

type stage = HFusion | HIVM
let stage_name = function HFusion -> "hfusion" | HIVM -> "hivm"

let configuration_for stage configuration =
  let expected=`String (stage_name stage) in
  (match J.member "stage" configuration with `Null -> () | value when value=expected -> ()
   | _ -> invalid_arg "IR stage and launch stage differ");
  `Assoc (("stage",expected)::List.remove_assoc "stage" (J.to_assoc configuration))

let report_for_launch ?entry ?(configuration=`Assoc []) ?timeout_ms stage backend ast =
  let lowered=lower_mlir ?entry ~configuration:(configuration_for stage configuration) ast in
  let backend=match backend with Precedence.Bfs -> Bug_traces.Search | Smt -> Solve in
  analyze_mlir ?timeout_ms ~backend ~hivm:true lowered

let verify_mlir_report report inputs capacity unit events =
  if J.member "format" report <> `String "core-race-1" || J.member "inputs" report <> inputs ||
     J.member "capacity" report <> `Int capacity || J.member "address_unit" report <> `String unit ||
     J.member "events" report <> events
  then invalid "MLIR report does not match this source module and launch";
  J.to_list (J.member "races" report)

let project_mlir lowered report =
  let backend=match J.member "backend" report with `String "bfs" -> Bug_traces.Search
    | `String "smt" -> Solve | _ -> invalid "unknown backend in Core report" in
  let source=match lowered with
    | Core_mlir p ->
        let schedule=mlir_schedule ~pair_limit:Loop_trace.threshold p in
        let rows=verify_mlir_report report (mlir_inputs p.ast_digest p.launch) p.launch.capacity
          "byte" (mlir_events p schedule) in
        let coverage=if Concrete_schedule.large schedule || J.member "status" report=`String "unknown" then
            Concrete_schedule.of_report ~rounds:(Concrete_schedule.iteration_counts schedule) report else All_pairs in
        let full=Concrete_schedule.full coverage in
        core_mlir_report ~coverage ~backend ~hivm:true p schedule (List.map (Race_report.read_core_race ~full schedule) rows)
    | Device_mlir p ->
        let model=mlir_device_model ~backend p in
        let rows=verify_mlir_report report (mlir_inputs p.ast_digest p.launch) p.launch.capacity
          "bit" (Device_races.events model) in
        let coverage=if Array.exists (fun n->n>Loop_trace.threshold) model.rounds || J.member "status" report=`String "unknown" then
            Concrete_schedule.of_report ~rounds:model.rounds report else All_pairs in
        List.iter (Device_races.replay_witness ~full:(Concrete_schedule.full coverage) model) rows;
        device_mlir_report ~coverage ~backend ~hivm:true p model rows in
  if J.member "status" source<>J.member "status" report then invalid "inconsistent Core report status";
  source

let replay_mlir lowered report = match lowered with
  | Core_mlir p ->
      let schedule=mlir_schedule ~pair_limit:Loop_trace.threshold p in
      let races=verify_mlir_report report (mlir_inputs p.ast_digest p.launch) p.launch.capacity
        "byte" (mlir_events p schedule) in
      let full=Concrete_schedule.large schedule && Concrete_schedule.full
        (Concrete_schedule.of_report ~rounds:(Concrete_schedule.iteration_counts schedule) report) in
      List.iter (Race_report.replay_core ~full schedule) races;
      2 * List.length races
  | Device_mlir p ->
      let model=mlir_device_model ~backend:Bug_traces.Search p in
      let races=verify_mlir_report report (mlir_inputs p.ast_digest p.launch) p.launch.capacity
        "bit" (Device_races.events model) in
      let full=Array.exists (fun n->n>Loop_trace.threshold) model.rounds &&
        Concrete_schedule.full (Concrete_schedule.of_report ~rounds:model.rounds report) in
      List.iter (Device_races.replay_witness ~full model) races;
      2 * List.length races
