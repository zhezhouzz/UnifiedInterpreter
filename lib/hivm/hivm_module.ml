open Stdlib
module J = Yojson.Safe.Util
module Source = Attention_runtime.Source

type value = int * string
type shaped_kind = Tensor | Memref | Vector
type layout = Identity | Strided of int option * int option list | Opaque_layout
type shaped_type = {
  kind : shaped_kind; shape : int option list; element : string;
  layout : layout; space : string option;
}
type typ = Integer of int | Float of int | Shaped of shaped_type | Opaque
type operation = {
  opcode : string; operands : int list; results : value list;
  attributes : (string * string) list; properties : (string * string) list;
  regions : block list list;
  literals : (string * Yojson.Safe.t) list;
  decoded : (string * Yojson.Safe.t) list;
  generic : bool;
  span : Source.span option;
  location : string option;
}
and block = {arguments : value list; body : operation list}
type catalog_origin = {benchmark:string; model_digest:string;
                       sites:(string * (int list * int list) list) list}
type t = {digest : string; format : string; attributes : (string * string) list; functions : (string * operation) list;
          catalog_origin : catalog_origin option; types : (string * Yojson.Safe.t) list;
          mlir_types : (string * typ) list; source_sha256 : string option}

let of_json doc =
  let format = J.member "format" doc in
  if not (List.mem format [`String "hivm-module-1"; `String "mlir-module-1"])
  then invalid_arg "expected a module AST";
  let list f j = List.map f (J.to_list j) in
  let assoc f j = List.map (fun (k,v) -> k,f v) (J.to_assoc j) in
  let optional f = function `Null -> None | x -> Some (f x) in
  let optional_assoc f = function `Null -> [] | x -> assoc f x in
  let value = function `List [`Int id;`String ty] -> id,ty | _ -> invalid_arg "invalid SSA value" in
  let typ j =
    let m k = J.member k j in
    match J.to_string (m "kind") with
    | "integer" -> Integer (J.to_int (m "bits"))
    | "float" -> Float (J.to_int (m "bits"))
    | "opaque" -> Opaque
    | ("memref" | "tensor" | "vector") as kind ->
        let kind = match kind with "memref" -> Memref | "tensor" -> Tensor | _ -> Vector in
        let layout = match m "layout" with
          | `Null | `String "identity" -> Identity
          | `String "strided" -> Strided (optional J.to_int (m "offset"),
                                         list (optional J.to_int) (m "strides"))
          | _ -> Opaque_layout in
        Shaped {kind;layout;shape=list (optional J.to_int) (m "shape");
                element=J.to_string (m "element");space=optional J.to_string (m "space")}
    | _ -> invalid_arg "invalid module AST type" in
  let rec op j =
    let field k = J.member k j in
    {opcode=J.to_string (field "opcode");operands=list J.to_int (field "operands");
     results=list value (field "results");attributes=assoc J.to_string (field "attributes");
     properties=assoc J.to_string (field "properties");regions=list (list block) (field "regions");
     literals=optional_assoc Fun.id (field "literals");
     decoded=optional_assoc Fun.id (field "decoded");
     generic=(field "generic" = `Bool true);
     span=optional Attention_runtime.Parser.span (field "span");
     location=optional J.to_string (field "location")}
  and block j = {arguments=list value (J.member "arguments" j);body=list op (J.member "body" j)} in
  let digest = Digest.to_hex (Digest.string (Yojson.Safe.to_string (Yojson.Safe.sort doc))) in
  let catalog_origin = match J.member "benchmark" doc with
    | `Null -> None
    | name ->
        let site = function `List [s;p] -> list J.to_int s,list J.to_int p
          | _ -> invalid_arg "invalid source site" in
        Some {benchmark=J.to_string name;model_digest=J.to_string (J.member "model_digest" doc);
              sites=assoc (list site) (J.member "sites" doc)} in
  let types = optional_assoc Fun.id (J.member "types" doc) in
  let mlir_types = if format = `String "mlir-module-1" then List.map (fun (name,t) -> name,typ t) types
    else [] in
  {digest;format=J.to_string format;catalog_origin;types;mlir_types;
   source_sha256=J.to_string_option (J.member "source_sha256" doc);
   attributes=assoc J.to_string (J.member "attributes" doc);
   functions=assoc op (J.member "functions" doc) |> List.map (fun (s,f) -> "@" ^ s,f)}

let read file = of_json (Yojson.Safe.from_file file)

let module_json ~execution ast =
  let list f xs = `List (List.map f xs) and str x = `String x in
  let assoc f xs = `Assoc (List.map (fun (k,v) -> k,f v) xs) in
  let value (id,ty) = `List [`Int id;str ty] in
  let rec op o = `Assoc ([
    "opcode",str o.opcode;"operands",list (fun i -> `Int i) o.operands;
    "results",list value o.results;"attributes",assoc str o.attributes;
    "properties",assoc str o.properties;"literals",`Assoc o.literals;
    "regions",list (list block) o.regions] @
    (if execution then ["decoded",`Assoc o.decoded;"generic",`Bool o.generic] else []))
  and block b = `Assoc ["arguments",list value b.arguments;"body",list op b.body] in
  `Assoc (["format",str ast.format;"types",`Assoc ast.types;"attributes",assoc str ast.attributes;
          "functions",assoc op (List.map (fun (k,v) -> String.sub k 1 (String.length k-1),v) ast.functions)]
          @ (if execution then [] else ["source_sha256",str (Option.get ast.source_sha256)]))
let execution_json = module_json ~execution:true
let scheduling_json = module_json ~execution:false
type syntax = Custom | Generic | BiSheng of string | Auto of string

let parse ?(syntax=Custom) ~file input =
  let arguments = match syntax with
    | Custom -> [] | Generic -> ["--generic"] | BiSheng path -> ["--bishengir-opt";path]
    | Auto path -> ["--auto-parser";path] in
  Attention_runtime.Parser.parse_json ~script:"mlir_frontend.py" ~arguments ~file input |> of_json

let entry ast name = match List.assoc name ast.functions with
  | {opcode="func.func";regions=[[block]];_} -> block
  | _ -> invalid_arg ("expected a single function entry block: " ^ name)

let resolve_in ~body ~region_block path =
  let rec walk operations = function
    | [i] -> List.nth operations i
    | i::r::b::rest -> walk (region_block (List.nth operations i) r b) rest
    | _ -> invalid_arg "invalid HIVM module AST path" in
  walk body path

let resolve ast ~entry:name path =
  resolve_in ~body:(entry ast name).body
    ~region_block:(fun op r b -> (List.nth (List.nth op.regions r) b).body) path
