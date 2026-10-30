open Attention_runtime

let read = Attention.read_file
let () =
  List.iter (fun basename ->
    let file = "../artifacts/flash_attention/ir/" ^ basename in
    let p = Parser.parse ~file (read file) in
    Validate.program p;
    assert (p.name = "@_attn_fwd");
    let loop = List.find (fun op -> op.Parser.opcode = "scf.for") p.body in
    assert (List.length loop.region > 30);
    List.iter (fun op ->
      assert (op.Parser.span.file = file);
      assert (op.span.start.line > loop.span.start.line)) loop.region;
    if basename = "hfusion_level.mlir" then begin
      let reductions = List.filter (fun op -> op.Parser.opcode = "linalg.reduce")
          loop.region in
      assert (List.length reductions = 2);
      List.iter (fun op ->
        assert (List.length op.Parser.region_arguments = 2);
        assert (List.length op.region = 2)) reductions
    end
  ) ["hfusion_level.mlir"; "attention_hivm_compute.mlir"];
  (match Parser.parse ~file:"bad.mlir" "func.func @f() {\n %x = tensor.empty( \n}" with
   | _ -> failwith "malformed MLIR accepted"
   | exception Failure message -> assert (String.length message > 0));
  let file = "../artifacts/flash_attention/ir/attention_hivm_compute.mlir" in
  let p = Parser.parse ~file (read file) in
  let new_hfusion_file = "../artifacts/kernel_IR/attention/hfusion.mlir" in
  let new_hivm_file = "../artifacts/kernel_IR/attention/hivm.mlir" in
  let new_hfusion = Parser.parse ~file:new_hfusion_file (read new_hfusion_file) in
  let new_hivm = Parser.parse ~file:new_hivm_file (read new_hivm_file) in
  let old_abi = Validate.attention_abi ~stage:"hivm" p in
  let hfusion_abi = Validate.attention_abi ~stage:"hfusion" new_hfusion in
  let hivm_abi = Validate.attention_abi ~stage:"hivm" new_hivm in
  assert (old_abi.pid_x = "%arg13" && old_abi.lse_type = Runner.E.Float32Type);
  assert (hfusion_abi.ffts = None && hfusion_abi.pid_x = "%arg12");
  assert (hivm_abi.ffts = Some "%arg0" && hivm_abi.pid_x = "%arg13");
  assert (hfusion_abi.lse_type = Runner.E.Float16Type && hfusion_abi.o_type = Runner.E.Float32Type);
  let names = List.mapi (fun i (name,_) -> name,"%renamed" ^ string_of_int i)
      new_hfusion.arguments in
  let rename name = Option.value ~default:name (List.assoc_opt name names) in
  let rec rename_op (op : Parser.operation) = {op with
    operands=List.map rename op.operands; inputs=List.map rename op.inputs;
    outputs=List.map rename op.outputs; region=List.map rename_op op.region} in
  let renamed = {new_hfusion with arguments=List.map (fun (name,ty) ->
    rename name,ty) new_hfusion.arguments; body=List.map rename_op new_hfusion.body} in
  let renamed_abi = Validate.attention_abi ~stage:"hfusion" renamed in
  assert (renamed_abi.pid_x = "%renamed12");
  let fixture_file = "fixtures/attention_hivm_vadd.mlir" in
  let fixture = Parser.parse ~file:fixture_file (read fixture_file) in
  Validate.program fixture;
  let span = (List.hd p.body).Parser.span in
  let rec normalize fixture (op : Parser.operation) =
    {op with span; region=List.map (normalize fixture) op.region;
      opcode=(if fixture && op.result = Some "%37" then "hivm.hir.vdiv" else op.opcode)} in
  assert (p.arguments = fixture.arguments);
  assert (List.map (normalize false) p.body = List.map (normalize true) fixture.body);
  let first = List.hd p.body in
  let reject p =
    match Validate.program p with
    | () -> failwith "invalid program accepted"
    | exception Source.Error _ -> ()
    | exception Invalid_argument _ -> () in
  reject {new_hfusion with arguments=List.tl new_hfusion.arguments};
  reject {new_hfusion with arguments=new_hfusion.arguments @ ["%extra",Parser.ScalarType (Parser.scalar_type "i32")]};
  let first_new = List.hd new_hfusion.body in
  reject {new_hfusion with body={first_new with operands=[hfusion_abi.sync_lock]} :: List.tl new_hfusion.body};
  reject {new_hfusion with arguments=List.mapi (fun i (name,ty) ->
    if i = 6 then name,Parser.ShapedType ("memref",[-1],Runner.E.Float16Type) else name,ty)
    new_hfusion.arguments};
  reject {p with body = {first with opcode="unknown.operation"} :: List.tl p.body};
  reject {p with body = first :: p.body};
  reject {p with body = {first with opcode="arith.addi"; operands=["%missing"]} :: List.tl p.body};
  reject {p with body = {first with attributes=("unknown",`Int 1)::first.attributes} :: List.tl p.body};
  reject {p with arguments = List.map (fun (name,ty) ->
    if name = "%arg9" then name,Parser.ScalarType (Parser.scalar_type "i64") else name,ty) p.arguments};
  let loop = List.find (fun op -> op.Parser.opcode = "scf.for") p.body in
  let broadcast = List.find (fun op -> op.Parser.opcode = "hivm.hir.vbrc") loop.region in
  let changed = {broadcast with attributes=["broadcast_dims",`List [`Int 0]]} in
  let loop = {loop with region=List.map (fun op -> if op == broadcast then changed else op) loop.region} in
  reject {p with body=List.map (fun op -> if op.Parser.opcode="scf.for" then loop else op) p.body};
  (match Attention.run ~max_steps:1 ~file (Attention.default_input ()) with
   | _ -> failwith "budget ignored"
   | exception Source.Error (_,message) ->
       assert (String.ends_with ~suffix:"budget exhausted" message));
  let body = List.map (fun (op : Parser.operation) ->
    if op.opcode = "scf.for" then {op with region=[List.hd op.region]} else op) p.body in
  let found_loop = ref false in
  let trace = function
    | `Assoc fields when List.assoc_opt "opcode" fields = Some (`String "arith.divsi") ->
        assert (List.assoc_opt "loops" fields = Some (`Assoc ["%arg16",`Int 0]));
        assert (List.assoc_opt "entry" fields = Some (`String "sem_integer_binary"));
        found_loop := true
    | _ -> () in
  let ctx = {Runner.state=ref {Handlers.memory=Runner.E.empty_memory;marker=73};
    steps=0;max_steps=10000;current=None;pid=0;calls=0;loops=[];trace} in
  Runner.with_handlers ctx (fun () ->
    ignore (Runner.execute_block ctx
      ["%arg13",Runner.Int (Runner.scalar_type "i32",Runner.E.Z0)] body));
  assert (!found_loop);
  print_endline "xDSL frontend: archived files, SSA, attributes, shapes, positions and loop trace passed"
