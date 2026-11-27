open Stdlib
open Unified_interpreter
module H = Hivm_trace
module A = H.Module_ast

let catalog = Race_benchmarks.catalog "../benchmark"
let file v = "../benchmarks/hivm/vectorlayout_" ^ v ^ ".ast.json"
let reject f = match f () with exception Invalid_argument _ -> () | _ -> assert false

let consume ast (report : H.report) (race : H.race) =
  let parts = ref [] and calls = ref [] and waits = ref [] in
  let run first second events =
    let pending = Hashtbl.create 64 and flags = Hashtbl.create 32 in
    let position (e : H.event) =
      let loc = e.location in
      assert (List.assoc loc.stream report.streams = loc.entry);
      let op = A.resolve ast ~entry:loc.entry loc.origin.path in
      assert (op.opcode = loc.origin.opcode);
      if op.opcode="func.call" then (
        let callee = List.assoc "callee" op.properties in
        let body = A.entry ast callee in
        assert (List.length op.operands = List.length body.arguments && body.body<>[]);
        calls := callee :: !calls);
      Option.iter (fun part ->
        assert (op.opcode="hivm.hir.mmadL1" && List.length op.operands=14);
        parts := part :: !parts) loc.origin.part in
    let apply_action (e : H.event) =
      let stream = e.location.stream in
      let consume_flag sender key =
        assert (Hashtbl.mem flags (sender,key)); Hashtbl.remove flags (sender,key) in
      match e.action with
      | Set ks -> List.iter (fun k ->
          assert (not (Hashtbl.mem flags (stream,k))); Hashtbl.add flags (stream,k) ()) ks
      | Wait k -> assert (not k.cross && k.receiver=stream); consume_flag stream k
      | Wait_all (senders,k) -> assert (k.cross && stream=k.receiver);
          waits := senders :: !waits; List.iter (fun s -> consume_flag s k) senders
      | _ -> () in
    List.iter (fun (e : H.event) ->
      position e;
      match e.phase with
      | Submit tasks -> List.iter (fun (t : H.task) ->
          assert (not (Hashtbl.mem pending t.id));
          Hashtbl.add pending t.id (e.location,e.action,t.pipe)) tasks
      | Complete t -> assert (Hashtbl.find pending t.id = (e.location,e.action,t.pipe));
          apply_action e; Hashtbl.remove pending t.id
      | Async_submit _ | Async_complete _ -> failwith "unexpected HFusion task in HIVM trace"
      | Execute _ -> apply_action e) events;
    assert (List.filter (fun e -> e=first || e=second) events = [first;second]);
    assert (List.hd (List.rev events)=second) in
  run race.first race.second race.forward; run race.second race.first race.reverse;
  !parts,!calls,!waits

let test variant pairs =
  let ast = A.read (file variant) and name = "vectorlayout/" ^ variant in
  let pairing = H.registered_module catalog name ast in
  let other = if variant="ok" then "fail" else "ok" in
  reject (fun () -> H.registered_file catalog name (file other));
  List.iter (fun suffix ->
    let entry = A.entry ast ("@_prefill_bnsd_score_kernel_mix_" ^ suffix) in
    assert (List.length entry.arguments=28);
    let rec referenced (b : A.block) = List.concat_map (fun (o : A.operation) ->
      o.operands @ List.concat_map (List.concat_map referenced) o.regions) b.body in
    let actual = referenced entry in
    List.iter (fun n -> assert (not (List.mem (fst (List.nth entry.arguments n)) actual))) [0;1;10;11])
    ["aic";"aiv"];
  let fused = "@_prefill_bnsd_score_kernel_mix_aiv_fused_5_outlined_merged_vf_0" in
  let rec stores (block : A.block) = List.concat_map (fun (o : A.operation) ->
    if o.opcode="ave.hir.masked_store" then [List.assoc "functionType" o.attributes]
    else List.concat_map (List.concat_map stores) o.regions) block.body in
  let modes = stores (A.entry ast fused) in
  assert (List.mem "#ave.func_dist_type<pk>" modes);
  assert (List.mem "#ave.func_dist_type<pk4>" modes = (variant="fail"));
  let concrete backend =
    let r = H.generate ~n:160 (Benchmark_traces.Concrete backend) pairing in
    assert (r.n=Some (Z.of_int 160) && List.length r.races=pairs && List.length r.streams=3);
    let parts,calls,waits = List.fold_left (fun (ps,cs,ws) race ->
      let p,c,w = consume ast r race in List.rev_append p ps,List.rev_append c cs,List.rev_append w ws)
      ([],[],[]) r.races in
    assert (List.mem fused calls && List.mem [1;2] waits && List.mem [0] waits);
    assert (List.sort_uniq compare parts = List.sort compare ["wait_input";"wait_matrix_buffer";
      "load";"release_input";"signal_loaded";"wait_loaded";"compute";"release_matrix_buffer"]);
    List.map (fun (race : H.race) -> race.first,race.second) r.races in
  assert (concrete Search = concrete Solve);
  let symbolic = H.generate ~kv_heads:2 Symbolic pairing in
  assert (symbolic.status=Race_found && List.length symbolic.streams=6);
  let field k = Yojson.Safe.Util.member k symbolic.inputs in
  let input = Vectorlayout_input.make_hivm (Device_trace.parse_config (field "config")) in
  assert (List.length input.bindings=28 && Device_trace.bindings input=field "bindings");
  assert (field "ast_format"=`String "hivm-module-1");
  let n = Z.to_int (Option.get symbolic.n) in
  let known = H.generate ~kv_heads:2 ~n (Concrete Search) pairing in
  assert (List.exists (fun (p : H.race) -> p.first.location.stream>=3 &&
    p.first.location.iterations=[0]) known.races);
  (match symbolic.races with
   | [r] -> ignore (consume ast symbolic r);
       assert (List.exists (fun (p : H.race) -> p.first=r.first && p.second=r.second) known.races)
   | _ -> assert false);
  assert ((H.generate ~n:0 (Concrete Search) pairing).races=[])

let () = test "ok" 33; test "fail" 29
