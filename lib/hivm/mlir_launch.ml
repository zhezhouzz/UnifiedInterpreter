open Stdlib
open Unified_interpreter
open Core_lang
module M = Hivm_module
module Mem = Mlir_memory
module J = Yojson.Safe.Util

type storage = {
  id : int;
  name : string;
  space : string option;
  mutable bytes : int;
  mutable declared_bytes : int option;
  mutable initial : (string * Yojson.Safe.t list) option;
}

type stream = {
  id : int;
  entry : string;
  ast : M.block;
  arguments : (int * value) list;
  pipes : Device.pipe list option;
  location : Device.location;
}

type t = {
  hfusion : bool;
  streams : stream list;
  storages : storage list;
  capacity : int;
  edges : (int * int) list option;
}

let optional f = function `Null -> None | j -> Some (f j)
let value j key f default = Option.value (optional f (J.member key j)) ~default
let z_of_json = function
  | `Int n -> Z.of_int n | `Intlit n -> Z.of_string n
  | _ -> invalid_arg "expected an integer"

let pipe = function
  | "S" | "PIPE_S" -> Device.S | "V" | "PIPE_V" -> V | "M" | "PIPE_M" -> M
  | "MTE1" | "PIPE_MTE1" -> MTE1 | "MTE2" | "PIPE_MTE2" -> MTE2
  | "MTE3" | "PIPE_MTE3" -> MTE3 | "FIX" | "PIPE_FIX" -> FIX
  | p -> invalid_arg ("unknown pipe " ^ p)

let symbol name = if String.starts_with ~prefix:"@" name then name else "@" ^ name

let resolve_symbol ast selected = match selected,ast.M.functions with
  | Some entry,_ -> symbol entry
  | None,[(name,_)] -> name
  | None,_ -> invalid_arg "select an entry function in the launch configuration or with --entry"

let block_edge launch source _ target _ =
  List.mem (source,target) (Option.value launch.edges ~default:[])

let bind ?entry ?(configuration=`Assoc []) ast =
  let hfusion = match J.member "stage" configuration with
    | `String "hfusion" -> true | `String "hivm" -> false
    | `Null ->
        let rec device (op : M.operation) =
          String.starts_with ~prefix:"hivm." op.opcode ||
          List.exists (fun (k,_) -> String.starts_with ~prefix:"hivm." k) op.attributes ||
          List.exists (List.exists (fun (b : M.block) -> List.exists device b.body)) op.regions in
        not (List.exists (fun (_,op) -> device op) ast.M.functions)
    | _ -> invalid_arg "launch stage must be hfusion or hivm" in
  let capacity = value configuration "capacity" J.to_int 1 in
  if capacity < 1 then invalid_arg "launch capacity must be positive";
  let storages = Hashtbl.create 8 in
  let record name space required declared initial =
    let s = match Hashtbl.find_opt storages name with
      | Some s -> s
      | None ->
          let s = {id=Hashtbl.length storages;name;space;bytes=0;declared_bytes=None;initial=None} in
          Hashtbl.add storages name s; s in
    if s.space<>space then invalid_arg ("shared storage has different address spaces: " ^ name);
    (match declared,s.declared_bytes with
     | Some n,Some m when n<>m -> invalid_arg ("inconsistent byte sizes for storage " ^ name)
     | Some n,_ -> s.declared_bytes <- Some n | None,_ -> ());
    (match initial,s.initial with
     | Some a,Some b when a<>b -> invalid_arg ("inconsistent initial data for storage " ^ name)
     | Some _,None -> s.initial <- initial | _ -> ());
    s.bytes <- max s.bytes required;
    s.id in
  let binding stream position type_name json =
    match Mem.type_of ast type_name with
    | M.Integer 1 ->
        (match json with `Bool b -> VBool b | `Int 0 -> VBool false | `Int 1 -> VBool true
         | _ -> invalid_arg "expected a boolean or an i1 bit")
    | M.Integer bits ->
        let n = z_of_json json in
        if bits <= 0 || Z.lt n (Z.neg (Z.shift_left Z.one (bits-1))) ||
           Z.geq n (Z.shift_left Z.one bits) then invalid_arg "integer does not fit its MLIR type";
        Mlir_scalar.int bits n
    | M.Float _ -> VFloat (J.to_number json)
    | M.Opaque -> invalid_arg ("unsupported argument type " ^ type_name)
    | M.Shaped ty ->
        let json = match json with `Null -> `Assoc [] | j -> j in
        let shape = match J.member "shape" json with
          | `Null -> Mem.dimensions ty.shape [] | j -> List.map J.to_int (J.to_list j) in
        let offset = optional z_of_json (J.member "offset" json) in
        let layout = optional (fun j -> List.map z_of_json (J.to_list j)) (J.member "strides" json) in
        let descriptor = Mem.descriptor ast ty shape ?offset ?layout () in
        let base_bytes = value json "base_bytes" J.to_int 0 in
        if base_bytes < 0 then invalid_arg "negative backing storage base";
        let b = {descriptor with base_bytes} in
        let name = value json "storage" J.to_string (Printf.sprintf "stream%d.arg%d" stream position) in
        let initial = optional (fun j -> ty.element,J.to_list j) (J.member "initial" json) in
        let declared = optional J.to_int (J.member "bytes" json) in
        let initial_bytes = Option.fold initial ~none:0 ~some:(fun (_,xs) -> List.length xs*b.element_bytes) in
        let bytes = max (Mem.size b) initial_bytes in
        let i = record name ty.space bytes declared initial in
        VBuffer {b with storage=Some (Input i);bytes} in
  let make_stream id spec =
    let selected = match entry with Some _ -> entry | None -> optional J.to_string (J.member "entry" spec) in
    let entry = resolve_symbol ast selected in
    if not (List.mem_assoc entry ast.M.functions) then invalid_arg ("unknown entry " ^ entry);
    let body = M.entry ast entry in
    let args = value spec "arguments" J.to_list (List.map (fun _ -> `Null) body.arguments) in
    if List.length args<>List.length body.arguments then
      invalid_arg (Printf.sprintf "%s expects %d launch arguments" entry (List.length body.arguments));
    let arguments = List.mapi (fun position ((ssa,ty),json) ->
      try ssa,binding id position ty json with
      | (Invalid_argument reason | J.Type_error (reason,_)) ->
          invalid_arg (Printf.sprintf "%s argument %d (%s): %s" entry position ty reason)
    ) (List.combine body.arguments args) in
    let block = value spec "block" J.to_int 0 and subblock = value spec "subblock" J.to_int 0 in
    if block<0 || subblock<0 then invalid_arg "negative launch coordinate";
    let core = match J.member "core" spec with
      | `Null ->
          let fn = List.assoc entry ast.functions in
          (match List.assoc_opt "hivm.func_core_type" fn.attributes with
           | Some "#hivm.func_core_type<AIC>" -> Device.Cube | _ -> Vector subblock)
      | `String "cube" -> Cube | `String "vector" -> Vector subblock
      | _ -> invalid_arg "launch core must be cube or vector" in
    {id;entry;ast=body;arguments;location={block;core};
     pipes=optional (fun j -> List.map (fun p -> pipe (J.to_string p)) (J.to_list j)) (J.member "pipes" spec)} in
  let specs = value configuration "streams" J.to_list [configuration] in
  if specs=[] then invalid_arg "launch must contain a stream";
  if entry<>None && List.length specs<>1 then invalid_arg "--entry requires a single launch stream";
  let streams = List.mapi make_stream specs in
  let storages = Hashtbl.to_seq_values storages |> List.of_seq
                 |> List.sort (fun (a : storage) (b : storage) -> compare a.id b.id) in
  List.iter (fun s -> match s.declared_bytes with
    | Some n when n<s.bytes -> invalid_arg ("storage is smaller than its input views: " ^ s.name)
    | Some n -> s.bytes <- n | None -> ()) storages;
  let streams = List.map (fun stream ->
    let arguments = List.map (fun (ssa,v) -> ssa,match v with
      | VBuffer ({storage=Some (Input i);_} as b) -> VBuffer {b with bytes=(List.nth storages i).bytes}
      | _ -> v) stream.arguments in
    {stream with arguments}) streams in
  let edges = optional (fun j -> List.map (function
    | `List [`Int a;`Int b] when a>=0 && b>=0 && a<>b && a<List.length streams && b<List.length streams -> a,b
    | _ -> invalid_arg "cross-stream edge must name two distinct launch stream indices") (J.to_list j))
    (J.member "edges" configuration) in
  {hfusion;streams;storages;capacity;edges}

let json_int n = if Z.fits_int n then `Int (Z.to_int n) else `Intlit (Z.to_string n)
let list f xs = `List (List.map f xs)
let json_ints = list (fun x -> `Int x)

let inputs launch =
  let argument = function
    | VInt n -> `Assoc ["integer",json_int n]
    | VBool b -> `Assoc ["integer",`Int (if b then 1 else 0)]
    | VFloat x -> `Assoc ["float",`Float x]
    | VBuffer ({storage=Some (Input i);_} as b) ->
        `Assoc ["storage",`String (List.nth launch.storages i).name;"bytes",`Int b.bytes;
                "shape",json_ints b.shape;"base_bytes",`Int b.base_bytes;
                "offset",json_int b.offset;"strides",list json_int b.strides]
    | _ -> invalid_arg "invalid launch argument" in
  let bindings (s : stream) =
    `Assoc ["stream",`Int s.id;"arguments",list (fun (_,v) -> argument v) s.arguments] in
  let location (s : stream) =
    `Assoc ["stream",`Int s.id;"block",`Int s.location.block;
            "core",`String (Device.core_name s.location.core)] in
  let initial s = match s.initial with
    | None -> `Null | Some (ty,values) -> `Assoc ["element",`String ty;"values",`List values] in
  `Assoc ["bindings",list bindings launch.streams;"coordinates",list location launch.streams;
          "initial",`Assoc (List.map (fun s -> s.name,initial s) launch.storages)]
