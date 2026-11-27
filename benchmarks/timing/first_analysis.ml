open Stdlib
module H = Hivm_trace
module J = Yojson.Safe.Util

let () =
  let ast = H.Module_ast.read Sys.argv.(1) in
  let configuration = Yojson.Safe.from_file Sys.argv.(2) in
  let backend = match Sys.argv.(3) with
    | "bfs" | "bfs-before" -> Unified_interpreter.Bug_traces.Search
    | "smt" -> Solve
    | _ -> invalid_arg "expected bfs or smt" in
  let lowered = H.lower_mlir ~configuration ast in
  Gc.full_major ();
  let start = Unix.gettimeofday () in
  let report = H.analyze_mlir ~timeout_ms:30000 ~symbolic_prefix:(Sys.argv.(3)<>"bfs-before") ~backend ~hivm:true lowered in
  let elapsed = Unix.gettimeofday () -. start in
  if Array.length Sys.argv=5 && Sys.argv.(4)="--details" then
    prerr_endline (Yojson.Safe.to_string (`Assoc (List.map (fun key->key,J.member key report)
      ["analysis";"graph_loop_bound";"prefix_rounds";"reason"])));
  Printf.printf "%.9f %s %d\n" elapsed (J.member "status" report |> J.to_string)
    (List.length (J.member "races" report |> J.to_list))
