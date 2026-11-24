open Attention_runtime

let numbers data = `List (Array.to_list (Array.map (fun x -> `Float x) data))

let scalar = function
  | `Int n -> Numeric.Integer (Int64.of_int n)
  | `Intlit n -> Numeric.Integer (Int64.of_string n)
  | `Float x -> Numeric.Floating x
  | _ -> invalid_arg "kernel input requires a number"

let bindings input =
  let open Yojson.Safe.Util in
  Yojson.Safe.from_file input |> to_assoc |> List.map (fun (name,value) ->
    let argument = match value with
      | `Assoc fields ->
          List.iter (fun (key,_) ->
            if not (List.mem key ["shape";"data";"output"]) then
              invalid_arg ("unknown kernel buffer field: " ^ key)) fields;
          let shape = value |> member "shape" |> to_list |> List.map to_int in
          let data = match List.assoc_opt "data" fields with
            | None -> None | Some items -> Some (List.map scalar (to_list items)) in
          let output = match List.assoc_opt "output" fields with
            | None -> false | Some flag -> to_bool flag in
          Kernel.Buffer {shape;data;output}
      | value -> Kernel.Scalar (scalar value) in
    name,argument)

let cell_json = function
  | Numeric.Integer n -> `Intlit (Int64.to_string n)
  | Numeric.Floating x when Float.is_finite x -> `Float x
  | Numeric.Floating x -> `String (Printf.sprintf "%g" x)
  | Numeric.Undefined -> invalid_arg "uninitialized output element"

let emit_trace channel stage event = Option.iter (fun channel ->
  let event = match event with
    | `Assoc fields -> `Assoc (("stage",`String stage)::fields)
    | _ -> invalid_arg "invalid trace event" in
  Yojson.Basic.to_channel channel event; output_char channel '\n') channel

let run_bound ~file ~stage ~max_steps ~trace ~input ~output =
  let result = Kernel.run_bound ~file ~stage ~max_steps ~trace (bindings input) in
  let outputs = List.map (fun (buffer : Kernel.buffer) ->
    `Assoc ["name",`String buffer.name;
      "shape",`List (List.map (fun n -> `Int n) buffer.shape);
      "data",`List (List.map cell_json buffer.cells)]) result.buffers in
  let json = `Assoc ["profile",`String "host-float64";"stage",`String stage;"ir",`String file;
    "outputs",`List outputs;"steps",`Int result.steps;"primitive_calls",`Int result.calls] in
  Printf.eprintf "%s: steps=%d calls=%d\n%!" stage result.steps result.calls;
  if output = "" then (Yojson.Safe.pretty_to_channel stdout json; print_newline ())
  else Yojson.Safe.to_file output json

let main () =
  let kernel = ref "vector-add" and stage = ref "both" and ir = ref "" in
  let input = ref "" and output = ref "" and trace = ref "" and max_steps = ref 1000000 in
  let length = ref None in
  Arg.parse [
    "--kernel",Arg.Set_string kernel,"vector-add|row-sum (default vector-add)";
    "--stage",Arg.Set_string stage,"hfusion|hivm|mixed|both (default both)";
    "--ir",Arg.Set_string ir,"MLIR file for a single stage";
    "--input",Arg.Set_string input,"JSON bindings for the entry arguments of --ir";
    "--length",Arg.Int (fun n -> length := Some n),"Input length for compiled vector-add (default 513)";
    "--output",Arg.Set_string output,"Result JSON (default stdout)";
    "--trace",Arg.Set_string trace,"JSONL primitive trace";
    "--max-steps",Arg.Set_int max_steps,"Execution budget (default 1000000)";
  ] (fun s -> invalid_arg ("unexpected argument " ^ s)) "kernel-example [options]";
  if not (List.mem !stage ["hfusion";"hivm";"mixed";"both"]) then
    invalid_arg "invalid stage";
  if !stage = "both" && !ir <> "" then invalid_arg "--ir requires a single stage";
  if !input <> "" && (!ir = "" || !length <> None) then
    invalid_arg "--input requires --ir and no --length";
  let channel = if !trace = "" then None else Some (open_out !trace) in
  Fun.protect ~finally:(fun () -> Option.iter close_out channel) (fun () ->
    if !input <> "" then
      run_bound ~file:!ir ~stage:!stage ~max_steps:!max_steps
        ~trace:(emit_trace channel !stage) ~input:!input ~output:!output
    else
    let example = Kernel_examples.get !kernel in
    let stages = if !stage = "both" then ["hfusion";"hivm"] else [!stage] in
    let results = List.map (fun stage ->
      let file = if !ir = "" then Kernel_examples.file example stage else !ir in
      let emit = emit_trace channel stage in
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
  | Yojson.Json_error message | Yojson.Safe.Util.Type_error (message,_) ->
      Printf.eprintf "kernel-example: %s\n%!" message;exit 1
