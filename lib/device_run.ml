open Device_ast
open Device_value
open Device_eval

type choice = Host of int | Finish of int * int
type event = { stream : int; pipe : pipe; site : string; path : int list; iterations : int list;
               phase : string; observation : observation option }
type result = { memory : memory; events : event list; choices : choice list }
type key = location * location * pipe * pipe * int
type operation = Compute | Signal of key list | Await of key list | Barrier_step
type submission = { serial : int; queue : pipe; operation : operation; synchronous : bool }
type transition = { choice : choice; submission : submission option; observations : event list }
type job = Action of (unit -> unit) | Send of key list | Receive of key list | Fence
type task = { number : int; pipe : pipe; site : string; path : int list; loops : int list; job : job }
type _ Effect.t += Enqueue : task * bool -> unit Effect.t
type fiber = { mutable next : (unit -> unit) option; mutable blocked : int option;
               mutable tasks : task list }

let run ?schedule ?prefix ?on_step ?on_stop ?on_blocked ?on_iteration ?execute ?copy_bank ?(record_events=true)
    ?(replay_error=fun reason -> Invalid_argument reason)
    ?(iteration_ordinals=false) (program : program) inputs bindings =
  if program.register_bytes <= 0 then invalid_arg "invalid register size";
  let memory = Hashtbl.create (Hashtbl.length inputs) in
  Hashtbl.iter (fun k b -> Hashtbl.add memory k
    (if Option.fold ~none:true ~some:(fun f -> f k) copy_bank then Bytes.copy b else b)) inputs;
  let events = ref [] and decisions = ref [] in
  let recent = ref [] and submitted = ref None in
  let tokens = Hashtbl.create 32 in
  let streams = Array.of_list program.streams in
  let locations = List.map (fun s -> s.location) program.streams in
  if List.length (List.sort_uniq compare locations) <> Array.length streams then
    invalid_arg "duplicate device stream location";
  let fibers = Array.map (fun _ -> {next=None; blocked=None; tasks=[]}) streams in
  let append stream pipe site path iterations phase observation =
    let event = {stream;pipe;site;path;iterations;phase;observation} in
    if record_events then events := event :: !events;
    if Option.is_some on_step then recent := event :: !recent in
  let setup id (stream : stream) =
    let fiber = fibers.(id) and serial = ref 0 in
    let current = ref (S,"entry",[],[]) in
    let observe o = let p,site,path,loops = !current in append id p site path loops "access" (Some o) in
    let c = {loc=stream.location;memory;register_bytes=program.register_bytes;
      counters=Hashtbl.create 4;control=Hashtbl.create 4;reads=[];writes=[];observe} in
    let submit pipe site path loops job synchronous =
      let number = !serial in incr serial;
      Effect.perform (Enqueue ({number;pipe;site;path;loops;job}, synchronous)) in
    let keys channel sending p q flag =
      let me = c.loc in
      let peers = match channel with Local -> [me] | Cross ->
        Array.to_list streams |> List.filter_map (fun s ->
          let other = s.location in
          if me.block = other.block && ((me.core = Cube) <> (other.core = Cube))
          then Some other else None) in
      if peers = [] then invalid_arg "cross-core signal without peer";
      List.map (fun peer -> if sending then me,peer,p,q,flag else peer,me,p,q,flag) peers in
    let rec block nested p site path loops env commands =
      List.fold_left (fun (idx,env) cmd ->
        let pc = path @ [idx] in
        let env = try instruction nested p site pc loops env cmd with
          | Invalid_argument reason -> failwith (Printf.sprintf "stream %d %s instruction %s: %s"
              id site (String.concat "." (List.map string_of_int pc)) reason) in
        idx+1,env) (0,env) commands |> snd
    and instruction nested p site path loops env cmd =
      current := p,site,path,loops;
      let ev e = let x = eval c env e in flush c "load"; x in
      let num e = integer (ev e) in
      let require_host () = if nested then invalid_arg ("nested pipe submission at " ^ site) in
      match cmd with
      | Let (x,e) -> (x,ev e)::env
      | Let_plt (mask,remainder,width,e) ->
          let length = num e in
          let pred = vec I1 (Array.init width (fun i -> if i < length then 1L else 0L)) in
          (mask,pred)::(remainder,scalar I64 (Int64.of_int (length-width)))::env
      | Advance_counter key ->
          let n = Option.value ~default:0 (Hashtbl.find_opt c.counters key) in
          Hashtbl.replace c.counters key (n+1); env
      | Interleave (l,h,a,b) ->
          let a = reg (ev a) and b = reg (ev b) in
          let ty = same a b and n = Array.length a.lanes in
          if n <> Array.length b.lanes || n mod 2 <> 0 then invalid_arg "interleave length";
          let half base = vec ty (Array.init n (fun i ->
            (if i mod 2 = 0 then a else b).lanes.(base + i / 2))) in
          (l,half 0)::(h,half (n/2))::env
      | If (cond,yes,no) ->
          let branch,body = if truth (ev cond) then 0,yes else 1,no in
          ignore (block nested p site (path @ [branch]) loops env body); env
      | For l ->
          let lo = num l.lo and hi = num l.hi and step = num l.step in
          if step <= 0 || List.length l.carried <> List.length l.yield then invalid_arg "invalid loop";
          let names = List.map fst l.carried in
          let rec repeat ordinal i values =
            if i >= hi then List.combine names values @ env else
            let ()=Option.iter (fun f -> f id ordinal) on_iteration in
            let inner = (l.index,scalar l.index_type (Int64.of_int i)) :: List.combine names values @ env in
            let loops = loops @ [if iteration_ordinals then ordinal else i] in
            let scope = block nested p site path loops inner l.body in
            current := p,site,path,loops;
            let values = List.map (eval c scope) l.yield in
            flush c "yield";
            let next = if i > max_int-step then hi else i+step in
            repeat (ordinal+1) next values in
          repeat 0 lo (List.map (fun (_,e) -> ev e) l.carried)
      | Issue (queue,label,body) ->
          require_host ();
          let work () = ignore (block true queue label path loops env body) in
          let number = !serial in
          let execute () = match execute with None -> work () | Some run ->
            current := queue,label,path,loops; run id number env c work in
          submit queue label path loops (Action execute) (queue = S); env
      | Set (channel,src,dst,flag) | Wait (channel,src,dst,flag) ->
          require_host ();
          let sending = match cmd with Set _ -> true | _ -> false in
          let flag = num flag in
          let ks = keys channel sending src dst flag in
          let queue = if sending then src else dst in
          let name = (match channel,sending with Local,true -> "set_flag" | Local,false -> "wait_flag"
            | Cross,true -> "sync_block_set" | Cross,false -> "sync_block_wait") in
          let label = Printf.sprintf "%s(%s,%s,%d)" name (pipe_name src) (pipe_name dst) flag in
          submit queue label path loops (if sending then Send ks else Receive ks) (queue = S); env
      | Barrier pipes -> require_host (); List.iter (fun q -> submit q "pipe_barrier" path loops Fence false) pipes; env
      | Control (bit,value) -> Hashtbl.replace c.control bit value;
          record c "set_ctrl" (Printf.sprintf "%d=%b" bit value); env
      | Debug (label,e) ->
          let data = match ev e with
            | Reg r -> Array.to_list r.lanes
            | View v -> List.init (product v.shape) (fun i -> read c v (coords v.shape i))
            | Tensor t -> List.init (Array.length t.cells) (fun i ->
                tensor_cell t (coords t.dimensions i)) in
          record c "debug" (label ^ " " ^ String.concat "," (List.map Int64.to_string data)); env
      | (Store _ | Masked_store _ | Copy _ | Copy_tensor _ | Fill _ | Indirect_load _ | Indirect_store _
        | Scatter_tensor _ | Nd2nz _ | Mmad _ | Fixpipe_row_split _) -> memory_op c env cmd; env in
    fiber.next <- Some (fun () ->
      Effect.Deep.match_with (fun () -> ignore (block false S "scalar" [] [] bindings stream.body)) ()
        {retc=(fun () -> fiber.next <- None);exnc=raise;
         effc=(fun (type a) (eff : a Effect.t) -> match eff with
           | Enqueue (task,synchronous) -> Some (fun (k : (a,unit) Effect.Deep.continuation) ->
               fiber.tasks <- fiber.tasks @ [task];
               let operation = match task.job with Action _ -> Compute | Fence -> Barrier_step
                 | Send ks -> Signal ks | Receive ks -> Await ks in
               submitted := Some {serial=task.number;queue=task.pipe;operation;synchronous};
               append id task.pipe task.site task.path task.loops "issued" None;
               if synchronous then fiber.blocked <- Some task.number;
               fiber.next <- Some (fun () -> Effect.Deep.continue k ()))
           | _ -> None)}) in
  Array.iteri setup streams;
  let ready = function
    | Receive ks -> List.for_all (Hashtbl.mem tokens) ks
    | Send ks -> List.for_all (fun k -> not (Hashtbl.mem tokens k)) ks
    | Action _ | Fence -> true in
  let eligible matches tasks =
    let pending = Hashtbl.create 7 and guarded = Hashtbl.create 7 in
    List.find_opt (fun t ->
      let allowed = matches t && ready t.job && not (Hashtbl.mem guarded t.pipe) &&
        (match t.job with Send _ | Fence -> not (Hashtbl.mem pending t.pipe) | _ -> true) in
      Hashtbl.replace pending t.pipe ();
      (match t.job with Receive _ | Fence -> Hashtbl.replace guarded t.pipe () | _ -> ());
      allowed) tasks in
  let finish id fiber t =
    (match t.job with Send ks -> List.iter (fun k -> Hashtbl.add tokens k ()) ks
     | Receive ks -> List.iter (Hashtbl.remove tokens) ks | Action work -> work () | Fence -> ());
    fiber.tasks <- List.filter (fun x -> x.number <> t.number) fiber.tasks;
    if fiber.blocked = Some t.number then fiber.blocked <- None;
    append id t.pipe t.site t.path t.loops "done" None in
  let host id f = match f.next,f.blocked with
    | Some step,None -> Some (Host id,step) | _ -> None in
  let completion id f matches =
    Option.map (fun t -> Finish (id,t.number),(fun () -> finish id f t)) (eligible matches f.tasks) in
  let choose () =
    Array.to_seqi fibers |> Seq.find_map (fun (id,f) ->
      match completion id f (fun _ -> true) with None -> host id f | step -> step) in
  let apply (choice,step) =
    decisions := choice :: !decisions; recent := []; submitted := None;
    step ();
    Option.iter (fun f -> f {choice;submission= !submitted;observations=List.rev !recent}) on_step in
  let unfinished () = Array.exists (fun f -> f.next <> None || f.tasks <> []) fibers in
  let rec drive () = match choose () with
    | Some step -> apply step; drive ()
    | None when unfinished () ->
        let pending = Array.to_list (Array.mapi (fun id f ->
          let queues = List.filter (fun t ->
            not (List.exists (fun x -> x.number < t.number && x.pipe = t.pipe) f.tasks)) f.tasks in
          Printf.sprintf "stream %d [%s]" id (String.concat ", " (List.map (fun t ->
            Printf.sprintf "%s@%s" t.site (String.concat "/" (List.map string_of_int t.loops))) queues))) fibers) in
        let reason="device streams blocked: " ^ String.concat "; " pending in
        (match on_blocked with Some report -> report reason | None -> failwith reason)
    | None -> () in
  let replay choice =
    let step = match choice with Host id -> host id fibers.(id)
      | Finish (id,n) -> completion id fibers.(id) (fun t -> t.number = n) in
    match step with Some step -> apply step | None -> raise (replay_error "invalid replay step") in
  (match schedule,prefix with None,None -> drive () | None,Some choices -> List.iter replay choices
   | Some choices,None -> List.iter replay choices; if unfinished () then raise (replay_error "incomplete replay schedule")
   | Some _,Some _ -> invalid_arg "provide either a schedule or a prefix");
  Option.iter (fun observe ->
    Array.to_list (Array.mapi (fun id f ->
      Option.to_list (Option.map fst (host id f)) @ List.filter_map (fun t ->
        Option.map fst (completion id f (fun x -> x.number=t.number))) f.tasks) fibers)
    |> List.concat |> observe) on_stop;
  {memory; events=List.rev !events; choices=List.rev !decisions}
