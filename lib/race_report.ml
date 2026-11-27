module Json = Yojson.Safe.Util
open Core_lang
open Race_schedule
module Schedule = Race_schedule
let predecessors = Race_search.precedence

let ints xs = `List (List.map (fun i -> `Int i) xs)
let numbers j = Json.to_list j |> List.map Json.to_int
let occurrence id = `Assoc ["stream",`Int id.stream;"site",ints id.site;"iterations",ints id.iterations]
let storage = function Input i -> `List [`String "input";`Int i]
  | Invalid_address -> `List [`String "invalid"]
  | Allocated id -> `List [`String "alloc";occurrence id]
let intervals addresses =
  let rec loop acc = function
    | [] -> `List (List.rev acc)
    | (bank,first)::rest ->
        let rec range last = function
          | (s,i)::xs when s=bank && i=last+1 -> range i xs
          | xs -> loop (`List [storage bank;`Int first;`Int (last+1)]::acc) xs in
        range first rest in
  loop [] addresses
let key = function Issued (id,_) -> id,None | Done {id;pipe;_} -> id,Some pipe
let index schedule =
  let table = Hashtbl.create (Array.length schedule.nodes) in
  Array.iteri (fun i node ->
    Hashtbl.add table (node.id,match node.phase with Emit _ -> None | Finish {pipe;_} -> Some pipe) i
  ) schedule.nodes;
  fun e -> Hashtbl.find table (key e)

let directions ?(full=false) schedule a b forward reverse =
  let check x y ids =
    ignore (replay_indices schedule ids);
    if List.filter (fun i -> i=a || i=b) ids <> [x;y] ||
       (if full then List.length ids<>Array.length schedule.nodes else List.hd (List.rev ids) <> y)
    then invalid_arg "incorrect witness order" in
  check a b forward; check b a reverse

let target index id events =
  List.find_map (function
    | (Done d as e) when d.id=id -> Some (index e)
    | (Issued (i,Immediate (Operation _)) as e) when i=id -> Some (index e)
    | _ -> None) events |> Option.get

let core_race ?(full=false) schedule index (w : Result.race_witness) =
  let f = List.map index w.first_then_second and r = List.map index w.second_then_first in
  let a = target index w.first w.first_then_second and b = target index w.second w.first_then_second in
  directions ~full schedule a b f r;
  `Assoc ["first",occurrence w.first;"second",occurrence w.second;"nodes",ints [a;b];
          "conflicts",intervals w.conflicts;"forward",ints f;"reverse",ints r]

let pair_at schedule a b =
  if a=b then invalid_arg "identical race endpoints";
  let x,y=min a b,max a b in
  match Schedule.conflict_pairs [|schedule.nodes.(x);schedule.nodes.(y)|] with
  | [p] -> {p with a=x;b=y}
  | _ -> invalid_arg "no shared address at race endpoints"

let read_core_race ?(full=false) schedule =
  let can_extend=lazy (Race_solve.can_extend schedule) in
  fun j ->
  if schedule.blocked_control || schedule.boundaries<>[] || schedule.cutoffs<>[] then invalid_arg "unfinished launch";
  let field k = Json.member k j in
  let a,b = match numbers (field "nodes") with [a;b] -> a,b | _ -> invalid_arg "expected two nodes" in
  let pair = pair_at schedule a b in
  if occurrence schedule.nodes.(a).id <> field "first" || occurrence schedule.nodes.(b).id <> field "second"
    || intervals pair.addresses <> field "conflicts" then invalid_arg "incorrect conflict or identity";
  let read x y key =
    let ids=numbers (field key) in
    if List.filter (fun i -> i=a || i=b) ids<>[x;y] ||
       (if full then List.length ids<>Array.length schedule.nodes else List.hd (List.rev ids)<>y) then
      invalid_arg "incorrect witness order";
    let events=replay_indices schedule ids in
    if not full && not ((Lazy.force can_extend) ids) then invalid_arg "race prefix cannot reach program end";
    events in
  Result.{first=schedule.nodes.(a).id;second=schedule.nodes.(b).id;conflicts=pair.addresses;
          first_then_second=read a b "forward";second_then_first=read b a "reverse"}

let replay_core ?full schedule =
  let read=read_core_race ?full schedule in fun j -> ignore (read j)

let schedule ?pair_limit launch n =
  Race_schedule.compile ?pair_limit ~capacity:launch.Litao_benchmark.capacity (Historical_lang.instantiate launch.family n)

let events_of op_name schedule =
  let item = function Operation (op,_) -> op_name op
    | Set _ -> "set" | Wait _ | Wait_peers _ -> "wait" | Bar -> "barrier" in
  `List (Array.to_list (Array.map (fun node ->
    let phase,kind,pipe = match node.phase with
      | Emit {action;_} -> (match action with
          | Immediate i -> "scalar",item i,Some scalar_pipe | Submit (p,i) -> "issue",item i,Some p
          | Fence _ -> "issue","barrier",None | Control -> "host","control",None
          | Scalar_wait _ -> "scalar","wait",Some scalar_pipe | Reserve _ -> "host","alloc",None)
      | Finish {pipe;item=i;_} -> "done",item i,Some pipe in
    `Assoc ["id",occurrence node.id;"phase",`String phase;"operation",`String kind;
           "pipe",Option.fold ~none:`Null ~some:(fun p -> `Int p) pipe]) schedule.nodes))

let events launch = events_of launch.Litao_benchmark.op_name

let witnesses ?timeout_ms backend schedule =
  match backend with
  | Bug_traces.Search -> Race_search.generate schedule
  | Solve -> Race_solve.generate ?timeout_ms schedule

let prefix_schedule ?loop_bound ?pair_limit ~capacity program =
  Schedule.compile ?loop_bound ?pair_limit ~capacity program

let core backend schedule =
  let result = witnesses backend schedule in
  List.map (core_race schedule (index schedule)) result.races
