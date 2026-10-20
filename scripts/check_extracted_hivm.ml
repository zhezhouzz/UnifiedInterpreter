(* This executable calls Rocq extraction, not the hand-written lib interpreter.
   The numeric test model checks wiring/structure, not NPU floating-point bits. *)
let () =
  let checks = Unified_semantics.extracted_checks in
  if List.length checks <> 5 then failwith "unexpected extracted check count";
  List.iteri
    (fun i passed ->
      if not passed then failwith (Printf.sprintf "HIVM extracted check %d failed" i))
    checks;
  if not Unified_semantics.memory_check then
    failwith "HIVM extracted memory/lens composition failed";
  if Unified_semantics.exceptional_checks <> [true; true] then
    failwith "HIVM extracted NaN propagation checks failed";
  print_endline "HIVM extraction: 5 compute, 2 NaN checks and memory/lens composition passed."
