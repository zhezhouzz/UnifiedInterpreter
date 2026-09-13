let () =
  let open Unified_interpreter in
  let cases = Examples.cases () in
  assert (List.length cases = 2);
  List.iter
    (fun case ->
      let execution = Report.execute case in
      Report.agreement case execution
      |> List.iter (fun (_scope, diff) -> assert (diff <= 1e-5));
      let run = List.hd execution.runs in
      assert (run.scope = Interpreter.H5_H4_H3_H2_H1);
      assert (Report.trace_contains run.state "H1 CV-before-map source");
      assert (Report.trace_contains run.state "H2 CV-core-map program_id");
      assert (Report.trace_contains run.state "H3 vector");
      assert (Report.trace_contains run.state "H4 on-chip-memory-map load");
      assert (Report.trace_contains run.state "H4 on-chip-memory-map store");
      assert (Report.trace_contains run.state "H5 alloc.local");
      assert (Report.trace_contains run.state "H5 async.copy.in");
      assert (Report.trace_contains run.state "H5 wait");
      assert (Report.trace_contains run.state "H5 barrier");
      assert (Report.trace_contains run.state "H5 async.copy.out");
      assert (not (Report.trace_contains run.state "H1 load"));
      assert (not (Report.trace_contains run.state "H1 fadd"));
      assert (not (Report.trace_contains run.state "H4 async.copy.in"));
      assert (not (Report.trace_contains run.state "H4 barrier"));
      match case.id with
      | "vector-add" ->
          assert (Report.trace_contains run.state "vector.fadd")
      | "fused-softmax" ->
          assert (Report.trace_contains run.state "vector.reduce.max");
          assert (Report.trace_contains run.state "vector.exp");
          assert (Report.trace_contains run.state "vector.reduce.sum")
      | _ -> assert false)
    cases
