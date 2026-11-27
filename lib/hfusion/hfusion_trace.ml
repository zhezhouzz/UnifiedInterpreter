include Hfusion_model
module S = Hfusion_schedule
type backend = Bfs | Smt | Symbolic
type t = model
let prepare = compile
let scheduling_point model ~stream ~path =
  List.exists (fun site -> site.stream=stream && site.path=path) model.sites

let concrete_n model n=match model.parameter_max,n with
  | None,None -> Z.zero
  | Some max,Some i when Z.sign i>=0 && Z.leq i max -> i
  | Some _,None -> invalid_arg "missing concrete HFusion N"
  | None,Some _ -> invalid_arg "HFusion launch has no N parameter"
  | Some _,Some _ -> invalid_arg "HFusion N is outside the parameter type"

let generate ?n ?timeout_ms backend model =
  let report n status races={entry=model.program.name;launch=model.launch;n;status;races} in
  try match backend,model.parameter_max with
  | Symbolic,Some maximum ->
      if n<>None then invalid_arg "symbolic HFusion analysis chooses N";
      (match Hfusion_symbolic.query ?timeout_ms model maximum with
       | None -> report None No_race [] | Some (n,r) -> report (Some n) Race [r])
  | _ ->
      let schedule=S.build model (concrete_n model n) in
      let pairs=S.candidates schedule in
      if backend<>Symbolic && schedule.max_rounds>Unified_interpreter.Loop_trace.threshold then (
        if not schedule.complete then report n (Unknown "the launch does not reach program end") [] else
        match S.Order.complete_race ?timeout_ms (S.rules schedule) schedule.rounds pairs with
        | Found (k,(a,b,f,r)) -> report n (Full_race k) [S.race schedule a b f r]
        | No_race -> report n No_race [] | Incomplete why -> report n (Unknown why) [])
      else
      let races=match backend with Bfs -> S.bfs schedule pairs
        | Smt | Symbolic -> S.smt ?timeout_ms ~first_only:(backend=Symbolic) schedule pairs in
      (match backend,races with Symbolic,[] -> report n No_race []
       | Symbolic,r::_ -> report n Race [r] | _ -> report n Complete races)
  with S.Inconclusive reason -> report n (Unknown reason) []

let replay ?n model prefix=S.replay (S.build ~through:prefix model (concrete_n model n)) prefix
let verify ?(full=false) (schedule:S.t) r =
  let node event=match Hashtbl.find_opt schedule.by_event event with
    | Some i -> schedule.nodes.(i) | None -> invalid_arg "unknown HFusion race endpoint" in
  if not (S.conflict (node r.first) (node r.second)) then invalid_arg "unrelated HFusion race endpoints";
  let check first second events=
    S.replay schedule events;
    if not schedule.complete || (not full && not (S.Order.can_extend (S.rules schedule)
       (List.map (Hashtbl.find schedule.by_event) events))) then invalid_arg "HFusion race prefix cannot reach program end";
    if List.filter (fun e -> e=first || e=second) events<>[first;second] ||
       (if full then not schedule.complete || List.length events<>Array.length schedule.nodes
        else List.hd (List.rev events)<>second) then invalid_arg "wrong HFusion race endpoint order" in
  check r.first r.second r.forward;check r.second r.first r.reverse
let verify_race ?n model r =
  let ends e events=List.nth_opt (List.rev events) 0=Some e in
  let full=not (ends r.second r.forward && ends r.first r.reverse) in
  verify ~full (S.build model (concrete_n model n)) r

module J = Yojson.Safe.Util
let ints xs=`List (List.map (fun i -> `Int i) xs)
let list_of_ints j=List.map J.to_int (J.to_list j)
let argument_json = function
  | Integer i -> `Int i | Parameter -> `String "N" | Float x -> `Float x
  | Buffer b -> `Assoc ["allocation",`String b.allocation;"elements",`Int b.elements;
    "initialized",`Bool b.initialized;"offset",`Int b.offset;"shape",ints b.shape;"strides",ints b.strides]
let launch_of_json j =
  let argument = function
    | `Int i -> Integer i | `Float x -> Float x | `String "N" -> Parameter
    | `Assoc _ as b -> Buffer {allocation=J.to_string (J.member "allocation" b);
        elements=J.to_int (J.member "elements" b);initialized=J.to_bool (J.member "initialized" b);
        offset=J.to_int (J.member "offset" b);shape=list_of_ints (J.member "shape" b);
        strides=list_of_ints (J.member "strides" b)}
    | _ -> invalid_arg "invalid HFusion argument JSON" in
  J.to_list j |> List.map (fun row -> J.to_assoc row |> List.map (fun (k,v) -> k,argument v))
let to_json report =
  let event (e:event)=`Assoc ["entry",`String e.entry;"stream",`Int e.stream;"path",ints e.path;
    "opcode",`String e.opcode;"iterations",ints e.iterations;"phase",`String "execute"] in
  let events es=`List (List.map event es) in
  let race r=`Assoc ["first",event r.first;"second",event r.second;
    "forward",events r.forward;"reverse",events r.reverse] in
  let status,detail=match report.status with Complete -> "complete",[] | Race -> "race",[]
    | Full_race k -> "race",["trace_extent",`String "program_end";"prefix_rounds",`Int k]
    | No_race -> "no-race",[] | Unknown why -> "unknown",["reason",`String why] in
  let inputs=`List (List.map (fun args -> `Assoc (List.map (fun (k,v) -> k,argument_json v) args)) report.launch) in
  `Assoc (["format",`String "hfusion-race-1";"entry",`String report.entry;
    "inputs",inputs;"n",Option.fold ~none:`Null ~some:(fun n ->
      if Z.fits_int n then `Int (Z.to_int n) else `Intlit (Z.to_string n)) report.n;
    "status",`String status;"races",`List (List.map race report.races)]@detail)

let read_ast file =
  let j=Yojson.Safe.from_file file in
  Ast.check_integer_range file j;
  {Ast.name=J.to_string (J.member "name" j);
   arguments=List.map Ast.argument (J.to_list (J.member "arguments" j));
   body=List.map Ast.operation (J.to_list (J.member "body" j))}

let replay_report (program:Ast.program) doc =
  if J.member "format" doc<>`String "hfusion-race-1" || J.member "entry" doc<>`String program.name
  then invalid_arg "HFusion report format or entry mismatch";
  let model=prepare program (launch_of_json (J.member "inputs" doc)) in
  let n=match J.member "n" doc with `Int i -> Some (Z.of_int i) | `Intlit s -> Some (Z.of_string s)
    | `Null -> None | _ -> invalid_arg "invalid HFusion report N" in
  let event j =
    if J.member "phase" j<>`String "execute" then invalid_arg "invalid HFusion event phase";
    {entry=J.to_string (J.member "entry" j);stream=J.to_int (J.member "stream" j);
     iterations=list_of_ints (J.member "iterations" j);path=list_of_ints (J.member "path" j);
     opcode=J.to_string (J.member "opcode" j)} in
  let races=J.to_list (J.member "races" doc) in
  (match J.member "status" doc,races with
   | `String "complete",_ | `String "race",[_] | `String ("unknown"|"no-race"),[] -> ()
   | _ -> invalid_arg "inconsistent HFusion report status");
  List.iter (fun r ->
    let prefix key=List.map event (J.to_list (J.member key r)) in
    let race={first=event (J.member "first" r);second=event (J.member "second" r);
              forward=prefix "forward";reverse=prefix "reverse"} in
    if J.member "trace_extent" doc=`String "program_end" then verify ~full:true (S.build model (concrete_n model n)) race
    else verify_race ?n model race) races;
  List.length races
