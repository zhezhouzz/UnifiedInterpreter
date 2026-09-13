let () =
  let open Unified_interpreter in
  let cases = Adapters.cases () in
  assert (List.length cases = 5);
  List.iter
    (fun case ->
      let execution = Report.execute case in
      let tolerance = if case.id = "layer-norm" then 5e-3 else 1e-5 in
      Report.agreement case execution
      |> List.iter (fun (_label, diff) -> assert (diff <= tolerance));
      assert (not (Report.unsupported_by_us execution));
      let has needle = Report.trace_contains execution.mem_async needle in
      (match case.id with
      | "vector-add" -> assert (has "vector.add")
      | "fused-softmax" ->
          assert (has "vector.reduce.max");
          assert (has "vector.exp");
          assert (has "vector.reduce.sum")
      | "layer-norm" ->
          assert (has "bf16ish");
          assert (has "vector.sqrt")
      | "matmul-bias" ->
          assert (has "vector.fma");
          assert (has "async.copy");
          assert (has "barrier")
      | "toy-transpose-mul" ->
          assert (has "tensor_to_memref");
          assert (has "affine")
      | _ -> assert false))
    cases
