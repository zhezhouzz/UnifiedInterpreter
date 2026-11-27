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
  | Emit of { action : action; predecessors : int list }
  | Finish of { pipe : int; item : item; submit : int; earlier : int list }
type node = { id : occurrence; phase : phase }
type pair = { a : int; b : int; addresses : address list }
type allocation_check = Allocated_after of int list | Unallocated
type t = {
  capacity : int;
  nodes : node array;
  allocations : allocation_check array;
  pairs : pair list;
  cutoffs : int option list;
  boundaries : string list;
  blocked_control : bool;
}

module Addresses = Set.Make (struct type t = address let compare = compare end)
module Indices = Set.Make (Int)

let visibility prefix schedule =
  let key node=node.id,(match node.phase with Emit _ -> None | Finish f -> Some f.pipe) in
  let keys=Hashtbl.create (Array.length prefix.nodes) in
  Array.iter (fun node -> Hashtbl.add keys (key node) ()) prefix.nodes;
  Array.map (fun node -> Hashtbl.mem keys (key node)) schedule.nodes

let allocation_checks nodes =
  let reserves = Hashtbl.create 16 in
  Array.iteri (fun n node -> match node.phase with
    | Emit { action = Reserve (_, view); _ } -> Hashtbl.add reserves node.id (n, List.length view)
    | _ -> ()) nodes;
  let last=ref None in
  let reservation id= match !last with
    | Some (old,result) when old==id -> result
    | _ -> let result=Hashtbl.find_opt reserves id in last:=Some (id,result);result in
  let access required = function
    | Invalid_address,_ -> None
    | Input _, _ -> required
    | Allocated id, offset ->
        match reservation id with
        | Some (n, size) when offset >= 0 && offset < size -> Option.map (Indices.add n) required
        | _ -> None in
  Array.map (fun node -> match node.phase with
    | Emit { action = Immediate (Operation (_, fp)); _ } | Finish { item = Operation (_, fp); _ } ->
        let needs = List.fold_left access (Some Indices.empty) fp.reads in
        (match List.fold_left access needs fp.writes with
         | Some needs -> Allocated_after (Indices.elements needs)
         | None -> Unallocated)
    | _ -> Allocated_after []) nodes

let conflict_pairs nodes =
  let normalize spans =
    List.fold_left (fun acc (bank,lo,hi) -> match acc with
      | (prev,start,stop)::rest when bank=prev && lo<=stop+1 -> (bank,start,max stop hi)::rest
      | _ -> (bank,lo,hi)::acc) [] (List.sort compare spans) |> List.rev in
  let ranges addresses =
    let rec runs acc bank lo hi = function
      | (other,i)::xs when bank=other && i>=lo-1 && i<=hi+1 ->
          runs acc bank (min lo i) (max hi i) xs
      | (other,i)::xs -> runs ((bank,lo,hi)::acc) other i i xs
      | [] -> normalize ((bank,lo,hi)::acc) in
    match addresses with [] -> [] | (bank,i)::xs -> runs [] bank i i xs in
  let rec intersection acc xs ys = match xs,ys with
    | (x,a,b)::left,(y,c,d)::right ->
        let order=compare x y in
        if order<0 then intersection acc left ys else if order>0 then intersection acc xs right else
        let lo=max a c and hi=min b d in
        let acc=if lo<=hi then (x,lo,hi)::acc else acc in
        if b<d then intersection acc left ys else intersection acc xs right
    | _ -> acc in
  let prior = ref [] and pairs = ref [] in
  Array.iteri (fun b node -> match node.phase with
    | Emit { action = Immediate (Operation (_, fp)); _ } | Finish { item = Operation (_, fp); _ } ->
        let reads=ranges fp.reads and writes=ranges fp.writes in
        let touched=normalize (reads @ writes) in
        List.iter (fun (a, earlier_reads, earlier_writes) ->
          (* 同一条流中，先执行的原子操作已经完成才会发射后续操作。 *)
          if nodes.(a).id.stream<>node.id.stream || (match nodes.(a).phase with Finish _ -> true | _ -> false) then (
            let overlap=intersection (intersection [] earlier_writes touched) earlier_reads writes in
            if overlap<>[] then
              let addresses=List.concat_map (fun (bank,lo,hi) -> List.init (hi-lo+1) (fun i -> bank,lo+i))
                (normalize overlap) in
              pairs := {a;b;addresses}::!pairs)
        ) !prior;
        prior := (b, reads, writes) :: !prior
    | _ -> ()) nodes;
  List.rev !pairs

let compile ?loop_bound ?pair_limit ?(capacity=1) program =
  if capacity < 1 then invalid_arg "flag capacity must be positive";
  if Option.fold ~none:false ~some:(fun bound -> bound < 0) loop_bound then
    invalid_arg "Bug_traces: negative loop bound";
  let unique values = List.length values = List.length (List.sort_uniq compare values) in
  if not (unique (List.map (fun (s : stream) -> s.id) program.streams)) then
    invalid_arg "Core_lang: duplicate stream";
  let nodes = ref [] and count = ref 0 and cutoffs = ref [] and boundaries = ref [] in
  let blocked_control = ref false in
  let add id phase =
    let index = !count in
    incr count;
    nodes := { id; phase } :: !nodes;
    index in
  let descriptors = Hashtbl.create 8 and reads = ref Addresses.empty in
  let local_readers = Hashtbl.create 8 and local_stores = Hashtbl.create 8 in
  let rec plans pending =
    let progress = ref false and blocked = ref [] in
    let ready = List.filter_map (fun stream ->
      let open Effect.Deep in
      let local=Hashtbl.create 8 and active_op=ref None in
      let footprint stream_id pipe op args =
        active_op:=Some op;
        let fp=program.footprint stream_id pipe op args in
        active_op:=None; fp in
      match stream_plan ?loop_bound {program with footprint} stream with
      | plan -> progress := true; Some (stream,plan)
      | effect (Store_local (cells,ty,value)), k ->
          let op=Option.get !active_op in
          Hashtbl.replace local_stores (stream.id,op) ();
          let entry=(cells,ty,value) in
          List.iter (fun a -> Hashtbl.replace local a entry) cells;
          continue k ()
      | effect (Capture_local (cells,ty)), k ->
          let snapshot=match Hashtbl.find_opt local (List.hd cells) with
            | Some ((written,stored_ty,v) as binding) when written=cells && stored_ty=ty &&
                List.for_all (fun a -> match Hashtbl.find_opt local a with
                  | Some current -> current==binding | None -> false) cells -> Some v
            | _ -> None in
          continue k snapshot
      | effect (Use_local cells), k ->
          List.iter (fun cell -> match Hashtbl.find_opt local_readers cell with
            | Some owner when owner<>stream.id -> invalid_arg "multiple streams depend on a writable local operand"
            | _ -> Hashtbl.replace local_readers cell stream.id) cells;
          continue k ()
      | effect (Read_geometry (cells,v)), k ->
          (match Lazy.force v with
           | value -> reads := List.fold_left (fun s c -> Addresses.add c s) !reads cells;
               continue k value
           | exception exn -> discontinue k exn)
      | effect (Store_descriptor (addr,b)), k ->
          (match Hashtbl.find_opt descriptors addr with
           | None -> Hashtbl.add descriptors addr b; progress := true
           | Some previous when previous=b -> ()
           | Some _ -> invalid_arg "multiple descriptor values require dynamic read-from analysis");
          continue k ()
      | effect (Load_descriptor addr), k ->
          (match Hashtbl.find_opt descriptors addr with
           | Some b -> continue k b
           | None -> blocked := stream :: !blocked; None)) pending in
    match !blocked with [] -> ready
    | _ when !progress -> ready @ plans (List.rev !blocked)
    | _ -> invalid_arg "descriptor read has no reachable initialization" in
  List.iter (fun (stream,plan) ->
    if not (unique stream.pipes) then invalid_arg "Core_lang: duplicate pipe";
    let previous = ref None and queues = Hashtbl.create 8 in
    List.iter (fun (id, action) ->
      let predecessors = Option.to_list !previous in
      let predecessors = match action with
        | Immediate Bar ->
            let pending = Hashtbl.fold (fun _ jobs rest -> List.rev_append jobs rest) queues predecessors in
            Hashtbl.clear queues;
            pending
        | _ -> predecessors in
      let submit = add id (Emit { action; predecessors }) in
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
    Option.iter (function Blocked_control -> blocked_control := true
      | Incomplete reason -> boundaries := reason :: !boundaries) plan.boundary;
    if plan.cutoff then cutoffs := !previous :: !cutoffs
  ) (List.sort (fun ((a:stream),_) (b,_) -> compare a.id b.id) (plans program.streams));
  let nodes = Array.of_list (List.rev !nodes) in
  let writer = Hashtbl.create 8 and allocations = allocation_checks nodes in
  let footprint = function Finish {item=Operation (_,fp);_}
    | Emit {action=Immediate (Operation (_,fp));_} -> Some fp | _ -> None in
  Array.iteri (fun i n -> Option.iter (fun fp -> List.iter (fun addr ->
    if Addresses.mem addr !reads then invalid_arg "schedule-dependent read controls execution";
    Option.iter (fun owner -> match n.phase with
      | Emit {action=Immediate (Operation (op,_));_} when owner=n.id.stream
          && Hashtbl.mem local_stores (owner,op) -> ()
      | _ -> invalid_arg "a concurrent or unmodelled write can change a local scheduling operand")
      (Hashtbl.find_opt local_readers addr);
    if Hashtbl.mem descriptors addr then (
      if Hashtbl.mem writer addr then invalid_arg "ambiguous descriptor initialization";
      Hashtbl.add writer addr i)) fp.writes) (footprint n.phase)) nodes;
  Array.iteri (fun i n -> Option.iter (fun fp -> match allocations.(i) with
    | Unallocated -> ()
    | Allocated_after ns -> allocations.(i) <- Allocated_after (List.sort_uniq compare
        (ns @ List.filter_map (Hashtbl.find_opt writer) fp.reads))) (footprint n.phase)) nodes;
  let skip_pairs=Option.fold ~none:false ~some:(fun limit ->
    Array.exists (fun node -> List.exists (fun i -> i>=limit) node.id.iterations) nodes) pair_limit in
  { capacity; nodes; allocations; pairs = (if !blocked_control || skip_pairs then [] else conflict_pairs nodes);
    cutoffs = !cutoffs; boundaries=List.rev !boundaries; blocked_control= !blocked_control }

module Keys = Map.Make (struct type t = key let compare = compare end)
type state = { seen : Z.t; tokens : int Keys.t }
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
      | (Set _ | Bar), _ | _, (Wait _ | Wait_peers _ | Bar) -> None
      | _ -> pending_position schedule state item (count + 1) rest

let step schedule state n =
  let { id; phase } = schedule.nodes.(n) in
  let advance event tokens =
    Some (event, { seen = Z.logor state.seen (Z.shift_left Z.one n); tokens }) in
  let count k = Option.value ~default:0 (Keys.find_opt k state.tokens) in
  let perform event = function
    | Set keys ->
        if List.exists (fun k -> count k >= schedule.capacity) keys then None
        else advance event (List.fold_left (fun m k -> Keys.add k (1 + count k) m) state.tokens keys)
    | Wait k -> (match count k with
        | 0 -> None | 1 -> advance event (Keys.remove k state.tokens)
        | i -> advance event (Keys.add k (i-1) state.tokens))
    | Wait_peers keys ->
        if List.exists (fun k -> count k=0) keys then None else
        advance event (List.fold_left (fun m k -> match count k with 1 -> Keys.remove k m
          | n -> Keys.add k (n-1) m) state.tokens keys)
    | Bar | Operation _ -> advance event state.tokens in
  let ready = match schedule.allocations.(n) with
    | Unallocated -> false | Allocated_after reserves -> List.for_all (occurred state) reserves in
  if occurred state n || not ready then None else
  match phase with
  | Emit { predecessors; _ } when not (List.for_all (occurred state) predecessors) -> None
  | Emit { action = Scalar_wait k as action; _ } ->
      perform (Issued (id, action)) (Wait k)
  | Emit { action = Immediate item as action; _ } -> perform (Issued (id,action)) item
  | Emit { action; _ } -> advance (Issued (id, action)) state.tokens
  | Finish { submit; _ } when not (occurred state submit) -> None
  | Finish { pipe; item; earlier; _ } ->
      match pending_position schedule state item 0 earlier with
      | None -> None
      | Some position ->
          let event = Done { id; pipe; position; item } in
          perform event item

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
