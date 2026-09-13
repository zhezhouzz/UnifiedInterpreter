(* Command-line demo harness. *)

let run_all () =
    Examples.cases ()
    |> List.iteri (fun i case ->
           if i > 0 then print_endline "\n---\n";
           print_endline (Report.pp_case case (Report.execute case)))

  let run _legacy_example = run_all ()
