open Unified_interpreter
open Hivm_event
module D = Core_lang.Device
module R = Device_races
module J = Yojson.Safe.Util

let export_events ?(full=false) ?(logical_async=fun _ -> false) ?(atomic=fun _ -> false) ~entries ~location (model : R.model) races =
  let streams = Array.of_list model.program.streams in
  let ids = Hashtbl.create (Array.length streams) in
  Array.iteri (fun i s -> Hashtbl.add ids s.D.location i) streams;
  let signal (src,dst,p,q,k) = {receiver=Hashtbl.find ids dst;source=p;target=q;flag=k;cross=src<>dst} in
  let action = function
    | Device_run.Compute -> Compute | Barrier_step -> Barrier
    | Signal keys -> Set (List.map signal keys)
    | Await (key::rest as keys) ->
        let k = signal key in
        if k.cross then (
          if not (List.for_all (fun other -> signal other=k) rest) then invalid_arg "inconsistent cross-core wait";
          Wait_all (List.map (fun (s,_,_,_,_) -> Hashtbl.find ids s) keys,k))
        else Wait k
    | Await [] -> invalid_arg "empty device wait" in
  let pending = Hashtbl.create 256 in
  let steps = Array.mapi (fun i choice ->
    let step = model.source_steps.(i) in
    match choice with
    | Device_run.Host stream ->
        let host = List.map (fun id -> id,{location=location id;phase=Execute (Some S);action=Compute}) step.host in
        (match step.issued with None -> host | Some (id,sub) ->
          let task = {id=i;pipe=sub.queue} in
          let loc=location id in
          let submit,complete=if logical_async loc.origin.opcode then Async_submit i,Async_complete i
            else Submit [task],Complete task in
          let issued = {location=loc;action=action sub.operation;phase=submit} in
          if atomic loc.origin.opcode && sub.synchronous then (
            Hashtbl.add pending (stream,sub.serial) (id,{issued with phase=Execute (Some sub.queue)});
            host)
          else (
            Hashtbl.add pending (stream,sub.serial) (id,{issued with phase=complete});
            host @ [id,issued]))
    | Finish (stream,serial) ->
        let key = stream,serial in
        let completion = Hashtbl.find pending key in
        Hashtbl.remove pending key;
        [completion]) model.steps in
  let race json =
    let field k = J.member k json in
    let target node key =
      let site = List.find (fun site -> R.identity_json site=field key) model.by_node.(node) in
      snd (List.find (fun (id,e) -> id=site.id && match e.phase with Submit _ | Async_submit _ -> false | _ -> true) steps.(node)) in
    match Race_report.numbers (field "nodes") with
    | [a;b] ->
        let first = target a "first" and second = target b "second" in
        let prefix key x y =
          let rec until = function
            | [] -> invalid_arg "race target missing from HIVM prefix"
            | (_,e)::_ when e=y -> [e]
            | (_,e)::rest -> e::until rest in
          let rec convert acc = function
            | [] -> invalid_arg "empty device prefix"
            | [last] -> List.rev_append acc (until steps.(last))
            | n::rest -> convert (List.fold_left (fun acc (_,e) -> e::acc) acc steps.(n)) rest in
          let nodes=Race_report.numbers (field key) in
          let events = if full then List.concat_map (fun n -> List.map snd steps.(n)) nodes else convert [] nodes in
          if List.filter (fun e -> e=x || e=y) events <> [x;y] then invalid_arg "incorrect HIVM race order";
          events in
        {first;second;forward=prefix "forward" first second;reverse=prefix "reverse" second first}
    | _ -> invalid_arg "expected two conflicting accesses" in
  Array.to_list (Array.mapi (fun i name -> i,name) entries),List.map race races
