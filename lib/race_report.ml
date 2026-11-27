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

let directions schedule a b forward reverse =
  let check x y ids =
    ignore (replay_indices schedule ids);
    if List.filter (fun i -> i=a || i=b) ids <> [x;y] ||
       List.hd (List.rev ids) <> y then invalid_arg "incorrect witness order" in
  check a b forward; check b a reverse

let core_race schedule index (w : Result.race_witness) =
  let f = List.map index w.first_then_second and r = List.map index w.second_then_first in
  let a = List.hd (List.rev r) and b = List.hd (List.rev f) in
  directions schedule a b f r;
  `Assoc ["first",occurrence w.first;"second",occurrence w.second;"nodes",ints [a;b];
          "conflicts",intervals w.conflicts;"forward",ints f;"reverse",ints r]

let read_core_race schedule j =
  let field k = Json.member k j in
  let a,b = match numbers (field "nodes") with [a;b] -> a,b | _ -> invalid_arg "expected two nodes" in
  let pair = List.find (fun p -> p.a=a && p.b=b) schedule.pairs in
  if occurrence schedule.nodes.(a).id <> field "first" || occurrence schedule.nodes.(b).id <> field "second"
    || intervals pair.addresses <> field "conflicts" then invalid_arg "incorrect conflict or identity";
  let read x y key =
    let ids=numbers (field key) in
    if List.filter (fun i -> i=a || i=b) ids<>[x;y] || List.hd (List.rev ids)<>y then
      invalid_arg "incorrect witness order";
    replay_indices schedule ids in
  Result.{first=schedule.nodes.(a).id;second=schedule.nodes.(b).id;conflicts=pair.addresses;
          first_then_second=read a b "forward";second_then_first=read b a "reverse"}

let replay_core schedule j = ignore (read_core_race schedule j)

let schedule launch n =
  Race_schedule.compile ~capacity:launch.Litao_benchmark.capacity (Historical_lang.instantiate launch.family n)

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

let witnesses backend schedule = match backend with
  | Bug_traces.Search -> Race_search.generate schedule
  | Solve -> Race_solve.generate schedule

let prefix_schedule ~capacity program =
  let compile=Schedule.compile ~capacity in
  let full=compile program in
  if full.boundaries=[] || Option.is_some (Race_search.precedence full) then full else
  let isolated (active : stream) =
    let streams=List.map (fun (s : stream) -> if s.id=active.id then s else {s with body=End}) program.streams in
    let prefix=compile {program with streams} in
    match Race_search.precedence prefix with
    | Some parents ->
        let graph=Precedence.build parents in
        if List.exists (fun p -> Precedence.unordered graph p.a p.b) prefix.pairs
        then Some {prefix with boundaries=full.boundaries} else None
    | None -> None in
  Option.value (List.find_map isolated program.streams) ~default:full

let core backend schedule =
  let result = witnesses backend schedule in
  List.map (core_race schedule (index schedule)) result.races
