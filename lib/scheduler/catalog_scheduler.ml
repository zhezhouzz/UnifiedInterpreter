module Ast = Hivm_trace.Module_ast
module J = Yojson.Safe.Util
module Order = Unified_interpreter.Event_order
module P = Unified_interpreter.Precedence
type stage = Source_scheduler.stage = HFusion | HIVM
type program = Tensor of Hfusion_trace.t | Device of Hivm_trace.pairing | Module of stage * Ast.t * Yojson.Safe.t
let explicit inputs = `Assoc ["kind",`String "explicit";"value",inputs]
let field k x = J.member k x
let integers x = List.map J.to_int (J.to_list x)
module Loop = Unified_interpreter.Loop_trace

let event_rounds events =
  let seen=Hashtbl.create 8 in
  let rounds e=match field "iterations" e with `Null -> 0 | xs -> Loop.rounds (integers xs) in
  Array.map (fun e ->
    let stream=J.to_int (field "stream" e) in
    let calls=match field "calls" e with `Null -> [] | xs -> J.to_list xs in
    let k=List.fold_left (fun n frame -> max n (rounds frame)) (rounds e) calls in
    let k=max k (Option.value (Hashtbl.find_opt seen stream) ~default:0) in
    Hashtbl.replace seen stream k;k) events
let stage_name = Source_scheduler.stage_name

let compile request =
  let module Parser = Attention_runtime.Parser in
  let root = match Sys.getenv_opt "ATTENTION_ROOT" with
    | Some path -> path | None -> Parser.project_root (Sys.getcwd ()) in
  let script = Filename.concat root "scripts/scheduler_module.py" in
  let python = Filename.concat root ".venv-attention/bin/python" in
  let channels = Unix.open_process_args_full python [|python;"-B";script|] (Unix.environment ()) in
  let stdout,stdin,stderr = channels in
  Yojson.Safe.to_channel stdin request; close_out stdin;
  let output,error = Parser.read_both stdout stderr in
  match Unix.close_process_full channels with
  | WEXITED 0 -> Yojson.Safe.from_string output
  | _ -> failwith error

let prepare ?n name stage ast launch =
  let compiled = compile (`Assoc ["module",Ast.scheduling_json ast;
    "stage",`String (stage_name stage);"name",`String name;"launch",launch;
    "n",Option.fold ~none:`Null ~some:(fun n -> `Int n) n]) in
  if ast.format="mlir-module-1" then begin
    let configuration = field "configuration" compiled in
    let lowered = Hivm_trace.Mlir.lower ~configuration ast in
    let nodes,pairs = Hivm_trace.source_event_order lowered in
    let rules = Array.map (fun (_,parents) ->
      Order.{requires=List.map (fun i -> [i]) parents;excludes=[]}) nodes in
    Array.map fst nodes,rules,pairs,field "inputs" compiled,"complete"
  end else
  let nodes = J.to_list (field "nodes" compiled) |> Array.of_list in
  let rules = Array.map (fun node -> Order.{requires=List.map integers (J.to_list (field "requires" node));
        excludes=integers (field "excludes" node)}) nodes in
  let pairs = List.map (fun x -> match integers x with [a;b] -> a,b | _ -> invalid_arg "invalid conflict")
      (J.to_list (field "pairs" compiled)) in
  let events = Array.map (field "event") nodes in
  events,rules,pairs,field "inputs" compiled,
    Option.value (J.to_string_option (field "status" compiled)) ~default:"complete"

let generate ?n ?kv_heads ?timeout_ms ~name backend = function
  | Device p ->
      let method_ = Unified_interpreter.Benchmark_traces.Concrete
        (match backend with P.Bfs -> Search | Smt -> Solve) in
      Hivm_trace.generate ?n ?kv_heads ?timeout_ms method_ p |> Hivm_trace.to_json
  | Tensor p ->
      let b = match backend with P.Bfs -> Hfusion_trace.Bfs | Smt -> Smt in
      let doc = Hfusion_trace.generate ?n:(Option.map Z.of_int n) ?timeout_ms b p |> Hfusion_trace.to_json in
      `Assoc (("benchmark",`String name)::J.to_assoc doc)
  | Module (stage,ast,launch) when ast.format="mlir-module-1" &&
      (field "kind" launch=`Null || (field "kind" launch=`String "explicit" &&
       field "instances" (field "value" launch)=`Null)) ->
      let configuration=match field "kind" launch with `String "explicit" -> field "value" launch
        | `Null -> launch | _ -> invalid_arg "parsed MLIR requires concrete launch parameters" in
      let doc=Source_scheduler.generate ~configuration ?timeout_ms stage backend ast in
      `Assoc (("benchmark",`String name)::List.remove_assoc "benchmark" (J.to_assoc doc))
  | Module (stage,ast,launch) ->
      let events,rules,pairs,inputs,status = prepare ?n name stage ast launch in
      let trace xs = `List (List.map (Array.get events) xs) in
      let rounds=event_rounds events in
      let rows,status,details=if status<>"complete" then
        [],"unknown",["reason",`String "the module model ends before program termination"]
      else if Array.exists (fun n->n>Loop.threshold) rounds then
        match Order.complete_race ?timeout_ms rules rounds pairs with
        | Found (k,row) -> [row],"race",["trace_extent",`String "program_end";"prefix_rounds",`Int k]
        | No_race -> [],"no-race",[] | Incomplete why -> [],"unknown",["reason",`String why]
        else Order.generate ?timeout_ms backend rules pairs,status,[] in
      let races = rows |> List.map (fun (a,b,f,r) ->
        `Assoc ["first",events.(a);"second",events.(b);"forward",trace f;"reverse",trace r]) in
      if status="race" && races=[] then invalid_arg "no reversible conflict in the prefix";
      `Assoc (["format",`String "ir-race-1";"stage",`String (stage_name stage);"benchmark",`String name;
        "source_sha256",`String (Option.get ast.source_sha256);"inputs",inputs;
        "n",Option.fold ~none:`Null ~some:(fun n -> `Int n) n;"status",`String status;"races",`List races] @ details)

let replay_module ast doc =
  let stage = match J.to_string (field "stage" doc) with "hivm" -> HIVM | "hfusion" -> HFusion
    | _ -> invalid_arg "unknown IR stage" in
  if field "format" doc <>`String "ir-race-1" ||
     J.to_string_option (field "source_sha256" doc) <> ast.Ast.source_sha256
  then invalid_arg "trace source mismatch";
  let name = J.to_string (field "benchmark" doc) in
  let events,rules,pairs,_,status = prepare ?n:(J.to_int_option (field "n" doc))
      name stage ast (explicit (field "inputs" doc)) in
  let ids = Hashtbl.create (Array.length events) in
  Array.iteri (fun i e -> let key = Yojson.Safe.sort e in
    if Hashtbl.mem ids key then invalid_arg "ambiguous dynamic event"; Hashtbl.add ids key i) events;
  let id e = Hashtbl.find ids (Yojson.Safe.sort e) in
  let can_extend=Order.can_extend rules in
  let races = J.to_list (field "races" doc) in
  let full=field "trace_extent" doc=`String "program_end" in
  if status<>"complete" then (
    if field "status" doc<>`String "unknown" || races<>[] then invalid_arg "unverified module continuation")
  else if Array.exists (fun k->k>Loop.threshold) (event_rounds events) then (
    match field "status" doc,races with
    | `String "race",[_] when full -> () | `String ("unknown"|"no-race"),[] -> ()
    | _ -> invalid_arg "invalid large-loop trace status")
  else if field "status" doc <> `String status || (status="race" && races=[]) then invalid_arg "invalid trace status";
  List.iter (fun race ->
    let a = id (field "first" race) and b = id (field "second" race) in
    if not (List.mem (a,b) pairs || List.mem (b,a) pairs) then invalid_arg "unrelated memory events";
    let check key x y = let steps = List.map id (J.to_list (field key race)) in
      Order.replay rules steps;
      if not full && not (can_extend steps) then invalid_arg "race prefix cannot reach program end";
      if List.filter (fun n -> n=x || n=y) steps<>[x;y] ||
         (if full then List.length steps<>Array.length events else List.hd (List.rev steps)<>y)
      then invalid_arg "invalid target order" in
    check "forward" a b; check "reverse" b a) races;
  List.length races
