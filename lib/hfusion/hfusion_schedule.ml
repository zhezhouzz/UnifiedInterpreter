open Hfusion_model

type footprint = { allocation : storage * int list; initial : bool; ranges : interval list }
type node = { event : event; reads : footprint list; writes : footprint list;
              claims : footprint list; previous : int option }
type dependencies = { writers : int list list; incompatible : int list }
type t = { nodes : node array; dependencies : dependencies array; by_event : (event,int) Hashtbl.t }

let rec take n xs = if n=0 then [] else List.hd xs::take (n-1) (List.tl xs)
let intersect a b = a.allocation=b.allocation && overlaps a.ranges b.ranges
let any_overlap xs ys = List.exists (fun x -> List.exists (intersect x) ys) xs
let conflict a b = a.event.stream<>b.event.stream &&
  (any_overlap a.writes (b.writes@b.reads) || any_overlap a.reads b.writes)

let instantiate ?through model n =
  let exception Prefix_complete in
  let targets=Option.map (fun events ->
    let streams=Array.init (List.length model.streams) (fun _ -> Hashtbl.create 8) in
    List.iter (fun (e:event) ->
      if e.stream<0 || e.stream>=Array.length streams then invalid_arg "unknown HFusion stream";
      Hashtbl.replace streams.(e.stream) e ()) events;
    streams) through in
  let count=ref 0 and nodes=ref [] in
  List.iteri (fun stream body ->
    let pending=Option.map (fun streams -> streams.(stream)) targets in
    let previous=ref None in
    let rec execute ivs iterations body =
      let value=eval n ivs in
      let footprint v =
        let local=match v.storage with External _ -> [] | Local (_,_,depth) -> take depth iterations in
        {allocation=v.storage,local; initial=v.initial; ranges=translate (value v.base) v.cells} in
      List.iter (function
        | For (loop,body) ->
            let start=value loop.lo and stop=value loop.hi and step=value loop.step in
            if Z.sign step<=0 then raise Invalid_iteration;
            let rec iter i ordinal =
              if Z.lt i stop then begin
                execute (ivs@[i]) (iterations@[ordinal]) body;
                let next=eval_binary E.ArithAddI loop.ty i step in
                if Z.leq next i then raise Invalid_iteration;
                iter next (ordinal+1)
              end in
            iter start 0
        | Check v ->
            if List.exists (fun (a,b) -> Z.sign a<0 || Z.geq b v.capacity) (footprint v).ranges
            then raise Invalid_iteration
        | Disjoint (a,b) ->
            if intersect (footprint a) (footprint b) then raise Invalid_iteration
        | Evaluate e -> ignore (value e)
        | Stop -> raise Invalid_iteration
        | Access site ->
            let event={stream;entry=model.program.name;path=site.path;opcode=site.opcode;iterations} in
            let node={event;previous= !previous;reads=List.map footprint site.reads;
                      writes=List.map footprint site.writes;claims=List.map footprint site.claims} in
            nodes:=node::!nodes;previous:=Some !count;incr count;
            Option.iter (fun events ->
              Hashtbl.remove events event;
              if Hashtbl.length events=0 then raise Prefix_complete) pending) body in
    (* 一个实例的错误操作无法完成。之前已经完成的操作仍属于合法前缀。 *)
    if Option.fold ~none:true ~some:(fun events -> Hashtbl.length events>0) pending then
      match execute [] [] body with () -> () | exception (Invalid_iteration | Prefix_complete) -> ()) model.streams;
  Array.of_list (List.rev !nodes)

(* 每段未初始化的地址需要至少一个先前写入者。写入覆盖范围的端点
   把读取区间划分为若干段，同一段的每个元素有相同的候选写入者。 *)
let dependencies nodes =
  let writes=Hashtbl.create 32 in
  Array.iteri (fun i node -> List.iter (fun w ->
    let old=Option.value ~default:[] (Hashtbl.find_opt writes w.allocation) in
    Hashtbl.replace writes w.allocation (List.rev_append (List.map (fun r -> i,r) w.ranges) old)
  ) node.writes) nodes;
  Array.mapi (fun i node ->
    let read r =
      if r.initial then [] else
      let writers=Option.value ~default:[] (Hashtbl.find_opt writes r.allocation)
        |> List.filter (fun (j,_) -> nodes.(j).event.stream<>node.event.stream || j<i) in
      List.concat_map (fun (lo,hi) ->
        let writers=List.filter_map (fun (j,(a,b)) ->
          if Z.lt b lo || Z.lt hi a then None else Some (j,(Z.max lo a,Z.min hi b))) writers in
        let cuts=lo::List.concat_map (fun (_, (a,b)) -> if Z.lt b hi then [a;Z.succ b] else [a]) writers
          |> List.sort_uniq Z.compare in
        List.filter_map (fun x ->
          let ids=List.filter_map (fun (j,(a,b)) -> if Z.leq a x && Z.leq x b then Some j else None) writers in
          if List.exists (fun j -> nodes.(j).event.stream=node.event.stream) ids then None
          else Some (List.sort_uniq compare ids)) cuts) r.ranges in
    let incompatible=if node.claims=[] then [] else
      Array.to_list (Array.mapi (fun j other ->
        if j<>i && any_overlap node.claims other.claims then Some j else None) nodes) |> List.filter_map Fun.id in
    {writers=List.concat_map read node.reads |> List.sort_uniq compare;incompatible}) nodes

let build ?through model n =
  let nodes=instantiate ?through model n in
  let by_event=Hashtbl.create (Array.length nodes) in
  Array.iteri (fun i node -> Hashtbl.add by_event node.event i) nodes;
  {nodes;dependencies=dependencies nodes;by_event}

let enabled schedule seen i =
  let present=Z.testbit seen and deps=schedule.dependencies.(i) in
  not (present i) && Option.fold ~none:true ~some:present schedule.nodes.(i).previous &&
  not (List.exists present deps.incompatible) && List.for_all (List.exists present) deps.writers
let advance seen i=Z.logor seen (Z.shift_left Z.one i)
let replay schedule events =
  ignore (List.fold_left (fun seen event ->
    let i=match Hashtbl.find_opt schedule.by_event event with Some i -> i
      | None -> invalid_arg "unknown HFusion trace event" in
    if not (enabled schedule seen i) then invalid_arg "disabled HFusion trace event";
    advance seen i) Z.zero events)

let candidates schedule =
  let allocations=Hashtbl.create 16 and pairs=Hashtbl.create 32 in
  let record stream i write view=match fst view.allocation with
    | Local _ -> ()
    | External name ->
        let streams=match Hashtbl.find_opt allocations name with
          | Some group -> group
          | None -> let group=Hashtbl.create 4 in Hashtbl.add allocations name group;group in
        let writes,reads=Option.value ~default:([],[]) (Hashtbl.find_opt streams stream) in
        let access=i,view.ranges in
        Hashtbl.replace streams stream (if write then access::writes,reads else writes,access::reads) in
  Array.iteri (fun i node ->
    List.iter (record node.event.stream i true) node.writes;
    List.iter (record node.event.stream i false) node.reads) schedule.nodes;
  let compare_groups xs ys=List.iter (fun (i,left) -> List.iter (fun (j,right) ->
    if overlaps left right then Hashtbl.replace pairs (min i j,max i j) ()) ys) xs in
  let rec compare_streams = function
    | [] -> ()
    | (writes,reads)::rest ->
        List.iter (fun (other_writes,other_reads) ->
          compare_groups writes other_writes;
          compare_groups writes other_reads;
          compare_groups reads other_writes) rest;
        compare_streams rest in
  Hashtbl.iter (fun _ streams -> compare_streams (List.of_seq (Hashtbl.to_seq_values streams))) allocations;
  Hashtbl.to_seq_keys pairs |> List.of_seq |> List.sort compare

let race schedule a b forward reverse =
  let events=List.map (fun i -> schedule.nodes.(i).event) in
  let forward=events forward and reverse=events reverse in
  replay schedule forward;replay schedule reverse;
  {first=schedule.nodes.(a).event;second=schedule.nodes.(b).event;forward;reverse}

module Order = Unified_interpreter.Event_order
exception Inconclusive = Order.Inconclusive
let solver ctx timeout_ms =
  let s=Z3.Solver.mk_solver ctx None in
  Option.iter (fun ms ->
    if ms<=0 then invalid_arg "timeout_ms must be positive";
    let p=Z3.Params.mk_params ctx in
    Z3.Params.add_int p (Z3.Symbol.mk_string ctx "timeout") ms;
    Z3.Solver.set_parameters s p) timeout_ms;s
let check solver assumptions = match Z3.Solver.check solver assumptions with
  | SATISFIABLE -> Some (Option.get (Z3.Solver.get_model solver))
  | UNSATISFIABLE -> None
  | UNKNOWN -> raise (Inconclusive (Z3.Solver.get_reason_unknown solver))
let number model e=Z3.Arithmetic.Integer.get_big_int (Option.get (Z3.Model.eval model e true))

let generate ?timeout_ms ?first_only backend schedule pairs =
  let rules = Array.mapi (fun i node ->
    let deps = schedule.dependencies.(i) in
    Order.{requires=List.map (fun n -> [n]) (Option.to_list node.previous) @ deps.writers;
           excludes=deps.incompatible}) schedule.nodes in
  Order.generate ?timeout_ms ?first_only backend rules pairs
  |> List.map (fun (a,b,f,r) -> race schedule a b f r)

let bfs schedule pairs = generate Bfs schedule pairs
let smt ?timeout_ms ?first_only schedule pairs = generate ?timeout_ms ?first_only Smt schedule pairs
