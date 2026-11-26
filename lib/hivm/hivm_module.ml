open Stdlib
module J = Yojson.Safe.Util

type value = int * string
type operation = {
  opcode : string; operands : int list; results : value list;
  attributes : (string * string) list; properties : (string * string) list;
  regions : block list list; literals : (string * Yojson.Safe.t) list;
}
and block = {arguments : value list; body : operation list}
type catalog_origin = {benchmark:string; model_digest:string;
                       sites:(string * (int list * int list) list) list}
type t = {digest : string; attributes : (string * string) list; functions : (string * operation) list;
          catalog_origin:catalog_origin option; types:(string * Yojson.Safe.t) list; source_sha256:string option}

let of_json doc =
  if J.member "format" doc <> `String "hivm-module-1" then invalid_arg "expected a HIVM module AST";
  let list f j = List.map f (J.to_list j) in
  let assoc f j = List.map (fun (k,v) -> k,f v) (J.to_assoc j) in
  let value = function `List [`Int id;`String ty] -> id,ty | _ -> invalid_arg "invalid SSA value" in
  let rec op j =
    let field k = J.member k j in
    {opcode=J.to_string (field "opcode");operands=list J.to_int (field "operands");
     results=list value (field "results");attributes=assoc J.to_string (field "attributes");
     properties=assoc J.to_string (field "properties");regions=list (list block) (field "regions");
     literals=(match field "literals" with `Null -> [] | x -> J.to_assoc x)}
  and block j = {arguments=list value (J.member "arguments" j);body=list op (J.member "body" j)} in
  let digest = Digest.to_hex (Digest.string (Yojson.Safe.to_string (Yojson.Safe.sort doc))) in
  let catalog_origin = match J.member "benchmark" doc with
    | `Null -> None
    | name ->
        let site = function `List [s;p] -> list J.to_int s,list J.to_int p
          | _ -> invalid_arg "invalid source site" in
        Some {benchmark=J.to_string name;model_digest=J.to_string (J.member "model_digest" doc);
              sites=assoc (list site) (J.member "sites" doc)} in
  {digest;catalog_origin;types=(match J.member "types" doc with `Null -> [] | t -> J.to_assoc t);
   source_sha256=J.to_string_option (J.member "source_sha256" doc);
   attributes=assoc J.to_string (J.member "attributes" doc);
   functions=assoc op (J.member "functions" doc) |> List.map (fun (s,f) -> "@" ^ s,f)}

let read file = of_json (Yojson.Safe.from_file file)

let scheduling_json ast =
  let list f xs = `List (List.map f xs) and str x = `String x in
  let assoc f xs = `Assoc (List.map (fun (k,v) -> k,f v) xs) in
  let value (id,ty) = `List [`Int id;str ty] in
  let rec op o = `Assoc [
    "opcode",str o.opcode;"operands",list (fun i -> `Int i) o.operands;
    "results",list value o.results;"attributes",assoc str o.attributes;
    "properties",assoc str o.properties;"literals",`Assoc o.literals;
    "regions",list (list block) o.regions]
  and block b = `Assoc ["arguments",list value b.arguments;"body",list op b.body] in
  `Assoc ["format",str "hivm-module-1";"types",`Assoc ast.types;"attributes",assoc str ast.attributes;
          "source_sha256",str (Option.get ast.source_sha256);
          "functions",assoc op (List.map (fun (k,v) -> String.sub k 1 (String.length k-1),v) ast.functions)]

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
