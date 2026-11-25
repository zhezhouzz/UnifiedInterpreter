open Stdlib
module J = Yojson.Safe.Util

type value = int * string
type operation = {
  opcode : string; operands : int list; results : value list;
  attributes : (string * string) list; properties : (string * string) list;
  regions : block list list;
}
and block = {arguments : value list; body : operation list}
type catalog_origin = {benchmark:string; model_digest:string;
                       sites:(string * (int list * int list) list) list}
type t = {digest : string; attributes : (string * string) list; functions : (string * operation) list;
          catalog_origin:catalog_origin option}

let read file =
  let doc = Yojson.Safe.from_file file in
  if J.member "format" doc <> `String "hivm-module-1" then invalid_arg "expected a HIVM module AST";
  let list f j = List.map f (J.to_list j) in
  let assoc f j = List.map (fun (k,v) -> k,f v) (J.to_assoc j) in
  let value = function `List [`Int id;`String ty] -> id,ty | _ -> invalid_arg "invalid SSA value" in
  let rec op j =
    let field k = J.member k j in
    {opcode=J.to_string (field "opcode");operands=list J.to_int (field "operands");
     results=list value (field "results");attributes=assoc J.to_string (field "attributes");
     properties=assoc J.to_string (field "properties");regions=list (list block) (field "regions")}
  and block j = {arguments=list value (J.member "arguments" j);body=list op (J.member "body" j)} in
  let digest = Digest.to_hex (Digest.string (Yojson.Safe.to_string (Yojson.Safe.sort doc))) in
  let catalog_origin = match J.member "benchmark" doc with
    | `Null -> None
    | name ->
        let site = function `List [s;p] -> list J.to_int s,list J.to_int p
          | _ -> invalid_arg "invalid source site" in
        Some {benchmark=J.to_string name;model_digest=J.to_string (J.member "model_digest" doc);
              sites=assoc (list site) (J.member "sites" doc)} in
  {digest;catalog_origin;attributes=assoc J.to_string (J.member "attributes" doc);
   functions=assoc op (J.member "functions" doc) |> List.map (fun (s,f) -> "@" ^ s,f)}

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
