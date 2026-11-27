open Stdlib
open Unified_interpreter
open Effect.Deep

type key = int * int * string * string * int
type operation = Work of (unit -> unit) | Set of key list | Wait of key list | Barrier
type task = {pipe:string; site:string; operation:operation}
type _ Effect.t += Submit : task * bool -> unit Effect.t
type item = {serial:int; task:task; blocking:bool}
type pipe_queue = {signals:item Queue.t; operations:item Queue.t}
type fiber = {mutable resume:(unit -> unit) option; mutable blocked:bool;
              mutable pending:int; queues:(string, pipe_queue) Hashtbl.t}
type outcome = Returned | Deadlock of string list

let submit ?(blocking=false) pipe site operation =
  Effect.perform (Submit ({pipe;site;operation},blocking))

let drive state capacity completed entries =
  let signals=Hashtbl.create 32 and serial=ref 0 in
  let fibers=Array.map (fun entry ->
    let f={resume=None;blocked=false;pending=0;queues=Hashtbl.create 8} in
    let start () = match_with entry () {
      retc=(fun () -> f.resume<-None); exnc=raise;
      effc=(fun (type a) (e:a Effect.t) -> match e with
        | Submit (task,blocking) -> Some (fun (k:(a,unit) continuation) ->
            let q=match Hashtbl.find_opt f.queues task.pipe with Some q->q | None->
              let q={signals=Queue.create ();operations=Queue.create ()} in Hashtbl.add f.queues task.pipe q;q in
            let items=match task.operation with Set _->q.signals | _->q.operations in
            Queue.add {serial= !serial;task;blocking} items;incr serial;
            f.pending<-f.pending+1; f.blocked<-blocking;
            f.resume<-Some (fun () -> continue k ()))
        | _ -> None)} in
    f.resume<-Some start; f) entries in
  let tokens k=Option.value (Hashtbl.find_opt signals k) ~default:0 in
  let enabled t=match t.operation with
    | Work _ | Barrier -> true
    | Set ks -> List.for_all (fun k->tokens k<capacity) ks
    | Wait ks -> List.for_all (fun k->tokens k>0) ks in
  let ready f =
    (* A blocked set may be passed by ordinary work or a wait. A wait or
       barrier guards everything behind it. Only two queue heads can run. *)
    let candidate q=match Queue.peek_opt q.signals,Queue.peek_opt q.operations with
      | Some s,op when Option.fold ~none:true ~some:(fun x->s.serial<x.serial) op && enabled s.task ->
          Some (s,q.signals)
      | set,Some op when enabled op.task && (match op.task.operation with
          | Barrier->Option.fold ~none:true ~some:(fun s->s.serial>op.serial) set | _->true) ->
          Some (op,q.operations)
      | _->None in
    Hashtbl.fold (fun _ q earliest -> match earliest,candidate q with
      | None,c | c,None -> c
      | Some (a,_),Some (b,_) as choices -> if a.serial<b.serial then fst choices else snd choices)
      f.queues None in
  let finish f (item,q) =
    let task=item.task in ignore (Queue.take q);
    (match task.operation with
     | Work work -> work () | Barrier -> ()
     | Set ks -> List.iter (fun k -> Hashtbl.replace signals k (tokens k+1)) ks
     | Wait ks -> List.iter (fun k -> Hashtbl.replace signals k (tokens k-1)) ks);
    f.pending<-f.pending-1;
    if item.blocking then f.blocked<-false in
  let first=ref 0 in
  let rec step () =
    let rec choose id =
      if id=Array.length fibers then false else
      let f=fibers.(id) in
      state.Interpreter.current_pid<-id;
      if f.pending=0 && f.resume=None then (
        if id= !first then incr first;
        choose (id+1))
      else match ready f,f.resume with
      | Some t,_ -> finish f t; incr completed; true
      | None,Some resume when not f.blocked -> resume (); true
      | _ -> choose (id+1) in
    if choose !first then step () else
    let pending=Array.to_list (Array.mapi (fun i f ->
      Hashtbl.fold (fun _ q acc ->
        List.filter_map Queue.peek_opt [q.signals;q.operations] @ acc) f.queues []
      |> List.sort (fun a b->compare a.serial b.serial)
      |> List.map (fun {task;_}->Printf.sprintf "stream %d %s %s" i task.pipe task.site)) fibers) |> List.concat in
    if pending=[] then Returned else Deadlock pending in
  step ()
