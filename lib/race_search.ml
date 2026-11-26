open Race_schedule

let enumerate schedule =
  let queue = Queue.create () and visited = Hashtbl.create 128 in
  let orders = Hashtbl.create 32 and truncated = ref false in
  let conflicts = Array.make (Array.length schedule.nodes) [] in
  List.iter (fun { a; b; _ } ->
    conflicts.(a) <- b :: conflicts.(a);
    conflicts.(b) <- a :: conflicts.(b)
  ) schedule.pairs;
  let enqueue state prefix =
    (* 在合法前缀中，各令牌的状态由已发生的置位和消费次数唯一确定。 *)
    if not (Hashtbl.mem visited state.seen) then (
      Hashtbl.add visited state.seen ();
      Queue.add (state, prefix) queue) in
  enqueue initial [];
  while not (Queue.is_empty queue) do
    let state, prefix = Queue.take queue in
    if List.exists (reached state) schedule.cutoffs then truncated := true;
    Array.iteri (fun n _ -> match step schedule state n with
      | None -> ()
      | Some (event, successor) ->
          let prefix = event :: prefix in
          List.iter (fun a ->
            if occurred state a && not (Hashtbl.mem orders (a, n)) then
              Hashtbl.add orders (a, n) (List.rev prefix)
          ) conflicts.(n);
          enqueue successor prefix
    ) schedule.nodes
  done;
  result schedule ~truncated:!truncated (fun a b -> Hashtbl.find_opt orders (a, b))

let precedence schedule =
  let open Core_lang in
  let parents = Array.make (Array.length schedule.nodes) [] and flags = Hashtbl.create 16 in
  let require n a = parents.(n) <- a :: parents.(n) in
  let touch k sends n =
    let s,w = Option.value ~default:([],[]) (Hashtbl.find_opt flags k) in
    Hashtbl.replace flags k (if sends then n::s,w else s,n::w) in
  let item n = function Set keys -> List.iter (fun k -> touch k true n) keys
    | Wait k -> touch k false n | Operation _ | Bar -> () in
  Array.iteri (fun n node ->
    (match schedule.allocations.(n) with Unallocated -> require n (-1)
     | Allocated_after reserves -> List.iter (require n) reserves);
    match node.phase with
    | Emit {action;previous} ->
        Option.iter (require n) previous;
        (match action with Scalar_wait k -> touch k false n | Immediate x -> item n x | _ -> ())
    | Finish {item=x;submit;earlier;_} ->
        require n submit; item n x;
        List.iter (fun a -> match x,item_at schedule a with
          | (Set _ | Bar),_ | _,(Wait _ | Bar) -> require n a | _ -> ()) earlier
  ) schedule.nodes;
  if Hashtbl.fold (fun _ (s,_) many -> many ||
      List.length (List.sort_uniq compare (List.map (fun n -> schedule.nodes.(n).id.stream) s)) > 1)
      flags false then None else (
    Hashtbl.iter (fun _ (s,w) ->
      let s = Array.of_list (List.rev s) and w = Array.of_list (List.rev w) in
      let at a i = if i < Array.length a then a.(i) else -1 in
      Array.iteri (fun i n -> require n (at s i)) w;
      Array.iteri (fun i n -> if i >= schedule.capacity then require n (at w (i-schedule.capacity))) s
    ) flags;
    Some parents)

let from_predecessors backend schedule parents =
  let graph = Precedence.compile backend parents in
  let truncated = List.exists (Option.fold ~none:true ~some:(Array.get graph.reachable)) schedule.cutoffs in
  result schedule ~truncated (fun a b -> if Precedence.unordered graph a b then
    Some (replay_indices schedule (Precedence.prefix graph a b)) else None)

let generate schedule = match precedence schedule with
  | None -> enumerate schedule
  | Some parents -> from_predecessors Precedence.Bfs schedule parents
