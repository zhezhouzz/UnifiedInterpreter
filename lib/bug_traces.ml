include Race_schedule.Result
type backend = Search | Solve
module Symbolic = Historical_lang
type symbolic_result = Historical_race.outcome =
  | Race of { n : Z.t; witness : race_witness }
  | No_race
  | Unknown of string

let find_symbolic_race = Historical_race.find

let replay ?loop_bound ?capacity program trace =
  let schedule = Race_schedule.compile ?loop_bound ?capacity program in
  let index = Hashtbl.create (Array.length schedule.nodes) in
  Array.iteri (fun n (node : Race_schedule.node) ->
    let pipe = match node.phase with Emit _ -> None | Finish { pipe; _ } -> Some pipe in
    Hashtbl.add index (node.id, pipe) n
  ) schedule.nodes;
  List.fold_left (fun state event ->
    let key = match event with Core_lang.Issued (id, _) -> id, None
      | Done { id; pipe; _ } -> id, Some pipe in
    match Hashtbl.find_opt index key with
    | Some n ->
        (match Race_schedule.step schedule state n with
         | Some (expected, next) when event = expected -> next
         | _ -> invalid_arg "Bug_traces.replay: illegal event")
    | None -> invalid_arg "Bug_traces.replay: unknown event"
  ) Race_schedule.initial trace |> ignore

let generate_bug_traces ?(backend = Search) ?loop_bound ?capacity program =
  match backend with
  | Search -> Race_search.generate (Race_schedule.compile ?loop_bound ?capacity program)
  | Solve ->
      (try Race_solve.generate (Race_schedule.compile ?loop_bound ?capacity program) with
       | Race_solve.Inconclusive reason -> failwith ("Bug_traces.Solve: " ^ reason))
