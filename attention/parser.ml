module E = Extracted_semantics.Unified_semantics
open Yojson.Basic.Util

type typ = ScalarType of E.mlir_type | ShapedType of string * int list * E.mlir_type
type operation = {
  result : string option;
  opcode : string;
  stage : Stage.t;
  operands : string list;
  operand_types : typ list;
  result_type : typ option;
  inputs : string list;
  outputs : string list;
  attributes : (string * Yojson.Basic.t) list;
  region : operation list;
  region_arguments : (string * typ) list;
  span : Source.span;
}
type program = { name : string; arguments : (string * typ) list; body : operation list }

let scalar_type = function
  | "f16" -> E.Float16Type | "f32" -> E.Float32Type | "index" -> E.IndexType
  | "i1" -> E.IntegerType (1,E.Signless) | "i8" -> E.IntegerType (8,E.Signless)
  | "i32" -> E.IntegerType (32,E.Signless) | "i64" -> E.IntegerType (64,E.Signless)
  | s -> invalid_arg ("unsupported scalar type " ^ s)

let typ json =
  let element = json |> member "element" |> to_string |> scalar_type in
  match json |> member "kind" |> to_string with
  | "scalar" -> ScalarType element
  | ("tensor" | "memref") as kind ->
      ShapedType (kind,json |> member "shape" |> to_list |> List.map to_int,element)
  | s -> invalid_arg ("unsupported type kind " ^ s)

let position json = {
  Source.offset = json |> member "offset" |> to_int;
  line = json |> member "line" |> to_int;
  column = json |> member "column" |> to_int;
}
let span json = {
  Source.file = json |> member "file" |> to_string;
  start = position (member "start" json);
  stop = position (member "stop" json);
}
let argument json = json |> member "name" |> to_string, typ (member "type" json)
let optional f = function `Null -> None | json -> Some (f json)
let strings json = json |> to_list |> List.map to_string
let rec operation json = {
  result = optional to_string (member "result" json);
  opcode = json |> member "opcode" |> to_string;
  stage = json |> member "opcode" |> to_string |> Stage.of_opcode;
  operands = strings (member "operands" json);
  operand_types = json |> member "operand_types" |> to_list |> List.map typ;
  result_type = optional typ (member "result_type" json);
  inputs = strings (member "inputs" json);
  outputs = strings (member "outputs" json);
  attributes = json |> member "attributes" |> to_assoc;
  region = json |> member "region" |> to_list |> List.map operation;
  region_arguments = json |> member "region_arguments" |> to_list |> List.map argument;
  span = span (member "span" json);
}

let rec project_root directory =
  if Sys.file_exists (Filename.concat directory ".venv-attention/bin/python") &&
     Sys.file_exists (Filename.concat directory "scripts/attention_frontend.py")
  then directory
  else
    let parent = Filename.dirname directory in
    if parent = directory then
      failwith "Set ATTENTION_ROOT to the repository with its attention Python environment";
    project_root parent

let parse ~file input =
  let root = match Sys.getenv_opt "ATTENTION_ROOT" with
    | Some path -> path | None -> project_root (Sys.getcwd ()) in
  let python = Filename.concat root ".venv-attention/bin/python" in
  let frontend = Filename.concat root "scripts/attention_frontend.py" in
  let channels = Unix.open_process_args_full python [|python;"-B";frontend;file|] (Unix.environment ()) in
  let stdout,stdin,stderr = channels in
  output_string stdin input;
  close_out stdin;
  let output = In_channel.input_all stdout in
  let diagnostic = In_channel.input_all stderr in
  (match Unix.close_process_full channels with
  | Unix.WEXITED 0 -> ()
  | _ -> failwith ("xDSL frontend failed:\n" ^ diagnostic));
  let json = Yojson.Basic.from_string output in
  { name = json |> member "name" |> to_string;
    arguments = json |> member "arguments" |> to_list |> List.map argument;
    body = json |> member "body" |> to_list |> List.map operation }
