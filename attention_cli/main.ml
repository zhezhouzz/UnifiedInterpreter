open Attention_runtime

let json_number = function
  | `Float x -> x | `Int x -> float_of_int x
  | _ -> invalid_arg "expected JSON number"
let matrix = function
  | `List rows when List.length rows = 128 ->
      rows |> List.map (function
        | `List xs when List.length xs = 128 -> List.map json_number xs
        | _ -> invalid_arg "matrix must have 128 columns")
      |> List.concat |> Array.of_list
  | _ -> invalid_arg "matrix must have 128 rows"
let input_file path =
  match Yojson.Basic.from_file path with
  | `Assoc fields ->
      let get name = match List.assoc_opt name fields with
        | Some x -> matrix x | None -> invalid_arg ("missing " ^ name) in
      let scale = match List.assoc_opt "scale" fields with
        | None -> 1. /. sqrt 128. | Some x -> json_number x in
      {Attention.q=get "Q"; k=get "K"; v=get "V"; scale}
  | _ -> invalid_arg "input must be an object"
let array xs = `List (Array.to_list (Array.map (fun x ->
  if Float.is_finite x then `Float x
  else invalid_arg "non-finite output") xs))
let matrix_json xs =
  `List (List.init 128 (fun i -> array (Array.sub xs (i*128) 128)))

let main () =
  let stage = ref "both" and ir = ref "" and input = ref "" in
  let output = ref "" and trace = ref "" and max_steps = ref 1000000 in
  Arg.parse [
    "--stage",Arg.Set_string stage,"hfusion|hivm|mixed|both (default both)";
    "--ir",Arg.Set_string ir,"MLIR file (required for mixed)";
    "--input",Arg.Set_string input,"JSON with 128x128 Q/K/V and optional scale";
    "--output",Arg.Set_string output,"Result JSON (default stdout)";
    "--trace",Arg.Set_string trace,"JSONL primitive trace";
    "--max-steps",Arg.Set_int max_steps,"Execution budget (default 1000000)";
  ] (fun s -> invalid_arg ("unexpected argument " ^ s)) "attention [options]";
  if not (List.mem !stage ["hfusion";"hivm";"mixed";"both"]) then invalid_arg "invalid stage";
  if !stage = "both" && !ir <> "" then invalid_arg "--ir requires a single stage";
  if !stage = "mixed" && !ir = "" then invalid_arg "--stage mixed requires --ir";
  if !max_steps <= 0 then invalid_arg "--max-steps must be positive";
  let input = if !input = "" then Attention.default_input () else input_file !input in
  Attention.validate_input input;
  let expected = Attention.reference input in
  let trace_channel = if !trace = "" then None else Some (open_out !trace) in
  Fun.protect ~finally:(fun () -> Option.iter close_out trace_channel) (fun () ->
    let stages = if !stage = "both" then ["hfusion";"hivm"] else [!stage] in
    let results = List.map (fun stage ->
      let file = if !ir <> "" then !ir else
          "artifacts/flash_attention/ir/" ^
          (if stage = "hfusion" then "hfusion_level.mlir" else "attention_hivm_compute.mlir") in
      let emit event = Option.iter (fun channel ->
        let event = match event with `Assoc fields -> `Assoc (("stage",`String stage)::fields)
          | _ -> event in
        Yojson.Basic.to_channel channel event; output_char channel '\n') trace_channel in
      let result = Attention.run ~stage ~max_steps:!max_steps ~trace:emit ~file input in
      let passed_o,error_o = Attention.compare_array expected.o result.o in
      let passed_lse,error_lse = Attention.compare_array expected.lse result.lse in
      Printf.eprintf "%s: steps=%d calls=%d max_error(O)=%g max_error(LSE)=%g\n%!"
        stage result.steps result.calls error_o error_lse;
      stage,result,passed_o && passed_lse,`Assoc [
        "stage",`String stage; "ir",`String file;
        "O",matrix_json result.o; "log_sum_exp",array result.lse;
        "steps",`Int result.steps;"primitive_calls",`Int result.calls;
        "reference_passed",`Bool (passed_o && passed_lse);
        "max_absolute_error_O",`Float error_o;"max_absolute_error_LSE",`Float error_lse]
    ) stages in
    let cross = match results with
      | [_,a,_,_;_,b,_,_] ->
          let po,eo = Attention.compare_array a.o b.o in
          let pl,el = Attention.compare_array a.lse b.lse in
          po && pl, `Assoc ["passed",`Bool (po && pl);
            "max_absolute_error_O",`Float eo;"max_absolute_error_LSE",`Float el]
      | _ -> true,`Null in
    let passed = fst cross && List.for_all (fun (_,_,p,_) -> p) results in
    let json = `Assoc [
      "profile",`String "host-float64";
      "configuration",`Assoc ["batch",`Int 1;"heads",`Int 1;"N",`Int 128;
        "D",`Int 128;"causal",`Bool false;"program_count",`Int 20;
        "scale",`Float input.scale];
      "stages",`List (List.map (fun (_,_,_,j) -> j) results);
      "cross_stage",snd cross;"passed",`Bool passed] in
    if !output = "" then (Yojson.Basic.pretty_to_channel stdout json; print_newline ())
    else Yojson.Basic.to_file !output json;
    if not passed then failwith "attention reference comparison failed")

let () =
  try main () with
  | Source.Error (span,message) ->
      Printf.eprintf "%s: %s\n%!" (Source.describe span) message; exit 1
  | Invalid_argument message | Failure message ->
      Printf.eprintf "attention: %s\n%!" message; exit 1
