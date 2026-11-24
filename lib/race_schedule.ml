open Core_lang

module Result = struct
  type race_witness = {
    first : occurrence;
    second : occurrence;
    conflicts : address list;
    first_then_second : event list;
    second_then_first : event list;
  }
  type bug_trace_set = { races : race_witness list; truncated : bool }
end

type phase =
  | Emit of { action : action; previous : int option }
  | Finish of { pipe : int; item : item; submit : int; earlier : int list }
type node = { id : occurrence; phase : phase }
type pair = { a : int; b : int; addresses : address list }
type allocation_check = Allocated_after of int list | Unallocated
type t = {
  nodes : node array;
  allocations : allocation_check array;
  pairs : pair list;
  cutoffs : int option list;
}

module Addresses = Set.Make (struct type t = address let compare = compare end)
module Indices = Set.Make (Int)

let allocation_checks nodes =
  let reserves = Hashtbl.create 16 in
  Array.iteri (fun n node -> match node.phase with
    | Emit { action = Reserve (_, view); _ } -> Hashtbl.add reserves node.id (n, List.length view)
    | _ -> ()) nodes;
  let access required = function
    | Input _, _ -> required
    | Allocated id, offset ->
        match Hashtbl.find_opt reserves id with
        | Some (n, size) when offset >= 0 && offset < size -> Option.map (Indices.add n) required
        | _ -> None in
  Array.map (fun node -> match node.phase with
    | Finish { item = Operation (_, fp); _ } ->
        let needs = List.fold_left access (Some Indices.empty) fp.reads in
        (match List.fold_left access needs fp.writes with
         | Some needs -> Allocated_after (Indices.elements needs)
         | None -> Unallocated)
    | _ -> Allocated_after []) nodes

let conflict_pairs nodes =
  let prior = ref [] and pairs = ref [] in
  Array.iteri (fun b node -> match node.phase with
    | Finish { item = Operation (_, fp); _ } ->
        let reads = Addresses.of_list fp.reads and writes = Addresses.of_list fp.writes in
        let touched = Addresses.union reads writes in
        List.iter (fun (a, earlier_reads, earlier_writes) ->
          let overlap = Addresses.union
            (Addresses.inter earlier_writes touched)
            (Addresses.inter earlier_reads writes) in
          if not (Addresses.is_empty overlap) then
            pairs := { a; b; addresses = Addresses.elements overlap } :: !pairs
        ) !prior;
        prior := (b, reads, writes) :: !prior
    | _ -> ()) nodes;
  List.rev !pairs

let compile ?loop_bound program =
  if Option.fold ~none:false ~some:(fun bound -> bound < 0) loop_bound then
    invalid_arg "Bug_traces: negative loop bound";
  let unique values = List.length values = List.length (List.sort_uniq compare values) in
  if not (unique (List.map (fun (s : stream) -> s.id) program.streams)) then
    invalid_arg "Core_lang: duplicate stream";
  let nodes = ref [] and count = ref 0 and cutoffs = ref [] in
  let add id phase =
    let index = !count in
    incr count;
    nodes := { id; phase } :: !nodes;
    index in
  List.iter (fun stream ->
    if not (unique stream.pipes) then invalid_arg "Core_lang: duplicate pipe";
    let plan = stream_plan ?loop_bound program stream in
    let previous = ref None and queues = Hashtbl.create 8 in
    List.iter (fun (id, action) ->
      let submit = add id (Emit { action; previous = !previous }) in
      previous := Some submit;
      let enqueue pipe item =
        if not (List.mem pipe stream.pipes) then invalid_arg "Core_lang: undeclared pipe";
        let earlier = Option.value ~default:[] (Hashtbl.find_opt queues pipe) in
        let completion = add id (Finish { pipe; item; submit; earlier }) in
        Hashtbl.replace queues pipe (completion :: earlier) in
      match action with
      | Submit (pipe, item) -> enqueue pipe item
      | Fence pipes -> List.iter (fun pipe -> enqueue pipe Bar) pipes
      | _ -> ()
    ) plan.actions;
    if plan.cutoff then cutoffs := !previous :: !cutoffs
  ) program.streams;
  let nodes = Array.of_list (List.rev !nodes) in
  { nodes; allocations = allocation_checks nodes; pairs = conflict_pairs nodes; cutoffs = !cutoffs }

module Keys = Set.Make (struct type t = key let compare = compare end)
type state = { seen : Z.t; tokens : Keys.t }
let initial = { seen = Z.zero; tokens = Keys.empty }
let occurred state = Z.testbit state.seen
let reached state = Option.fold ~none:true ~some:(occurred state)

let item_at schedule n = match schedule.nodes.(n).phase with
  | Finish { item; _ } -> item
  | Emit _ -> invalid_arg "Race_schedule: expected completion"

let rec pending_position schedule state item count = function
  | [] -> Some count
  | n :: rest when occurred state n -> pending_position schedule state item count rest
  | n :: rest ->
      match item, item_at schedule n with
      | (Set _ | Bar), _ | _, (Wait _ | Bar) -> None
      | _ -> pending_position schedule state item (count + 1) rest

let step schedule state n =
  let { id; phase } = schedule.nodes.(n) in
  let advance event tokens =
    Some (event, { seen = Z.logor state.seen (Z.shift_left Z.one n); tokens }) in
  if occurred state n then None else
  match phase with
  | Emit { previous; _ } when not (reached state previous) -> None
  | Emit { action = Scalar_wait k as action; _ } ->
      if Keys.mem k state.tokens then advance (Issued (id, action)) (Keys.remove k state.tokens)
      else None
  | Emit { action; _ } -> advance (Issued (id, action)) state.tokens
  | Finish { submit; _ } when not (occurred state submit) -> None
  | Finish { pipe; item; earlier; _ } ->
      let ready = match schedule.allocations.(n) with
        | Unallocated -> false | Allocated_after reserves -> List.for_all (occurred state) reserves in
      if not ready then None else match pending_position schedule state item 0 earlier with
      | None -> None
      | Some position ->
          let event = Done { id; pipe; position; item } in
          match item with
          | Set keys ->
              if List.exists (fun k -> Keys.mem k state.tokens) keys then None
              else advance event (List.fold_left (fun bits k -> Keys.add k bits) state.tokens keys)
          | Wait k ->
              if Keys.mem k state.tokens then advance event (Keys.remove k state.tokens) else None
          | Bar | Operation _ -> advance event state.tokens

let replay_indices schedule indices =
  List.fold_left_map (fun state n -> match step schedule state n with
    | Some (event, state) -> state, event
    | None -> failwith "Bug_traces: illegal witness from solver"
  ) initial indices |> snd

let result schedule ~truncated orders =
  let races = List.filter_map (fun { a; b; addresses } ->
    match orders a b, orders b a with
    | Some first_then_second, Some second_then_first ->
        Some Result.{ first = schedule.nodes.(a).id; second = schedule.nodes.(b).id;
                      conflicts = addresses; first_then_second; second_then_first }
    | _ -> None
  ) schedule.pairs in
  Result.{ races; truncated }
