open Unified_interpreter
open Hivm_event
module C = Core_lang

let invalid fmt = Printf.ksprintf (fun s -> invalid_arg ("Hivm_trace: " ^ s)) fmt
let path_name path = "[" ^ String.concat "," (List.map string_of_int path) ^ "]"
let ints = Race_report.ints
let optional f = function Some x -> f x | None -> `Null

type event_site =
  | Ordinary
  | Direct of origin
  | Nested of Mlir_lowering.source
  | In_call of { call_path : int list; callee : string; target : origin }

let pipe_name pipe = "PIPE_" ^ C.Device.pipe_name pipe
let pipe_of pipes p =
  if p = C.scalar_pipe then S else
    match List.assoc_opt p pipes with Some pipe -> pipe | None -> invalid "unmapped Core pipe %d" p

let project_node ~pipes ~entries ~source schedule =
  let open Race_report.Schedule in
  let finish = Hashtbl.create 32 in
  Array.iteri (fun i node -> match node.phase with
    | Finish f -> Hashtbl.add finish (node.id,f.pipe) i
    | Emit _ -> ()) schedule.nodes;
  let pipe = pipe_of pipes in
  let task id p = {id=Hashtbl.find finish (id,p);pipe=pipe p} in
  let signal (k : C.key) = {receiver=k.receiver; source=pipe k.source;
    target=(match k.target with ScalarEnd -> S | Data p -> pipe p);flag=k.flag;cross=k.block} in
  let action = function
    | C.Operation _ -> Compute | Bar -> Barrier
    | Set keys -> Set (List.map signal keys) | Wait k -> Wait (signal k)
    | Wait_peers (k::_ as keys) -> Wait_all (List.map (fun (p:C.key) -> Option.get p.sender) keys,signal k)
    | Wait_peers [] -> invalid "cross-core wait without a sender" in
  let at (id : C.occurrence) phase action =
    let entry = List.assoc id.stream entries in
    let event entry origin iterations calls =
      Some {location={stream=id.stream;entry;origin;iterations;calls};action;phase} in
    match source id.stream id.site with
    | Ordinary -> None
    | Direct origin -> event entry origin id.iterations []
    | Nested source ->
        let rec descend entry iterations calls = function
          | [] -> event entry source.origin iterations (List.rev calls)
          | (caller,call_path,depth,callee)::frames ->
              if caller<>entry || depth>List.length iterations then invalid "invalid call origin";
              let frame = {caller;call_path;call_iterations=List.take depth iterations} in
              descend callee (List.drop depth iterations) (frame::calls) frames in
        descend entry id.iterations [] source.frames
    | In_call {call_path;callee;target} ->
        event callee target [] [{caller=entry;call_path;call_iterations=id.iterations}] in
  fun {id;phase} -> match phase with
    | Emit {action=Control;_} -> None
    | Emit {action=Reserve _;_} -> at id (Execute (Some S)) Compute
    | Emit {action=Immediate Bar;_} -> at id (Execute None) Barrier
    | Emit {action=Immediate item;_} -> at id (Execute (Some S)) (action item)
    | Emit {action=Scalar_wait key;_} -> at id (Execute (Some S)) (Wait (signal key))
    | Emit {action=Submit (p,item);_} when p=C.async_pipe ->
        at id (Async_submit (Hashtbl.find finish (id,p))) (action item)
    | Finish {pipe=p;item;_} when p=C.async_pipe ->
        at id (Async_complete (Hashtbl.find finish (id,p))) (action item)
    | Emit {action=Submit (p,item);_} -> at id (Submit [task id p]) (action item)
    | Emit {action=Fence ps;_} -> at id (Submit (List.map (task id) ps)) Barrier
    | Finish {pipe=p;item;_} -> at id (Complete (task id p)) (action item)

let export_races ?(full=false) ~pipes ~entries ~source schedule witnesses =
  let open Race_report.Schedule in
  let convert = project_node ~pipes ~entries ~source schedule in
  let index = Race_report.index schedule in
  let conflicts = Hashtbl.create (List.length schedule.pairs) in
  List.iter (fun p -> Hashtbl.add conflicts (p.a,p.b) p.addresses) schedule.pairs;
  let export (w : Bug_traces.race_witness) =
    let forward = w.first_then_second and reverse = w.second_then_first in
    let a=Race_report.target index w.first forward and b=Race_report.target index w.second forward in
    let overlap=if full then Some (Race_report.pair_at schedule a b).addresses
      else Hashtbl.find_opt conflicts (a,b) in
    if overlap <> Some w.conflicts ||
       schedule.nodes.(a).id <> w.first || schedule.nodes.(b).id <> w.second then
      invalid "target operations differ from the paired program";
    let checked x y events =
      let ids = List.map index events in
      if (full && List.length ids<>Array.length schedule.nodes) ||
         replay_indices schedule ids <> events || List.filter (fun n -> n=a || n=b) ids <> [x;y]
      then invalid "invalid race prefix";
      List.filter_map (fun i -> convert schedule.nodes.(i)) ids in
    let forward = checked a b forward and reverse = checked b a reverse in
    {first=Option.get (convert schedule.nodes.(a));second=Option.get (convert schedule.nodes.(b));forward;reverse} in
  List.map export witnesses

let coverage_status = function
  | Concrete_schedule.All_pairs -> Complete_search | Full_trace n -> Full_race n
  | Race_free -> No_race | Unresolved reason -> Unknown reason

let encode_event =
  let task (t : task) = `Assoc ["id",`Int t.id;"pipe",`String (pipe_name t.pipe)] in
  let signal s = `Assoc ["receiver",`Int s.receiver;"source",`String (pipe_name s.source);
    "target",`String (pipe_name s.target);"flag",`Int s.flag;"cross",`Bool s.cross] in
  fun e ->
    let l = e.location in
    let action, signals = match e.action with
      | Compute -> "compute",[] | Barrier -> "barrier",[]
      | Set ks -> "set",ks | Wait k | Wait_all (_,k) -> "wait",[k] in
    let phase, tasks, synchronous_pipe = match e.phase with
      | Submit ts -> "submit",List.map task ts,None | Complete t -> "complete",[task t],None
      | Async_submit id | Async_complete id ->
          (match e.phase with Async_submit _ -> "submit" | _ -> "complete"),
          [`Assoc ["id",`Int id;"pipe",`String "HFUSION_ASYNC"]],None
      | Execute p -> "execute",[],p in
    let senders = match e.action with Wait_all (ss,_) -> ["senders",ints ss] | _ -> [] in
    let calls = match l.calls with
      | [] -> []
      | frames -> ["calls", `List (List.map (fun f -> `Assoc ["entry",`String f.caller;
          "path",ints f.call_path;"iterations",ints f.call_iterations]) frames)] in
    `Assoc (["entry",`String l.entry;"stream",`Int l.stream;"path",ints l.origin.path;
            "opcode",`String l.origin.opcode;"part",optional (fun x -> `String x) l.origin.part;
            "iterations",ints l.iterations;"action",`String action;"phase",`String phase;
            "tasks",`List tasks;"signals",`List (List.map signal signals);
            "synchronous_pipe",optional (fun p -> `String (pipe_name p)) synchronous_pipe] @ calls @ senders)

let to_json report =
  let encoded = Hashtbl.create 256 in
  let event e = match Hashtbl.find_opt encoded e with
    | Some json -> json
    | None -> let json = encode_event e in Hashtbl.add encoded e json; json in
  let race r = `Assoc ["first",event r.first;"second",event r.second;
    "forward",`List (List.map event r.forward);"reverse",`List (List.map event r.reverse)] in
  let status,details = match report.status with Complete_search -> "complete",[] | Race_found -> "race",[]
    | Full_race n -> Concrete_schedule.fields (Full_trace n)
    | No_race -> "no-race",[] | Unknown why -> "unknown",["reason",`String why] in
  `Assoc (["format",`String "hivm-race-1";"benchmark",`String report.benchmark;
    "streams",`List (List.map (fun (id,entry) -> `Assoc ["stream",`Int id;"entry",`String entry]) report.streams);
    "n",optional (fun n -> if Z.fits_int n then `Int (Z.to_int n) else `Intlit (Z.to_string n)) report.n;
    "inputs",report.inputs;
    "status",`String status;"races",`List (List.map race report.races)] @ details)
