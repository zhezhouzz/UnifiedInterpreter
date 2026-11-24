open Race_schedule

let generate schedule =
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
