open Attention_runtime
open Yojson.Basic.Util

module E = Extracted_semantics.Unified_semantics

let number = function
  | `Int n -> float_of_int n
  | `Float x -> x
  | _ -> invalid_arg "expected a number"

let array json = json |> to_list |> List.map number |> Array.of_list

let matrix json =
  let rows = json |> to_list |> List.map array in
  if List.length rows <> 128 || List.exists (fun row -> Array.length row <> 128) rows then
    invalid_arg "expected a 128x128 matrix";
  Array.concat rows

let read_input json = {
  Attention.q = json |> member "Q" |> matrix;
  k = json |> member "K" |> matrix;
  v = json |> member "V" |> matrix;
  scale = json |> member "scale" |> number;
}

let read_values json =
  json |> member "O" |> matrix, json |> member "log_sum_exp" |> array

let compare (expected_o, expected_lse) (actual : Attention.output) =
  let same_o, error_o = Attention.compare_array expected_o actual.o in
  let same_lse, error_lse = Attention.compare_array expected_lse actual.lse in
  same_o && same_lse, error_o, error_lse

let require_values label expected actual =
  let same, error_o, error_lse = compare expected actual in
  if not same then
    failwith (Printf.sprintf "%s: O error=%g, log_sum_exp error=%g" label error_o error_lse)

let string key json = json |> member key |> to_string

let check_case ~path ~load ~input case =
  let id = string "id" case and stage = string "stage" case in
  let file = path (string "ir" case) in
  let input = input (string "input" case) in
  let expected = load (string "ir_expected" case) in
  match string "kind" expected with
  | "output" ->
      let result = Attention.run ~stage ~file input in
      require_values id (read_values expected) result;
      let same, _, _ = compare (read_values (load (string "source_expected" case))) result in
      if same then failwith (id ^ ": witness did not distinguish the mutation");
      Printf.printf "%s: mutant output matched and differed from the source\n%!" id
  | "error" when string "error" expected = "ReadUninitialized" ->
      let readback = ref false in
      let trace = function
        | `Assoc fields when List.assoc_opt "entry" fields = Some (`String "materialize_output") ->
            readback := true
        | _ -> () in
      if string "at" expected <> "materialize_output" then failwith (id ^ ": unknown error location");
      (match Attention.run ~stage ~file ~trace input with
      | _ -> failwith (id ^ ": expected ReadUninitialized at output readback")
      | exception Handlers.Semantic_error E.ReadUninitialized when !readback ->
          Printf.printf "%s: ReadUninitialized at output readback\n%!" id)
  | _ -> failwith (id ^ ": unknown expectations")

let () =
  if Array.length Sys.argv <> 2 then invalid_arg "expected the exported dataset directory";
  let path = Filename.concat Sys.argv.(1) in
  let load rel = Yojson.Basic.from_file (path rel) in
  let manifest = load "manifest.json" in
  if string "profile" manifest <> "host-float64" then invalid_arg "unexpected dataset profile";
  let source_expected = read_values (load (string "source_expected" manifest)) in
  let inputs = manifest |> member "inputs" |> to_assoc |> List.map (fun (name, json) ->
    let input = read_input (load (to_string json)) in
    require_values (name ^ " reference") source_expected (Attention.reference input);
    name, input) in
  List.iter (fun (stage, baseline) ->
    let file = path (string "ir" baseline) in
    List.iter (fun (name, input) ->
      require_values (stage ^ " " ^ name ^ " baseline") source_expected
        (Attention.run ~stage ~file input)) inputs)
    (manifest |> member "baselines" |> to_assoc);
  let cases = manifest |> member "cases" |> to_list in
  if cases = [] then failwith "no FlashAttention IR mutations";
  List.iter (check_case ~path ~load ~input:(fun name -> List.assoc name inputs)) cases
