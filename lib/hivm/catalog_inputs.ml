open Unified_interpreter
module C = Core_lang
module J = Yojson.Safe.Util

let integer z = if Z.fits_int z then `Int (Z.to_int z) else `Intlit (Z.to_string z)
let binding id args = `Assoc ["stream",`Int id;"arguments",`List args]
let storage id bytes = `Assoc ["storage",`String id;"bytes",`Int bytes]

let litao (launch : Race_benchmarks.launch) entries config n =
  let streams = launch.family.streams in
  let args = J.member "arguments" config in
  let bindings = List.map (fun (s : C.stream) ->
    let arg i (x,v) =
      if List.mem (s.id,x) launch.family.parameter then integer (Option.get n)
      else match v with
        | C.VInt z -> integer z
        | VView cells ->
            let id = match (if args=`Null then `Null else J.member (string_of_int i) args) with
              | `String id -> id | _ -> "gm:" ^ string_of_int i in
            storage id (List.length cells)
        | _ -> invalid_arg "unsupported kernel argument" in
    binding s.id (List.mapi arg s.params)) streams in
  let kinds = match J.member "kinds" config with
    | `Null -> List.map (fun _ -> "AIV") entries | a -> List.map J.to_string (J.to_list a) in
  let vectors = ref 0 in
  let coordinates = List.map2 (fun (id,_) kind ->
    let subblock = if kind="AIV" then (let n= !vectors in incr vectors; n) else 0 in
    `Assoc ["stream",`Int id;"block",`Int 0;"kind",`String kind;"subblock",`Int subblock]) entries kinds in
  let tile = match J.member "tile" config with `Null -> 32 | v -> J.to_int v in
  ["bindings",`List bindings;"coordinates",`List coordinates;"initial",J.member "initial" config;
   "tile",`Int tile;"initial_default",`Int 0]

let fixture name (launch : Race_benchmarks.launch) schedule n =
  let open Race_report.Schedule in
  let size = Array.fold_left (fun size node -> match node.phase with
    | Finish {item=C.Operation (_,fp);_} ->
        let extend size = function C.Input 0,i -> max size (i+1) | _ -> size in
        List.fold_left extend (List.fold_left extend size fp.reads) fp.writes
    | _ -> size) 0 schedule.nodes in
  let shared = Fixture_source.shared name in
  let args s =
    [storage "gm:0" (size*4)] @ (if shared then [`Assoc ["descriptor_slot",`String "allocation:0"]] else [])
    @ List.filter_map (fun (id,_) -> if id=s.C.id then Some (integer (Option.get n)) else None)
        launch.family.parameter in
  ["bindings",`List (List.map (fun s -> binding s.C.id (args s)) launch.family.streams);
   "initial",`Assoc ["gm:0",`Int 0];
   "initial_cells",`List (if size=0 then [] else [`Assoc ["storage",`String "gm:0";"element",`Int 0;"value",`Int 7]])]

let make name (launch : Race_benchmarks.launch) ast entries schedule n =
  let common = ["ast_format",`String "hivm-module-1";"ast_digest",`String ast.Hivm_module.digest] in
  let inputs = match schedule with
    | None -> []
    | Some schedule ->
        if launch.fixture=`Null then fixture name launch schedule n
        else litao launch entries (J.member "launch" launch.fixture) n in
  `Assoc (common @ inputs)
