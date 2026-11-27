module Ast = Hivm_trace.Module_ast
type stage = HFusion | HIVM
let stage_name = function HFusion -> "hfusion" | HIVM -> "hivm"

let generate ?entry ?(configuration=`Assoc []) ?timeout_ms stage backend ast =
  let module J = Yojson.Safe.Util in
  let expected=`String (stage_name stage) in
  (match J.member "stage" configuration with `Null -> () | value when value=expected -> ()
   | _ -> invalid_arg "IR stage and launch stage differ");
  let configuration=`Assoc (("stage",expected)::List.remove_assoc "stage" (J.to_assoc configuration)) in
  let lowered=Hivm_trace.Source.lower_mlir ?entry ~configuration ast in
  let backend=match backend with
    | Unified_interpreter.Precedence.Bfs -> Unified_interpreter.Bug_traces.Search
    | Smt -> Solve in
  Hivm_trace.Source.analyze_mlir ?timeout_ms ~backend ~hivm:true lowered
