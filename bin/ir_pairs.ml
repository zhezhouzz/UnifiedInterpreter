module Json = Yojson.Safe.Util

let run argv =
  let name = ref None and json = ref false in
  let select value =
    match !name with
    | None -> name := Some value
    | Some _ -> raise (Arg.Bad "expected at most one benchmark name")
  in
  Arg.parse_argv ~current:(ref 0) argv
    ["--json", Arg.Set json, " include artifact digests and provenance"]
    select "race pairs [NAME] [--json]";
  let catalog = Yojson.Safe.from_file "benchmarks/ir-pairs/catalog.json" in
  let cases = Json.(catalog |> member "benchmarks" |> to_assoc) in
  let selected = match !name with
    | None -> cases
    | Some n ->
        match List.assoc_opt n cases with
        | Some pair -> [n, pair]
        | None -> raise (Arg.Bad ("unknown benchmark: " ^ n))
  in
  if !json then begin
    Yojson.Safe.to_channel stdout (`Assoc selected);
    print_newline ()
  end else
    List.iter (fun (n, pair) ->
      let path stage = Json.(pair |> member stage |> member "path" |> to_string) in
      Printf.printf "%s\t%s\t%s\n" n (path "hfusion") (path "hivm")) selected
