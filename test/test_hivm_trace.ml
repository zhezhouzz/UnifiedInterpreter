open Stdlib
open Unified_interpreter
module H = Hivm_trace
module C = Core_lang
module J = Yojson.Safe.Util

let catalog = Race_benchmarks.catalog "../benchmark"
let registered = H.registered ~root:"../benchmarks/hivm" catalog
let fixture file = H.read_ast ("../benchmarks/hivm/" ^ file ^ ".ast.json")
let methods = Benchmark_traces.[Concrete Search; Concrete Solve; Symbolic]

(* 以使用方的视角，只通过公共事件和原始 AST 解析位置与任务。 *)
let consume ast events =
  let pending = Hashtbl.create 8 in
  List.iter (fun (event : H.event) ->
    let loc = event.location in
    let op = H.resolve ast loc.origin.path in
    assert (op.opcode = loc.origin.opcode && loc.entry = ast.name);
    let identity = loc, event.action in
    match event.phase with
    | Submit tasks ->
        List.iter (fun (task : H.task) ->
          assert (not (Hashtbl.mem pending task.id));
          Hashtbl.add pending task.id (identity,task.pipe)) tasks
    | Complete task ->
        assert (Hashtbl.find pending task.id = (identity,task.pipe));
        Hashtbl.remove pending task.id
    | Async_submit _ | Async_complete _ -> failwith "unexpected HFusion task in HIVM trace"
    | Execute _ -> ()) events;
  Hashtbl.length pending

let check_pair ast (race : H.race) =
  let check first second events =
    assert (List.filter (fun e -> e = first || e = second) events = [first;second]);
    assert (List.hd (List.rev events) = second);
    consume ast events in
  check race.first race.second race.forward, check race.second race.first race.reverse

let reject f = match f () with
  | exception Invalid_argument _ -> ()
  | _ -> failwith "accepted an invalid HIVM pairing"

let two_loads () =
  let name = "fixture/hivm-two-loads" in
  let ast = fixture "two_loads_hivm" in
  let pairing = registered name ast in
  List.iter (fun method_ ->
    let r = H.generate method_ pairing in
    assert (r.streams = [0,"@two_loads"] && Z.geq (Option.get r.n) Z.one);
    assert (J.member "format" (H.to_json r) = `String "hivm-race-1");
    match r.races with
    | [race] ->
        ignore (check_pair ast race);
        let issued events = List.filter_map (fun (e : H.event) ->
          match e.phase with
          | Submit [task] -> assert (task.pipe = MTE2); Some task.id
          | _ -> None) events in
        assert (List.length (List.sort_uniq compare (issued race.forward)) >= 2);
        let sources events = List.filter_map (fun (e : H.event) ->
          match e.phase with
          | Complete _ ->
              (match e.location.iterations with
               | [i] -> assert (i >= 0 && Z.lt (Z.of_int i) (Option.get r.n))
               | _ -> failwith "expected one loop coordinate");
              let op = H.resolve ast e.location.origin.path in
              assert (op.outputs = ["%dst"]);
              Some op.inputs
          | _ -> None) events in
        let forward = sources race.forward and reverse = sources race.reverse in
        (match method_ with
         | Concrete _ ->
             assert (r.n = Some Z.one);
             assert (forward = [["%a"];["%b"]] && reverse = [["%b"];["%a"]])
         | Symbolic ->
             let concrete = H.generate ~n:(Z.to_int (Option.get r.n)) (Concrete Search) pairing in
             assert (List.exists (fun (p : H.race) ->
               p.first = race.first && p.second = race.second) concrete.races))
    | _ -> failwith "expected one pair of loads") methods;
  let loop = H.generate ~n:2 (Concrete Search) pairing in
  assert (List.exists (fun (r : H.race) -> r.first.location.origin = r.second.location.origin &&
      r.first.location.iterations <> r.second.location.iterations) loop.races);
  List.iter (fun r -> ignore (check_pair ast r)) loop.races;
  assert ((H.generate ~n:0 (Concrete Solve) pairing).races = []);
  reject (fun () -> registered "fixture/fifo-copy" ast);
  reject (fun () -> H.resolve ast [2;100]);
  (* 即使两个 load 的 opcode 一样，交换源缓冲区也必须拒绝内置配对。 *)
  let change (op : H.Ast.operation) = if op.opcode <> "scf.for" then op
    else {op with region=List.rev op.region} in
  reject (fun () -> registered name {ast with body=List.map change ast.body});
  let root = "../benchmarks/hivm" in
  let file = Filename.concat root "two_loads_hivm.ast.json" in
  let from_file = H.registered_file ~root catalog name file in
  assert (H.generate (Concrete Search) pairing = H.generate (Concrete Search) from_file);
  let rec change_space = function
    | `Assoc fields -> `Assoc (List.map (fun (key,v) -> key,change_space v) fields)
    | `List xs -> `List (List.map change_space xs)
    | `String "#hivm.address_space<gm>" -> `String "#hivm.address_space<ub>"
    | value -> value in
  let changed = Filename.temp_file ~temp_dir:"." "two-loads-space-" ".json" in
  Fun.protect ~finally:(fun () -> Sys.remove changed) (fun () ->
    Yojson.Safe.to_file changed (change_space (Yojson.Safe.from_file file));
    reject (fun () -> H.registered_file ~root catalog name changed))

let issue316 () =
  let ordered = fixture "issue316_vexp_hivm" and missing = fixture "issue316_missing_ready_hivm" in
  let fixed = registered "issue316/ordered" ordered in
  let buggy = registered "issue316/missing-ready" missing in
  reject (fun () -> registered "issue316/missing-ready" ordered);
  List.iter (fun method_ ->
    let fixed_result = H.generate method_ fixed in
    assert (fixed_result.races = []);
    assert (fixed_result.status = (if method_ = Benchmark_traces.Symbolic then H.No_race else Complete_search));
    let result = match method_ with Symbolic -> H.generate method_ buggy | Concrete _ ->
      assert ((H.generate ~n:3 method_ buggy).races=[]);
      H.generate ~n:2 method_ buggy in
    assert (Z.gt (Option.get result.n) Z.zero && result.races <> []);
    let actions = List.concat_map (fun (r : H.race) ->
      ignore (check_pair missing r); r.forward @ r.reverse) result.races in
    assert (List.for_all (fun (e : H.event) ->
      not (List.mem (H.resolve missing e.location.origin.path).opcode ["memref.alloc";"memref.alloca"])) actions);
    assert (List.exists (fun (e : H.event) -> match e.action with
      | Wait k -> k.receiver = 0 && k.flag >= 0 && not k.cross | _ -> false) actions);
    assert (List.exists (fun (e : H.event) -> match e.action with Set (_::_) -> true | _ -> false) actions)
  ) methods

let nested () =
  let ast = H.read_ast "fixtures/hivm_nested_load.ast.json" in
  let int n = C.Literal (C.VInt (Z.of_int n)) in
  let tile n = C.Literal (C.VView [Input n,0]) in
  let loop var body = C.For (var,int 1,int 5,int 2,body,End) in
  let stream = C.{id=0;pipes=[0];params=[];
    body=loop 0 (loop 1 (Issue (0,0,[tile 0;tile 1],End)))} in
  let family : Bug_traces.Symbolic.family = {streams=[stream];parameter=[];
    access=(fun _ _ _ -> [Arg 0],[Arg 1]);scalar=(fun _ _ -> assert false);
    block_edge=(fun _ _ _ _ -> false)} in
  let launch : Race_benchmarks.launch = {family;default_n=0;capacity=1;op_name=(fun _ -> "load");
    unit_name="element";fixture=`Null} in
  let origin = H.{path=[3;0;0];opcode="hivm.hir.load";part=None} in
  let pairing = H.pair ~name:"nested-load" ~launch ~pipes:[0,MTE2]
    ~streams:[{stream_id=0;program=ast;bindings=[{core_site=[0;0];origin}]}] in
  List.iter (fun backend ->
    let result = H.generate (Concrete backend) pairing in
    assert (List.length result.races = 6);
    let coords = List.concat_map (fun (r : H.race) ->
      ignore (check_pair ast r);
      assert (r.first.location.origin = origin && r.second.location.origin = origin);
      [r.first.location.iterations;r.second.location.iterations]) result.races in
    assert (List.sort_uniq compare coords = [[0;0];[0;1];[1;0];[1;1]])) Bug_traces.[Search;Solve]

let boundary () =
  let ast = H.read_ast "fixtures/hivm_prefix_boundary.ast.json" in
  let view n = C.Literal (C.VView [Input n,0]) in
  let scalar = C.Issue (C.scalar_pipe,1,[view 1],End) in
  let body = C.Barrier (All,Issue (0,0,[view 0;view 1],scalar)) in
  let family : Bug_traces.Symbolic.family = {
    streams=[{id=0;pipes=[0;1];params=[];body}];parameter=[];
    access=(fun _ _ -> function 0 -> [Arg 0],[Arg 1] | 1 -> [],[Arg 0] | _ -> assert false);
    scalar=(fun _ _ -> assert false);block_edge=(fun _ _ _ _ -> false)} in
  let launch : Race_benchmarks.launch = {family;default_n=0;capacity=1;
    op_name=(function 0 -> "load" | 1 -> "scalarstore" | _ -> assert false);
    unit_name="element";fixture=`Assoc ["arguments",`List (List.map (fun (n,_) -> `String n) ast.arguments)]} in
  let binding core_site index =
    let path = [index] in
    H.{core_site;origin={path;opcode=(resolve ast path).opcode;part=None}} in
  let bindings = [binding [] 1;binding [0] 2;binding [0;0] 3] in
  let register pipes bindings = H.pair ~name:"prefix-boundary" ~launch ~pipes
    ~streams:[{stream_id=0;program=ast;bindings}] in
  let pipes = [0,H.MTE2;1,V] in
  reject (fun () -> register pipes (List.tl bindings));
  reject (fun () -> register pipes (binding [0] 2 :: bindings));
  reject (fun () -> register [0,H.V;1,MTE2] bindings);
  reject (fun () -> register pipes [binding [] 1;binding [0] 3;binding [0;0] 2]);
  List.iter (fun backend ->
    match (H.generate (Concrete backend) (register pipes bindings)).races with
    | [r] ->
        let left,right = check_pair ast r in
        assert (left > 0 && right > 0);
        assert (r.second.phase = Execute (Some S) && r.second.location.origin.opcode = "memref.store");
        (match (List.hd r.forward).phase with
         | Submit [a;b] -> assert (a.pipe = MTE2 && b.pipe = V && a.id <> b.id)
         | _ -> failwith "expected both barrier tasks")
    | _ -> failwith "expected a scalar/async race") Bug_traces.[Search;Solve]

let multi_stage () =
  let ast = H.read_ast "fixtures/hivm_mmad_parts.ast.json" in
  let tile n = C.Literal (C.VView (List.init 256 (fun i -> C.Input n,i))) in
  let flag = C.Literal (C.VEvent 0) in
  let stream id =
    let local = tile (3+id) in
    let compute = C.Issue (1,1,[local;tile 2],End) in
    let handoff = C.Sync (LocalSet,0,Data 1,flag,Sync (LocalWait,0,Data 1,flag,compute)) in
    let body = C.Issue (0,0,[tile 0;tile 1;local],handoff) in
    C.{id;pipes=[0;1];params=[];body} in
  let family : Bug_traces.Symbolic.family = {
    streams=[stream 0;stream 1];parameter=[];scalar=(fun _ _ -> assert false);
    access=(fun _ _ -> function 0 -> [Arg 0;Arg 1],[Arg 2] | 1 -> [Arg 0],[Arg 1] | _ -> assert false);
    block_edge=(fun _ _ _ _ -> false)} in
  let launch : Race_benchmarks.launch = {family;capacity=1;default_n=0;unit_name="element";
    op_name=(function 0 -> "mmadL1.load" | 1 -> "mmadL1" | _ -> assert false);
    fixture=`Assoc ["arguments",`List (List.map (fun (s,_) -> `String s) ast.arguments)]} in
  let parts = ["load";"signal_loaded";"wait_loaded";"compute"] in
  let bindings = List.mapi (fun i part ->
    H.{core_site=List.init i (fun _ -> 0);origin={path=[2];opcode="hivm.hir.mmadL1";part=Some part}}) parts in
  let streams bs = List.map (fun id -> H.{stream_id=id;program=ast;bindings=bs}) [0;1] in
  let register bs = H.pair ~name:"mmad-parts" ~launch ~pipes:[0,MTE1;1,M] ~streams:(streams bs) in
  reject (fun () -> register (List.map (fun (b : H.binding) ->
    {b with origin={b.origin with part=None}}) bindings));
  let pairing = register bindings in
  List.iter (fun backend ->
    match (H.generate (Concrete backend) pairing).races with
    | [r] ->
        ignore (check_pair ast r);
        let stages stream events = List.filter_map (fun (e : H.event) -> match e.phase with
          | Complete _ when e.location.stream=stream -> e.location.origin.part
          | _ -> None) events in
        List.iter (fun trace -> List.iter (fun id -> assert (stages id trace = parts)) [0;1])
          [r.forward;r.reverse]
    | _ -> failwith "expected competing writes to one output tile") Bug_traces.[Search;Solve]

let () = two_loads (); issue316 (); nested (); boundary (); multi_stage ()
