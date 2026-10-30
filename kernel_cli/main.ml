open Attention_runtime

let numbers data = `List (Array.to_list (Array.map (fun x -> `Float x) data))

let main () =
  let kernel = ref "vector-add" and stage = ref "both" and ir = ref "" in
  let output = ref "" and trace = ref "" and max_steps = ref 1000000 in
  let length = ref None in
  Arg.parse [
    "--kernel",Arg.Set_string kernel,"vector-add|row-sum (default vector-add)";
    "--stage",Arg.Set_string stage,"hfusion|hivm|mixed|both (default both)";
    "--ir",Arg.Set_string ir,"MLIR file for a single stage";
    "--length",Arg.Int (fun n -> length := Some n),"Input length for compiled vector-add (default 513)";
    "--output",Arg.Set_string output,"Result JSON (default stdout)";
    "--trace",Arg.Set_string trace,"JSONL primitive trace";
    "--max-steps",Arg.Set_int max_steps,"Execution budget (default 1000000)";
  ] (fun s -> invalid_arg ("unexpected argument " ^ s)) "kernel-example [options]";
  if not (List.mem !stage ["hfusion";"hivm";"mixed";"both"]) then
    invalid_arg "invalid stage";
  if !stage = "both" && !ir <> "" then invalid_arg "--ir requires a single stage";
  let example = Kernel_examples.get !kernel in
  let channel = if !trace = "" then None else Some (open_out !trace) in
  Fun.protect ~finally:(fun () -> Option.iter close_out channel) (fun () ->
    let stages = if !stage = "both" then ["hfusion";"hivm"] else [!stage] in
    let results = List.map (fun stage ->
      let file = if !ir = "" then Kernel_examples.file example stage else !ir in
      let emit event = Option.iter (fun channel ->
        let event = match event with
          | `Assoc fields -> `Assoc (("stage",`String stage)::fields)
          | _ -> invalid_arg "invalid trace event" in
        Yojson.Basic.to_channel channel event; output_char channel '\n') channel in
      let compiled_vector = example.name = "vector-add" && !ir <> "" &&
        List.exists (function _,Parser.ShapedType ("memref",[-1],_) -> true | _ -> false)
          (Parser.parse ~file (Attention.read_file file)).arguments in
      let result,expected = if compiled_vector then begin
        let n = Option.value !length ~default:513 in
        if n < 0 || n > 2147483647 then invalid_arg "invalid vector-add length";
        let a = Array.init n (fun i -> float_of_int (i mod 31 - 15) /. 4.) in
        let b = Array.init n (fun i -> float_of_int (i mod 17 - 8) /. 8.) in
        Vector_add.run ~stage ~max_steps:!max_steps ~trace:emit ~file a b,
        Array.map2 ( +. ) a b
      end else begin
        if !length <> None then invalid_arg "--length requires a compiled vector-add IR";
        Kernel.run ~stage ~max_steps:!max_steps ~trace:emit ~file example.bindings, example.expected
      end in
      let data = match result.outputs with
        | [output] when output.name = "%out" -> output
        | _ -> invalid_arg "example requires one %out buffer" in
      let passed,error = Attention.compare_array expected data.data in
      Printf.eprintf "%s/%s: steps=%d calls=%d max_error=%g\n%!"
        example.name stage result.steps result.calls error;
      passed,`Assoc ["stage",`String stage;"ir",`String file;
        "shape",`List (List.map (fun n -> `Int n) data.shape);
        "output",numbers data.data;"reference",numbers expected;
        "steps",`Int result.steps;"primitive_calls",`Int result.calls;
        "reference_passed",`Bool passed;"max_absolute_error",`Float error]
    ) stages in
    let passed = List.for_all fst results in
    let json = `Assoc ["kernel",`String example.name;"profile",`String "host-float64";
      "stages",`List (List.map snd results);"passed",`Bool passed] in
    if !output = "" then (Yojson.Basic.pretty_to_channel stdout json;print_newline ())
    else Yojson.Basic.to_file !output json;
    if not passed then failwith "kernel reference comparison failed")

let () =
  try main () with
  | Source.Error (span,message) ->
      Printf.eprintf "%s: %s\n%!" (Source.describe span) message;exit 1
  | Invalid_argument message | Failure message ->
      Printf.eprintf "kernel-example: %s\n%!" message;exit 1
