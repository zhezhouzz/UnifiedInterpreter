module E = Extracted_semantics.Unified_semantics
(* [Yojson.Safe] rather than [Yojson.Basic]: the frontend writes MLIR integer
   constants as JSON numbers, and [Basic] can only represent those as an OCaml
   [int], so it raises on anything that does not fit.  [Safe] keeps the literal
   text in [`Intlit], which lets the interpreter reject out-of-range constants
   with a diagnostic instead of crashing. *)
open Yojson.Safe.Util

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
  attributes : (string * Yojson.Safe.t) list;
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

(* The frontend reads all of stdin, then writes its diagnostic to stderr.  If
   that diagnostic exceeds the pipe capacity (64 KiB on Linux) the child blocks
   writing while the parent blocks reading stdout, and neither side can make
   progress.  Reading both pipes with [select] keeps the parent draining
   whichever one is ready, so a large diagnostic cannot deadlock the tool. *)
let read_both out err =
  let out_fd = Unix.descr_of_in_channel out
  and err_fd = Unix.descr_of_in_channel err in
  let buffer = Bytes.create 65536 in
  let out_buffer = Buffer.create 65536 and err_buffer = Buffer.create 1024 in
  let out_open = ref true and err_open = ref true in
  while !out_open || !err_open do
    let ready =
      (if !out_open then [out_fd] else []) @ (if !err_open then [err_fd] else []) in
    let fds,_,_ = Unix.select ready [] [] (-1.0) in
    List.iter (fun fd ->
        let count = Unix.read fd buffer 0 (Bytes.length buffer) in
        if count = 0 then
          (if fd = out_fd then out_open := false else err_open := false)
        else if fd = out_fd then Buffer.add_subbytes out_buffer buffer 0 count
        else Buffer.add_subbytes err_buffer buffer 0 count) fds
  done;
  Buffer.contents out_buffer,Buffer.contents err_buffer

(* The interpreter represents integers in 63 bits: [nat] extracts to the OCaml
   [int] in Extracted_semantics, so no value at or beyond 2^62 can survive.  The
   Coq model is exact there -- it computes in unbounded [Z] and the IR gives
   [IndexType] 64 bits -- so this bound is a property of the implementation, not
   of the specification.  [Yojson.Safe] reports every JSON number that does not
   fit an OCaml [int] as [`Intlit] with its literal text, so this is the one
   place that has to reject them, before any value reaches the semantics. *)
let rec check_integer_range file json =
  let reject literal =
    failwith
      (Printf.sprintf
         "%s: integer constant %s is outside the 63-bit range supported by the \
          interpreter ([-2^62, 2^62-1])"
         file literal) in
  match json with
  | `Intlit literal -> reject literal
  | `Assoc fields -> List.iter (fun (_,value) -> check_integer_range file value) fields
  | `List items -> List.iter (check_integer_range file) items
  | _ -> ()

let parse ~file input =
  let root = match Sys.getenv_opt "ATTENTION_ROOT" with
    | Some path -> path | None -> project_root (Sys.getcwd ()) in
  let python = Filename.concat root ".venv-attention/bin/python" in
  let frontend = Filename.concat root "scripts/attention_frontend.py" in
  let channels = Unix.open_process_args_full python [|python;"-B";frontend;file|] (Unix.environment ()) in
  let stdout,stdin,stderr = channels in
  output_string stdin input;
  close_out stdin;
  let output,diagnostic = read_both stdout stderr in
  (match Unix.close_process_full channels with
  | Unix.WEXITED 0 -> ()
  | _ -> failwith ("xDSL frontend failed:\n" ^ diagnostic));
  let json =
    try Yojson.Safe.from_string output
    with Yojson.Json_error message ->
      failwith ("xDSL frontend produced malformed JSON: " ^ message) in
  check_integer_range file json;
  { name = json |> member "name" |> to_string;
    arguments = json |> member "arguments" |> to_list |> List.map argument;
    body = json |> member "body" |> to_list |> List.map operation }
