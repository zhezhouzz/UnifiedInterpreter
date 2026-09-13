(* Report/test harness: run all levels, compare outputs, summarize routes. *)

open Language
open Examples

  type execution = {
    top : Interpreter.state;
    core : Interpreter.state;
    vector : Interpreter.state;
    mem_async : Interpreter.state;
    core_ir : core_program;
    vector_ir : vector_program;
    mem_ir : mem_async_program;
    route_results : Routes.route_result list;
  }

  let execute case =
    let core_ir = Lowering.to_core case.command in
    let vector_ir = Lowering.to_vector core_ir in
    let mem_ir = Lowering.to_mem_async vector_ir in
    {
      top = Interpreter.Eval.run_case case Interpreter.Eval.eval_top case.command;
      core = Interpreter.Eval.run_case case Interpreter.Eval.eval_core core_ir;
      vector = Interpreter.Eval.run_case case Interpreter.Eval.eval_vector vector_ir;
      mem_async = Interpreter.Eval.run_case case Interpreter.Eval.eval_mem_async mem_ir;
      core_ir;
      vector_ir;
      mem_ir;
      route_results = Routes.run case;
    }

  let agreement case execution =
    let out = case.output in
    let reference = Interpreter.tensor execution.top out in
    [
      ("L0 vs L1", Tensor.max_abs_diff reference (Interpreter.tensor execution.core out));
      ("L0 vs L2", Tensor.max_abs_diff reference (Interpreter.tensor execution.vector out));
      ("L0 vs L3", Tensor.max_abs_diff reference (Interpreter.tensor execution.mem_async out));
    ]

  let trace_contains state needle =
    Interpreter.trace state
    |> List.exists (fun line ->
           let line_len = String.length line and needle_len = String.length needle in
           let rec loop i =
             i + needle_len <= line_len && (String.sub line i needle_len = needle || loop (i + 1))
           in
           needle_len = 0 || loop 0)

  let unsupported_by_us execution =
    List.exists
      (fun (r : Routes.route_result) ->
        match r.status with Routes.Unsupported_by_us _ -> true | _ -> false)
      execution.route_results

  let pp_trace_sample ?(limit = 20) state =
    let trace = Interpreter.trace state in
    let shown = trace |> List.to_seq |> Seq.take limit |> List.of_seq in
    let body = shown |> List.map (fun line -> "  " ^ line) |> String.concat "\n" in
    if List.length trace > limit then body ^ Printf.sprintf "\n  ... %d more events" (List.length trace - limit)
    else body

  let pp_case case execution =
    let output = Interpreter.tensor execution.mem_async case.output in
    let route_lines =
      execution.route_results
      |> List.map (fun (result : Routes.route_result) ->
             Printf.sprintf "- %s: %s" result.route (Routes.pp_status result.status))
      |> String.concat "\n"
    in
    let agreement_lines =
      agreement case execution
      |> List.map (fun (label, diff) -> Printf.sprintf "- %s max_abs_diff=%.6g" label diff)
      |> String.concat "\n"
    in
    String.concat "\n"
      [
        "## " ^ case.title ^ " (`" ^ case.id ^ "`)";
        "";
        "- Source: " ^ case.source.title ^ " (" ^ case.source.url ^ ")";
        "- Source note: " ^ case.source.note;
        "- Top IR: " ^ pp_top case.command;
        "";
        "### L1 Core IR";
        pp_core execution.core_ir;
        "";
        "### L2 Vector IR";
        pp_vector execution.vector_ir;
        "";
        "### L3 Memory/Async IR";
        pp_mem execution.mem_ir;
        "";
        "### Internal Agreement";
        agreement_lines;
        "";
        "### Output";
        Tensor.pp output;
        "";
        "### External Routes";
        route_lines;
        "";
        "### Extra Effect Trace";
        pp_trace_sample execution.mem_async;
      ]
