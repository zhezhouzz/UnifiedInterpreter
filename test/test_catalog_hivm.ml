open Unified_interpreter
module H = Hivm_trace
module A = H.Module_ast
module J = Yojson.Safe.Util

let root = "../benchmarks/hivm"
let catalog = Race_benchmarks.catalog "../benchmarks/litao"

let consume ast first second events =
  let pending = Hashtbl.create 16 in
  List.iter (fun (e : H.event) ->
    let l=e.location in
    let rec path body iterations = function
      | [i] -> assert (iterations=[]); List.nth body i
      | i::r::b::rest ->
          let op : A.operation = List.nth body i in
          let nested = (List.nth (List.nth op.regions r) b).body in
          if op.opcode="scf.for" || op.opcode="scf.while" && r=1 then
            (match iterations with k::ks when k>=0 -> path nested ks rest | _ -> failwith "missing ordinal")
          else path nested iterations rest
      | _ -> failwith "invalid AST location" in
    let op = path (A.entry ast l.entry).body l.iterations l.origin.path in
    assert (op.opcode=l.origin.opcode && op=A.resolve ast ~entry:l.entry l.origin.path);
    if op.opcode="func.call" then ignore (A.entry ast (List.assoc "callee" op.properties));
    let identity=l,e.action in
    match e.phase with
    | Submit tasks -> List.iter (fun (t:H.task) ->
        assert (not (Hashtbl.mem pending t.id)); Hashtbl.add pending t.id (identity,t.pipe)) tasks
    | Complete t -> assert (Hashtbl.find pending t.id=(identity,t.pipe)); Hashtbl.remove pending t.id
    | Async_submit _ | Async_complete _ -> failwith "unexpected HFusion task in HIVM trace"
    | Execute _ -> ()) events;
  assert (List.filter (fun e -> e=first || e=second) events=[first;second]);
  assert (List.hd (List.rev events)=second)

let () =
  let count=ref 0 and symbolic=ref 0 and races=ref 0 and racy=ref 0 in
  let old=["fixture/hivm-two-loads";"issue316/ordered";"issue316/missing-ready";"vectorlayout/ok";"vectorlayout/fail"] in
  List.iter (fun (name,load) ->
    let file=H.ast_file ~root name in
    assert (Sys.file_exists file);
    if not (List.mem name old) then (
      incr count;
      let launch = match load () with Race_benchmarks.Core l -> l | _ -> assert false in
      let ast=A.read file in
      let pairing=H.registered_module ~root catalog name ast in
      let check (report:H.report) =
        assert (J.member "ast_digest" report.inputs=`String ast.digest);
        if report.status=Complete_search || report.status=Race_found then (
          let bindings=J.member "bindings" report.inputs |> J.to_list in
          List.iter2 (fun (id,entry) b ->
            assert (J.member "stream" b=`Int id);
            assert (List.length (J.member "arguments" b |> J.to_list)=List.length (A.entry ast entry).arguments)
          ) report.streams bindings);
        List.iter (fun (r:H.race) -> consume ast r.first r.second r.forward; consume ast r.second r.first r.reverse)
          report.races;
        List.map (fun (r:H.race) -> r.first,r.second) report.races |> List.sort compare in
      let bfs=H.generate (Concrete Search) pairing and smt=H.generate (Concrete Solve) pairing in
      assert (check bfs=check smt);
      let raw=Benchmark_traces.generate catalog (Concrete Search) name in
      assert (List.length bfs.races=List.length (J.member "races" raw |> J.to_list));
      races:= !races+List.length bfs.races;
      if bfs.races<>[] then incr racy;
      if launch.family.parameter<>[] then (
        incr symbolic;
        let report=H.generate Symbolic pairing in
        assert (report.status=Race_found || report.status=No_race);
        let targets=check report in
        if report.status=Race_found then (
          assert (List.length targets=1);
          let specific=H.generate ~n:(Z.to_int (Option.get report.n)) (Concrete Search) pairing in
          assert (List.mem (List.hd targets) (check specific)))))) catalog;
  assert (!count=73);
  let name="regression/flag-expression" in
  let flags=H.registered_file ~root catalog name (H.ast_file ~root name) in
  let enabled=H.generate ~n:19 (Concrete Solve) flags in
  let args=J.member "bindings" enabled.inputs |> J.to_list |> List.hd |> J.member "arguments" |> J.to_list in
  assert (List.nth args 1=`Int 19 && enabled.races<>[]);
  assert ((H.generate ~n:18 (Concrete Search) flags).races=[]);
  let wrong=A.read (H.ast_file ~root "litao/wrong-event/fixed") in
  (match H.registered_module ~root catalog "litao/wrong-event/buggy" wrong with
   | exception Invalid_argument _ -> () | _ -> failwith "accepted the wrong HIVM variant");
  let shared="fixture/shared-allocation" in
  let ast=A.read (H.ast_file ~root shared) in
  let pairing=H.registered_module ~root catalog shared ast in
  List.iter (fun backend ->
  let report=H.generate (Concrete backend) pairing in
  assert (report.races<>[]);
  let slots=List.map (fun b -> List.nth (J.member "arguments" b |> J.to_list) 1)
      (J.member "bindings" report.inputs |> J.to_list) in
  assert (slots=[`Assoc ["descriptor_slot",`String "allocation:0"];`Assoc ["descriptor_slot",`String "allocation:0"]]);
  List.iter (fun (r:H.race) -> List.iter (fun events ->
    let slot_written = ref false in
    List.iter (fun (e:H.event) ->
      let loc=e.location in
      if loc.stream=0 then (
        assert (not !slot_written && e.action=Compute && e.phase=Execute (Some S));
        let parent = match loc.calls with [frame] -> frame | _ -> failwith "expected one call" in
        assert (parent.caller=List.assoc 0 report.streams && parent.call_iterations=[]);
        let op=A.resolve ast ~entry:parent.caller parent.call_path in
        assert (op.opcode="func.call" && List.assoc "callee" op.properties=loc.entry);
        let store=A.resolve ast ~entry:loc.entry loc.origin.path in
        let block=A.entry ast loc.entry in
        let alloc=List.find (fun (op:A.operation) -> op.opcode="memref.alloc") block.body in
        assert (store.opcode="memref.store" && List.hd store.operands=fst (List.hd alloc.results) &&
                List.nth store.operands 1=fst (List.hd block.arguments));
        slot_written := true)
      else match e.phase with Complete _ -> assert !slot_written | _ -> ()) events;
    assert !slot_written) [r.forward;r.reverse]) report.races) [Search;Solve];
  Printf.printf "HIVM catalog: %d programs, %d racy default inputs, %d pairs per backend, %d symbolic inputs\n"
    !count !racy !races !symbolic
