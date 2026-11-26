module Ast = Hivm_trace.Module_ast
module J = Yojson.Safe.Util
module Order = Unified_interpreter.Event_order
module P = Unified_interpreter.Precedence
type stage = HFusion | HIVM
type program = Tensor of Hfusion_trace.t | Device of Hivm_trace.pairing | Module of stage * Ast.t * Yojson.Safe.t
let explicit inputs = `Assoc ["kind",`String "explicit";"value",inputs]
let field k x = J.member k x
let integers x = List.map J.to_int (J.to_list x)
let stage_name = function HFusion -> "hfusion" | HIVM -> "hivm"

let generate_mlir ?entry ?(configuration=`Assoc []) stage backend ast =
  let expected=`String (stage_name stage) in
  (match field "stage" configuration with `Null -> () | stage when stage=expected -> ()
   | _ -> invalid_arg "IR stage and launch stage differ");
  let configuration=`Assoc (("stage",expected)::List.remove_assoc "stage" (J.to_assoc configuration)) in
  let lowered=Hivm_trace.lower_mlir ?entry ~configuration ast in
  let backend=match backend with P.Bfs -> Unified_interpreter.Bug_traces.Search | Smt -> Solve in
  Hivm_trace.analyze_mlir ~backend ~hivm:true lowered

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
      let doc=generate_mlir ~configuration stage backend ast in
      `Assoc (("benchmark",`String name)::List.remove_assoc "benchmark" (J.to_assoc doc))
  | Module (stage,ast,launch) ->
      let events,rules,pairs,inputs,status = prepare ?n name stage ast launch in
      let trace xs = `List (List.map (Array.get events) xs) in
      let races = Order.generate ?timeout_ms backend rules pairs |> List.map (fun (a,b,f,r) ->
        `Assoc ["first",events.(a);"second",events.(b);"forward",trace f;"reverse",trace r]) in
      if status="race" && races=[] then invalid_arg "no reversible conflict in the prefix";
      `Assoc ["format",`String "ir-race-1";"stage",`String (stage_name stage);"benchmark",`String name;
        "source_sha256",`String (Option.get ast.source_sha256);"inputs",inputs;
        "n",Option.fold ~none:`Null ~some:(fun n -> `Int n) n;"status",`String status;"races",`List races]

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
  let races = J.to_list (field "races" doc) in
  if field "status" doc <> `String status || (status="race" && races=[]) then invalid_arg "invalid trace status";
  List.iter (fun race ->
    let a = id (field "first" race) and b = id (field "second" race) in
    if not (List.mem (a,b) pairs || List.mem (b,a) pairs) then invalid_arg "unrelated memory events";
    let check key x y = let steps = List.map id (J.to_list (field key race)) in
      Order.replay rules steps;
      match List.rev steps with last::rest when last=y && List.mem x rest -> () | _ -> invalid_arg "invalid target order" in
    check "forward" a b; check "reverse" b a) races;
  List.length races
