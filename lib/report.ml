(* Report/test harness for the nested, non-overlapping handler stack. *)

open Language

type run_result = {
  state : Interpreter.state;
}

type execution = { runs : run_result list }

let execute case = { runs = [ { state = Interpreter.run_case case } ] }

let reference_run execution =
  match execution.runs with
  | first :: _ -> first
  | [] -> invalid_arg "empty execution"

let tensor_of case run = Interpreter.tensor run.state case.output

let agreement case execution =
  let reference = tensor_of case (reference_run execution) in
  execution.runs
  |> List.map (fun run ->
         ("in-program handlers", Tensor.max_abs_diff reference (tensor_of case run)))

let trace_contains state needle =
  Interpreter.trace state
  |> List.exists (fun line ->
         let line_len = String.length line and needle_len = String.length needle in
         let rec loop i =
           i + needle_len <= line_len
           && (String.sub line i needle_len = needle || loop (i + 1))
         in
         needle_len = 0 || loop 0)

let pp_trace_sample ?(limit = 28) state =
  let trace = Interpreter.trace state in
  let shown = trace |> List.to_seq |> Seq.take limit |> List.of_seq in
  let body = shown |> List.map (fun line -> "  " ^ line) |> String.concat "\n" in
  if List.length trace > limit then
    body ^ Printf.sprintf "\n  ... %d more events" (List.length trace - limit)
  else body

let pp_run case run =
  String.concat "\n"
    [
      "#### In-program handler scopes";
      "";
      "Output:";
      Tensor.pp (tensor_of case run);
      "";
      "Trace:";
      pp_trace_sample run.state;
    ]

let pp_case case execution =
  let agreement_lines =
    agreement case execution
    |> List.map (fun (scope, diff) ->
           Printf.sprintf "- %s max_abs_diff_vs_reference=%.6g" scope diff)
    |> String.concat "\n"
  in
  String.concat "\n"
    [
      "## " ^ case.title ^ " (`" ^ case.id ^ "`)";
      "";
      "- Source: " ^ case.source.title ^ " (" ^ case.source.url ^ ")";
      "- Source note: " ^ case.source.note;
      "- Grid: " ^ string_of_int case.grid;
      "";
      "### Triton-like Source";
      "```" ^ case.source_language;
      String.trim case.source_text;
      "```";
      "";
      "### Handler Result";
      agreement_lines;
      "";
      "### Handler Runs";
      execution.runs |> List.map (pp_run case) |> String.concat "\n\n";
    ]
