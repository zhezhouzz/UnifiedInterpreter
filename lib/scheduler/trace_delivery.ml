open Stdlib
open Unified_interpreter
module D = Dispatch
module H = Trace_history
module J = Yojson.Safe.Util

type extent = Race_prefix | Terminal of string
type trace = {events:D.event list; hash:string; extent:extent; targets:Yojson.Safe.t; reused:bool}
exception Incomplete of string

let status = function D.Finished->"returned" | Blocked _->"deadlock" | Invalid_memory _->"invalid-memory"
  | Step_limit site->raise (Incomplete ("execution step limit at "^site))
let encode t =
  let extent,terminal=match t.extent with Race_prefix->"race_prefix",`Null | Terminal s->"terminal",`String s in
  `Assoc ["events",`List (List.map D.encode t.events);"hash",`String t.hash;"extent",`String extent;
          "terminal",terminal;"targets",t.targets;"reused",`Bool t.reused]
let decode doc =
  let field k=J.member k doc in
  {events=List.map D.decode (J.to_list (field "events"));hash=J.to_string (field "hash");
   extent=(match field "terminal" with `Null->Race_prefix | s->Terminal (J.to_string s));
   targets=field "targets";reused=true}
let make events extent targets =
  let bytes=Yojson.Safe.to_string (`List (List.map D.encode events)) in
  {events;hash=H.sha bytes;extent;targets;reused=false}

let replay trace =
  let remaining=ref trace.events in
  let choose options=match !remaining with
    | next::tail when List.mem next options->remaining:=tail;next
    | next::_->invalid_arg ("disabled trace event "^Yojson.Safe.to_string (D.encode next))
    | []->(match trace.extent with Race_prefix->List.hd options | Terminal _->invalid_arg "extra scheduling event") in
  let verify outcome=
    let actual=status outcome in
    if !remaining<>[] then invalid_arg "execution ended before trace";
    match trace.extent with Terminal expected when expected<>actual->invalid_arg "different terminal state" | _->() in
  choose,verify

(* Convert analysis-local task IDs to the occurrence of the corresponding source
   submission. Several pipes can be submitted by one source barrier. *)
let guide_events first last sequence =
  let issued=Hashtbl.create 32 and counts=Hashtbl.create 32 in
  let ranks=Hashtbl.create 64 and pos=ref 0 and a=ref None and b=ref None in
  let convert raw=
    let field k=J.member k raw in
    let stream=J.to_int (field "stream") and opcode=J.to_string (field "opcode") in
    let site=D.site (J.to_string (field "entry")) (List.map J.to_int (J.to_list (field "path"))) opcode in
    let fresh phase pipe=
      let key=stream,site,pipe in let occurrence=Option.value (Hashtbl.find_opt counts key) ~default:0 in
      Hashtbl.replace counts key (occurrence+1);{D.stream;site;pipe;occurrence;phase} in
    let phase=J.to_string (field "phase") in
    let events=match phase with
      | "execute"->[fresh Execute "S"]
      | "submit"|"complete"->List.map (fun task->
          let id=J.to_int (J.member "id" task) and p=J.to_string (J.member "pipe" task) in
          let pipe=if String.starts_with ~prefix:"PIPE_" p then String.sub p 5 (String.length p-5) else p in
          if phase="submit" then (let e=fresh Submit pipe in Hashtbl.add issued (stream,id) e;e)
          else let e=Hashtbl.find issued (stream,id) in {e with phase=Complete}) (J.to_list (field "tasks"))
      | _->invalid_arg "invalid source trace phase" in
    let events=match phase,events with
      | "submit",([] | _::_::_) -> [fresh Submit "ALL"] | _->events in
    List.iter (fun e->Hashtbl.replace ranks e !pos;incr pos;
      if raw=first then a:=Some e;if raw=last then b:=Some e) events in
  let rec until=function []->invalid_arg "missing race endpoint" | raw::tail->
    convert raw;if raw<>last then until tail in
  until sequence;ranks,Option.get !a,Option.get !b

(* 只记录存在多种选择的位置。一次执行结束后，从最近的未访问分支继续。 *)
let branch_cursor cursor =
  let path=ref cursor and reversed=ref [] and successor=ref None in
  let select = function
    | [event] -> event
    | events ->
        let index=match !path with []->0 | i::rest->path:=rest;i in
        if index+1<List.length events then successor:=Some ((index+1)::!reversed);
        reversed:=index::!reversed;
        List.nth events index in
  let next ()=
    if !path<>[] then invalid_arg "stale scheduler cursor";
    Option.map List.rev !successor in
  select,next

let race_trace run guide cursor =
  let get k=J.member k guide in
  let ranks,first,last=guide_events (get "first") (get "last") (J.to_list (get "sequence")) in
  let rank e=Option.value (Hashtbl.find_opt ranks e) ~default:max_int in
  let select,next=branch_cursor cursor in
  let exception Out_of_order in
  let prefix=ref [] and seen=ref false and done_=ref false and after_endpoint=ref false in
  let choose options=
    if !done_ then after_endpoint:=true;
    let e=if !done_ then List.hd options else (
      let allowed=if !seen then options else List.filter ((<>) last) options in
      if allowed=[] then raise Out_of_order;
      select (List.stable_sort (fun a b->Int.compare (rank a) (rank b)) allowed)) in
    if not !done_ then (
      prefix:=e::!prefix;
      if e=first then seen:=true;
      if e=last then done_:=true);
    e in
  let confirmed=match run choose with
    | exception Out_of_order -> false
    | D.Invalid_memory _ -> !after_endpoint
    | outcome -> ignore (status outcome); !done_ in
  if confirmed then (
    let target source event=`Assoc ["source",source;"event",D.encode event] in
    Some (make (List.rev !prefix) Race_prefix (`List [target (get "first") first;target (get "last") last])),None)
  else None,next ()

(* A cursor contains only indices at genuine choices. Following one branch
   computes the nearest unexplored sibling without retaining interpreter heaps. *)
let next_leaf run cursor =
  let select,next=branch_cursor cursor and events=ref [] in
  let choose options=let event=select options in events:=event::!events;event in
  let terminal=status (run choose) in
  make (List.rev !events) (Terminal terminal) `Null,next ()

let next_trace ?db_path ?(timeout_ms=120_000) ~identity ~analyze ~execute () =
  if timeout_ms<=0 then invalid_arg "scheduler timeout must be positive";
  let deadline=Unix.gettimeofday ()+.float timeout_ms/.1000. in
  let budget ()=if Unix.gettimeofday ()>=deadline then raise (Incomplete "scheduler request timed out") in
  let filename=match db_path with Some path->path | None->H.default_file () in
  let key=H.text (H.sha (Yojson.Safe.to_string (Yojson.Safe.sort (`List [`String "source-dispatch-1";identity])))) in
  let run select=
    let choose options=budget ();select options in
    execute choose in
  try H.with_db ~timeout_ms filename (fun db->
    let state ()=H.row db "SELECT guide,cursor,revision FROM searches WHERE id=?" [key] in
    if state ()=None then (
      let report=analyze ~timeout_ms in
      if J.member "status" report=`String "unknown" then raise (Incomplete (J.to_string (J.member "reason" report)));
      let races=J.to_list (J.member "races" report) in
      H.transaction db (fun ()->if state ()=None then (
        H.write db "INSERT INTO searches VALUES (?,0,'[]',0)" [key];
        (match J.member "trace" report with
         | `Assoc _ as trace when J.member "extent" trace=`String "terminal" ->
             H.write db "INSERT INTO guides VALUES (?,0,?)" [key;H.text (Yojson.Safe.to_string trace)]
         | _ -> ());
        List.iteri (fun i race->
          let get k=J.member k race in
          List.iteri (fun j (a,b,order)->
            let guide=`Assoc ["first",get a;"last",get b;"sequence",get order] in
            H.write db "INSERT INTO guides VALUES (?,?,?)"
              [key;Sqlite3.Data.INT (Int64.of_int (2*i+j));H.text (Yojson.Safe.to_string guide)])
            ["first","second","forward";"second","first","reverse"]) races)));
    let rec request ()=
      budget ();
      let s=Option.get (state ()) in
      let cursor=s.(1) and revision=s.(2) in
      let guide=H.row db "SELECT body FROM guides WHERE id=? AND seq=?" [key;s.(0)] in
      match guide,cursor with
      | None,Sqlite3.Data.NULL->
          let row=Option.get (H.row db "SELECT body FROM issued WHERE id=? ORDER BY rowid LIMIT 1" [key]) in
          decode (Yojson.Safe.from_string (H.string row.(0)))
      | _->
          let path=List.map J.to_int (J.to_list (Yojson.Safe.from_string (H.string cursor))) in
          let candidate,next,g=match guide with
            | Some row->
                let guide=Yojson.Safe.from_string (H.string row.(0)) in
                let t,next=match J.member "terminal" guide with
                  | `String terminal->
                      let events=List.map D.decode (J.to_list (J.member "events" guide)) in
                      let trace=make events (Terminal terminal) `Null in
                      let choose,verify=replay trace in verify (run choose);Some trace,None
                  | _->race_trace run guide path in
                (match next with Some _->t,next,s.(0) | None->
                  t,Some [],Sqlite3.Data.INT (Int64.succ (Sqlite3.Data.to_int64_exn s.(0))))
            | None->let t,next=next_leaf run path in Some t,next,s.(0) in
          let next=match next with None->Sqlite3.Data.NULL
            | Some xs->H.text (Yojson.Safe.to_string (`List (List.map (fun i->`Int i) xs))) in
          budget ();
          let claimed=H.transaction db (fun ()->
            H.write db "UPDATE searches SET revision=revision+1,guide=?,cursor=? WHERE id=? AND revision=?"
              [g;next;key;revision];
            if Sqlite3.changes db=0 then None else match candidate with None->None | Some candidate->
              H.write db "INSERT OR IGNORE INTO issued VALUES (?,?,?)"
                [key;H.text candidate.hash;H.text (Yojson.Safe.to_string (encode candidate))];
              if Sqlite3.changes db=1 then Some candidate else (
                let existing=Option.get (H.row db "SELECT body FROM issued WHERE id=? AND hash=?" [key;H.text candidate.hash]) in
                let issued=decode (Yojson.Safe.from_string (H.string existing.(0))) in
                if issued.events<>candidate.events then failwith "scheduler trace hash collision";
                None)) in
          match claimed with Some trace->trace | None->request () in
    request ())
  with H.Busy -> raise (Incomplete "scheduler history is busy")
