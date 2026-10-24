open Attention_runtime
module E = Runner.E

let () =
  let file = "fixtures/mixed.mlir" in
  let program = Parser.parse ~file (Attention.read_file file) in
  Validate.program ~stage:"mixed" program;
  List.iter (fun stage ->
    match Validate.program ~stage program with
    | () -> failwith "mixed program accepted by single-stage validation"
    | exception Source.Error _ -> ()) ["hfusion";"hivm"];
  let rec check ops = List.iter (fun (op : Parser.operation) ->
    assert (op.stage = Stage.of_opcode op.opcode);
    check op.region) ops in
  check program.body;
  let loop = List.find (fun op -> op.Parser.opcode = "scf.for") program.body in
  let hf = List.find (fun op -> op.Parser.result = Some "%filled") loop.region in
  let hv = List.find (fun op -> op.Parser.result = Some "%added") loop.region in
  assert (hf.stage = Stage.HFusion && hv.stage = Stage.HIVM);
  let bad = {hf with stage=Stage.HIVM} in
  (match Validate.program {program with body=[bad]} with
  | () -> failwith "incorrect stage accepted"
  | exception Source.Error (_,message) -> assert (message = "operation stage mismatch"));
  let events = ref [] in
  let ctx = {Runner.state=ref {Handlers.memory=E.empty_memory;marker=73};
    steps=0;max_steps=10000;current=None;pid=0;calls=0;loops=[];
    trace=(fun event -> events := event :: !events)} in
  let env,_ = Runner.with_handlers ctx (fun () ->
    Runner.execute_block ctx [] program.body) in
  (match List.assoc "%result" env with
  | Runner.Tensor result -> assert (E.elements1 result = E.Ok [26.;26.])
  | _ -> assert false);
  assert ((!(ctx.state)).marker = 73);
  List.iter (fun (opcode,stage,entry) ->
    assert (List.exists (function `Assoc fields ->
      List.assoc_opt "opcode" fields = Some (`String opcode) &&
      List.assoc_opt "ir_stage" fields = Some (`String stage) &&
      List.assoc_opt "entry" fields = Some (`String entry)
      | _ -> false) !events))
    ["linalg.fill","hfusion","sem_linalg_fill";
     "hivm.hir.vadd","hivm","HIVM.evaluate";
     "arith.addf","common","eval_scalar_operation";
     "bufferization.materialize_in_destination","common","write_result";
     "linalg.elemwise_binary","hfusion","materialize"];
  let value = E.EmptyTensor ([1],E.Float32Type) in
  List.iter (fun (op,f) ->
    match Runner.with_handlers ctx (fun () -> Runner.with_operation_handlers ctx op f) with
    | _ -> failwith "wrong-stage computation handler was available"
    | exception Effect.Unhandled _ -> ())
    [hf,(fun () -> Effect.perform (Handlers.HIVM (E.UnaryRequest (E.VExp,value,value))));
     hv,(fun () -> Effect.perform (Handlers.HFusion (Handlers.Fill (E.Float32Type,0.,value))))];
  let before = ctx.calls in
  (match Runner.with_handlers ctx (fun () -> Runner.execute_block ctx [] [bad]) with
  | _ -> failwith "incorrect stage executed"
  | exception Source.Error (_,message) -> assert (message = "operation stage mismatch"));
  assert (ctx.calls = before);
  print_endline "mixed execution: stage routing, nested reduction, SSA and shared memory passed"
