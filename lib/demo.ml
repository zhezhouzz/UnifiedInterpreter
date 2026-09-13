(* Command-line demo harness. *)

let run_all () =
    Examples.program_inputs ()
    |> List.iteri (fun i input ->
           if i > 0 then print_endline "\n---\n";
           print_endline (Report.pp_input input (Report.execute input)))

  let run _legacy_example = run_all ()
