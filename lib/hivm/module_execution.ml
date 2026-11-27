open Stdlib
open Unified_interpreter
include Source_execution
module Delivery = Source_schedules.Trace_delivery
module J = Yojson.Safe.Util

let run_builtin = Source_execution.run_module

let next_trace ?db_path ?timeout_ms ?max_steps ?(backend=Precedence.Bfs) ~stage ~launch ast =
  let configuration = Mlir_trace.configuration_for stage launch in
  let stage_name = Mlir_trace.stage_name stage in
  let bound = Mlir_launch.bind ~configuration ast in
  let stream (s : Mlir_launch.stream) =
    let pipes = match s.pipes with
      | None -> `Null
      | Some ps -> `List (List.map (fun p -> `String (Core_lang.Device.pipe_name p)) ps) in
    `List [`String s.entry; pipes] in
  let edges = match bound.edges with
    | None -> `Null
    | Some xs -> `List (List.map (fun (a,b) -> `List [`Int a;`Int b]) (List.sort compare xs)) in
  let local = match J.member "local_initial" configuration with `Null -> `List [] | rows -> rows in
  let identity = `List [Hivm_module.execution_json ast; `String stage_name; Mlir_launch.inputs bound;
                        `List (List.map stream bound.streams); `Int bound.capacity; edges; local] in
  let identity=match backend with Precedence.Smt->identity | Bfs->`List [`String "bfs-terminal";identity] in
  let analyze ~timeout_ms = Mlir_trace.report_for_launch ~configuration ~timeout_ms stage backend ast in
  let execute choose =
    (Source_execution.run_module ~quiet:true ~choose ?max_steps ~stage:stage_name ~launch ast).status in
  Delivery.next_trace ?db_path ?timeout_ms ~identity ~analyze ~execute ()

let execute_trace ?max_steps ?trace ?on_read ~stage ~launch ast schedule =
  let choose,verify = Delivery.replay schedule in
  let result = Source_execution.run_module ~choose ?max_steps ?trace ?on_read
    ~stage:(Mlir_trace.stage_name stage) ~launch ast in
  verify result.status;
  result

let run_scheduled ?db_path ?timeout_ms ?max_steps ?backend ?trace ?on_read ~stage ~launch ast =
  let schedule = next_trace ?db_path ?timeout_ms ?max_steps ?backend ~stage ~launch ast in
  schedule, execute_trace ?max_steps ?trace ?on_read ~stage ~launch ast schedule

let run_module ?db_path ?timeout_ms ?max_steps ?trace ?on_read ~stage ~launch ast =
  let stage = match stage with
    | "hivm" -> Mlir_trace.HIVM | "hfusion" -> HFusion | _ -> invalid_arg "unknown source stage" in
  snd (run_scheduled ?db_path ?timeout_ms ?max_steps ?trace ?on_read ~stage ~launch ast)
