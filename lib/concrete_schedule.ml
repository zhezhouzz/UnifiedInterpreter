open Core_lang
open Race_schedule

let large schedule = Array.exists (fun node ->
  List.exists (fun i -> i>=Loop_trace.threshold) node.id.iterations) schedule.nodes

let iteration_counts schedule =
  let streams=Hashtbl.create 8 in
  Array.map (fun node ->
    let seen=Option.value (Hashtbl.find_opt streams node.id.stream) ~default:0 in
    let n=max seen (Loop_trace.rounds node.id.iterations) in
    Hashtbl.replace streams node.id.stream n;n) schedule.nodes

let spans addresses =
  let rec group acc = function
    | [] -> List.rev acc
    | (storage,i)::tail -> (match acc with
        | (s,start,stop)::rest when storage=s && i<=stop -> group ((s,start,max stop (i+1))::rest) tail
        | _ -> group ((storage,i,i+1)::acc) tail) in
  group [] (List.sort_uniq compare addresses)

let select ?timeout_ms ?partial schedule parents validate =
  let accesses=Array.to_list (Array.mapi (fun node n -> match n.phase with
    | Finish {item=Operation (_,fp);_} | Emit {action=Immediate (Operation (_,fp));_} ->
        Some Loop_trace.{node;reads=spans fp.reads;writes=spans fp.writes}
    | _ -> None) schedule.nodes) |> List.filter_map Fun.id |> Array.of_list in
  Loop_trace.choose ?timeout_ms ?partial ~parents ~iterations:(iteration_counts schedule) (Array.to_list accesses)
    (fun graph i j -> validate graph accesses.(i).node accesses.(j).node)

let run ?(timeout_ms=5000) ?target ?(allow_cutoff=false) schedule =
  let rounds=iteration_counts schedule in
  let witness a b f r =
    let pair=Race_report.pair_at schedule a b in
    let f,r=if a=pair.a then f,r else r,f in
    Result.{first=schedule.nodes.(pair.a).id;second=schedule.nodes.(pair.b).id;conflicts=pair.addresses;
            first_then_second=replay_indices schedule f;second_then_first=replay_indices schedule r} in
  let complete order required a b =
    let f=required @ [a;b] and r=required @ [b;a] in
    f,witness a b (Loop_trace.complete order f) (Loop_trace.complete order r) in
  if schedule.boundaries<>[] || (schedule.cutoffs<>[] && not allow_cutoff) then
    Loop_trace.Incomplete "a complete continuation requires the entire launch"
  else if schedule.blocked_control then Loop_trace.No_race
  else match Race_search.precedence schedule with
  | Some parents ->
      let finite () = select ~timeout_ms schedule parents (fun g a b ->
        let required=Z.logor g.ancestors.(a) g.ancestors.(b) in
        Some (complete g.order (Array.to_list g.order |> List.filter (Z.testbit required)) a b)) in
      (match target with
       | Some (first,second) ->
           let order=Precedence.topological_order parents in
           if Array.length order<>Array.length parents then
             Loop_trace.Incomplete "the launch has pending events that cannot complete"
           else
             let locate id=Array.find_index (fun node -> node.id=id && match node.phase with
               | Finish {item=Operation _;_} | Emit {action=Immediate (Operation _);_} -> true | _ -> false) schedule.nodes in
             (match locate first,locate second with
              | Some a,Some b ->
                  let needed=Array.make (Array.length parents) false in
                  for k=Array.length order-1 downto 0 do
                    let i=order.(k) in
                    if i=a || i=b || needed.(i) then
                      List.iter (fun parent -> needed.(parent)<-true) parents.(i)
                  done;
                  if needed.(a) || needed.(b) then finite () else
                  let required=Array.to_list order |> List.filter (Array.get needed) in
                  let prefix,w=complete order required a b in
                  Loop_trace.Found (List.fold_left (fun k i -> max k rounds.(i)) 0 prefix,w)
              | _ -> finite ())
       | None -> finite ())
  | None ->
      let enc=Race_solve.encode ~timeout_ms schedule in
      Z3.Solver.add enc.solver (Array.to_list enc.present);
      let round_through last steps =
        let rec through n = function [] -> invalid_arg "missing race endpoint" | x::xs ->
          let n=max n rounds.(x) in if x=last then n else through n xs in through 0 steps in
      (try match Race_solve.check enc [] with
       | None -> Loop_trace.Incomplete "the launch has no legal complete execution"
       | Some _ ->
           let rec select best = function
             | [] -> (match best with None->Loop_trace.No_race | Some (k,w)->Loop_trace.Found (k,w))
             | p::rest -> match Race_solve.complete_direction enc rounds p.a p.b with
               | None -> select best rest
               | Some f -> match Race_solve.complete_direction enc rounds p.b p.a with
                 | None -> select best rest
                 | Some r ->
                     let k=max (round_through p.b f) (round_through p.a r) in
                     let best=match best with Some (old,_) when old<=k -> best
                       | _ -> Some (k,witness p.a p.b f r) in
                     select best rest in
           select None (conflict_pairs schedule.nodes)
       with Race_solve.Inconclusive reason -> Loop_trace.Incomplete reason)

type coverage = All_pairs | Full_trace of int | Race_free | Unresolved of string

let analyze ?timeout_ms ?target backend schedule =
  if schedule.boundaries<>[] then Unresolved (String.concat "\n" schedule.boundaries),[]
  else if large schedule then match run ?timeout_ms ?target schedule with
    | Found (n,w) -> Full_trace n,[w]
    | No_race -> Race_free,[]
    | Incomplete reason -> Unresolved reason,[]
  else try All_pairs,(Race_report.witnesses ?timeout_ms backend schedule).races
    with Race_solve.Inconclusive why -> Unresolved why,[]

let fields = function
  | All_pairs -> "complete",[]
  | Race_free -> "no-race",[]
  | Full_trace n -> "race",["trace_extent",`String "program_end";"prefix_rounds",`Int n]
  | Unresolved reason -> "unknown",["reason",`String reason]

let full = function Full_trace _ -> true | _ -> false

let compile ?loop_bound ~capacity program =
  Race_report.prefix_schedule ?loop_bound ~pair_limit:Loop_trace.threshold ~capacity program

let probe ~capacity program = compile ~loop_bound:(Loop_trace.threshold+1) ~capacity program

let full_schedule ~capacity program current =
  if current.cutoffs=[] then current else compile ~capacity program

let finish ~timeout_ms ?target ~capacity backend program current =
  let schedule=full_schedule ~capacity program current in
  let coverage,races=analyze ~timeout_ms ?target backend schedule in
  schedule,coverage,races

let from_probe ~timeout_ms ~capacity backend program probe =
  if probe.cutoffs=[] && not (large probe) then
    let coverage,races=analyze ~timeout_ms backend probe in probe,coverage,races
  else
    let finish ?target current = finish ~timeout_ms ?target ~capacity backend program current in
    let rec concrete_prefix bound current =
      if current.cutoffs=[] || current.boundaries<>[] then finish current else
      match Race_search.precedence current with None -> finish current | Some parents ->
      match select ~timeout_ms ~partial:true current parents (fun graph a b ->
        Some (Precedence.prefix graph a b,(current.nodes.(a).id,current.nodes.(b).id))) with
      | Found (_,pair) -> finish ~target:pair current
      | No_race when bound<=max_int/2 ->
          let bound=2*bound in concrete_prefix bound (compile ~loop_bound:bound ~capacity program)
      | No_race | Incomplete _ -> finish current in
    match backend with
    | Bug_traces.Search ->
        let rec search bound =
          if bound>=Loop_trace.threshold+1 then concrete_prefix (Loop_trace.threshold+1) probe
          else
            let current=compile ~loop_bound:bound ~capacity program in
            match Race_search.precedence current with
            | Some parents when current.boundaries=[] && current.cutoffs<>[] ->
                (match select ~timeout_ms ~partial:true current parents (fun graph a b ->
                   Some (Precedence.prefix graph a b,(current.nodes.(a).id,current.nodes.(b).id))) with
                 | Found (k,pair) ->
                     let schedule,coverage,races=finish ~target:pair probe in
                     (match coverage with Full_trace n when n=k -> schedule,coverage,races
                      | _ -> let coverage,races=analyze ~timeout_ms backend schedule in schedule,coverage,races)
                 | No_race -> search (2*bound)
                 | Incomplete _ -> concrete_prefix (Loop_trace.threshold+1) probe)
            | _ -> concrete_prefix (Loop_trace.threshold+1) probe in
        search 1
    | Solve -> concrete_prefix (Loop_trace.threshold+1) probe

let program ?(timeout_ms=5000) ~capacity backend program =
  from_probe ~timeout_ms ~capacity backend program (probe ~capacity program)

let of_report ~rounds report =
  let module J=Yojson.Safe.Util in
  match J.member "status" report,J.member "trace_extent" report,J.to_list (J.member "races" report) with
  | `String "race",`String "program_end",[row] ->
      let a,b=match Race_report.numbers (J.member "nodes" row) with
        | [a;b] -> a,b | _ -> invalid_arg "expected two race endpoints" in
      let rec through target n = function
        | [] -> invalid_arg "missing race endpoint"
        | i::rest -> let n=max n rounds.(i) in if i=target then n else through target n rest in
      let prefix key last=through last 0 (Race_report.numbers (J.member key row)) in
      let n=max (prefix "forward" b) (prefix "reverse" a) in
      if J.member "prefix_rounds" report<>`Int n then invalid_arg "incorrect race prefix round count";
      Full_trace n
  | `String "no-race",`Null,[] -> Race_free
  | `String "unknown",`Null,[] -> Unresolved (J.to_string (J.member "reason" report))
  | _ -> invalid_arg "invalid large-loop report"
