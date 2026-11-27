open Stdlib
open Unified_interpreter
module C = Core_lang
module H = Hivm_trace
module J = Yojson.Safe.Util

let parse ?syntax file =
  H.Module_ast.parse ?syntax ~file (In_channel.with_open_bin file In_channel.input_all)

let parse_inline name source = H.Module_ast.parse ~file:name source
let launch json = Yojson.Safe.from_string json
let field key json = J.member key json
let races report = J.to_list (field "races" report)

let operation (lowered : H.Mlir.t) name =
  let stream = List.hd lowered.program.streams in
  let plan = C.stream_plan lowered.program stream in
  List.find_map (function
    | _,C.Immediate (Operation (id,footprint)) | _,C.Submit (_,Operation (id,footprint))
      when lowered.operation_names.(id)=name -> Some footprint
    | _ -> None) plan.actions |> Option.get

let external_bytes id from length = List.init length (fun i -> C.Input id,from+i)

let examples () =
  List.iter (fun (name,hf,hivm,reads,writes) ->
    List.iter (fun (dialect,opcode) ->
      let ast = parse (Printf.sprintf "../examples/kernels/%s_%s.mlir" name dialect) in
      let lowered = H.Mlir.lower ast in
      let materialize = operation lowered "bufferization.materialize_in_destination" in
      let compute = operation lowered opcode in
      assert (List.length materialize.reads = writes && List.length materialize.writes = writes);
      assert (List.length compute.reads = reads && compute.writes = materialize.reads);
      let report = H.analyze_mlir ~backend:Search (H.lower_mlir ast) in
      assert (races report=[])
    ) ["hfusion",hf;"hivm",hivm]
  ) ["vector_add","linalg.elemwise_binary","hivm.hir.vadd",64,32];
  let hf = parse "../examples/kernels/row_sum_hfusion.mlir" |> H.Mlir.lower in
  let hv = parse "../examples/kernels/row_sum_hivm.mlir" |> H.Mlir.lower in
  let reduction = operation hf "linalg.reduce" and vreduce = operation hv "hivm.hir.vreduce" in
  assert (List.length reduction.reads=60 && List.length vreduce.reads=48);
  assert (List.length reduction.writes=12 && List.length vreduce.writes=12)

let check_locations ast report =
  List.iter (fun race ->
    let check order last =
      let events = J.to_list (field order race) in
      if field "trace_extent" report<>`String "program_end" then
        assert (List.hd (List.rev events)=field last race);
      List.iter (fun event ->
        let entry = J.to_string (field "entry" event) in
        let stream=List.nth (J.to_list (field "streams" report)) (J.to_int (field "stream" event)) in
        let calls=match field "calls" event with `Null -> [] | xs -> J.to_list xs in
        let leaf=List.fold_left (fun entry frame ->
          assert (field "entry" frame=`String entry);
          let path=List.map J.to_int (J.to_list (field "path" frame)) in
          let op=H.Module_ast.resolve ast ~entry path in
          assert (op.opcode="func.call"); List.assoc "callee" op.properties)
          (J.to_string (field "entry" stream)) calls in
        assert (entry=leaf);
        let path = List.map J.to_int (J.to_list (field "path" event)) in
        let op = H.Module_ast.resolve ast ~entry path in
        assert (`String op.opcode=field "opcode" event)
      ) events in
    check "forward" "second";
    check "reverse" "first"
  ) (races report)

let issue316 () =
  List.iter (fun (stage,file,count) ->
    let configuration = `Assoc ["stage",`String stage;"arguments",`List [
        `Assoc ["shape",`List [`Int 3072]];`Null;`Int 3]] in
    let ast = parse file in
    let lowered = H.lower_mlir ~configuration ast in
    List.iter (fun backend ->
      let core = H.analyze_mlir ~backend lowered in
      assert (field "status" core=`String "complete");
      assert (List.length (races core)=count && H.replay_mlir lowered core=2*count);
      let hivm = H.analyze_mlir ~backend ~hivm:true lowered in
      if backend=Search && stage="hivm" && Filename.basename file="issue316_missing_ready_hivm.mlir" then (
        assert (field "status" hivm=`String "deadlock");
        let terminal=field "trace" hivm in
        let events=J.to_list (field "events" terminal) |> List.map Dispatch.decode in
        assert (events<>[]);
        let trace=H.Execution.Delivery.make events (Terminal "deadlock") `Null in
        let result=H.Execution.execute_trace ~stage:H.Source.HIVM ~launch:configuration ast trace in
        assert (match result.status with Blocked (_::_)->true | _->false));
      let expected=if backend=Search then min 1 count else count in
      assert (List.length (races hivm)=expected);
      check_locations ast hivm
    ) Bug_traces.[Search;Solve]
  ) ["hivm","../examples/kernels/issue316_vexp_hivm.mlir",0;
     "hivm","../examples/kernels/issue316_missing_ready_hivm.mlir",0;
     "hfusion","../benchmarks/ir-pairs/issue316/ordered/hfusion.mlir",0;
     "hfusion","../benchmarks/ir-pairs/issue316/missing-ready/hfusion.mlir",9]

let issue316_barrier_scope () =
  let ast = parse "../benchmarks/ir-pairs/issue316/ordered/hfusion.mlir" in
  let configuration = launch {|{"stage":"hfusion","streams":[
    {"entry":"issue316_vexp","block":0,"arguments":[{"shape":[1024]},{"storage":"shared"},1]},
    {"entry":"issue316_vexp","block":1,"arguments":[{"shape":[1024]},{"storage":"shared"},1]}
  ]}|} in
  let lowered = H.lower_mlir ~allow_prefix:false ~configuration ast in
  List.iter (fun backend ->
    let core = H.analyze_mlir ~backend lowered in
    assert (H.replay_mlir lowered core=2);
    let source = H.project_mlir lowered core in
    check_locations ast source;
    match races source with
    | [race] ->
        List.iter (fun order ->
          let steps = J.to_list (field order race) in
          List.iter (fun stream ->
            let events = List.filter_map (fun e ->
              if field "stream" e=`Int stream then Some (J.to_string (field "opcode" e),
                J.to_string (field "phase" e)) else None) steps in
            assert (events=["linalg.copy","submit";"linalg.copy","complete";
              "hfusion.barrier","execute";"linalg.elemwise_unary","submit";
              "linalg.elemwise_unary","complete"])) [0;1]) ["forward";"reverse"]
    | _ -> failwith "expected one race between the two cores writing the shared output"
  ) Bug_traces.[Search;Solve]

let nested_async_calls () =
  let ast=parse_inline "nested.mlir" {|module {
    func.func @inner(%a: memref<1xi32>, %b: memref<1xi32>) {
      memref.copy %a, %b : memref<1xi32> to memref<1xi32>
      return
    }
    func.func @outer(%a: memref<1xi32>, %b: memref<1xi32>) {
      func.call @inner(%a, %b) : (memref<1xi32>, memref<1xi32>) -> ()
      return
    }
    func.func @main(%a: memref<1xi32>, %b: memref<1xi32>) {
      %zero = arith.constant 0 : index
      %one = arith.constant 1 : index
      %two = arith.constant 2 : index
      scf.for %i = %zero to %two step %one {
        func.call @outer(%a, %b) : (memref<1xi32>, memref<1xi32>) -> ()
        func.call @outer(%a, %b) : (memref<1xi32>, memref<1xi32>) -> ()
      }
      return
    }
  }|} in
  let configuration=launch {|{"stage":"hfusion","arguments":[null,null]}|} in
  let lowered=H.lower_mlir ~entry:"main" ~configuration ast in
  List.iter (fun backend ->
    let source=H.analyze_mlir ~hivm:true ~backend lowered in
    let core=H.analyze_mlir ~backend lowered in
    let projected=H.project_mlir lowered core in
    (match backend with Solve->assert (source=projected)
     | Search->assert (field "analysis" source=`String "loop-smt" && field "prefix_rounds" source=`Int 1));
    let method_=match backend with Bug_traces.Search -> Precedence.Bfs | Solve -> Smt in
    let from_ast=Ir_scheduler.generate_mlir ~entry:"main" ~configuration HFusion method_ ast in
    assert (source=from_ast);
    assert (List.length (races source)=(if backend=Search then 1 else 6) && H.replay_mlir lowered core=12);
    check_locations ast source;
    let identity event =
      assert (field "entry" event=`String "@inner" && field "iterations" event=`List []);
      assert (field "phase" event=`String "complete");
      let task=List.hd (J.to_list (field "tasks" event)) in
      assert (field "pipe" task=`String "HFUSION_ASYNC");
      match J.to_list (field "calls" event) with
      | [caller;inner] -> assert (field "iterations" inner=`List []);
          field "path" caller,field "iterations" caller
      | _ -> failwith "expected both source calls" in
    let ids=List.concat_map (fun race -> List.map (fun k -> identity (field k race)) ["first";"second"]) (races source) in
    assert (List.length (List.sort_uniq compare ids)=(if backend=Search then 2 else 4))
  ) Bug_traces.[Search;Solve]

let reject_foreign_trace () =
  let create operand=parse_inline "copy.mlir" (Printf.sprintf {|func.func @copy(%s) {
    memref.copy %%a, %%b : memref<1xi32> to memref<1xi32>
    memref.copy %%a, %%b : memref<1xi32> to memref<1xi32>
    return
  }|} operand) |> H.lower_mlir in
  let report=H.analyze_mlir ~backend:Search (create "%a: memref<1xi32>, %b: memref<1xi32>") in
  assert (List.length (races report)=1);
  let different=create "%b: memref<1xi32>, %a: memref<1xi32>" in
  match H.project_mlir different report with
  | _ -> failwith "accepted a report for different source operands"
  | exception Invalid_argument _ -> ()

let carried_views () =
  let ast = parse_inline "carried.mlir" {|module {
  func.func @other() { return }
  func.func @carried(%src: memref<5xi32>, %dst: memref<1xi32>, %count: index) {
    %zero = arith.constant 0 : index
    %one = arith.constant 1 : index
    %false = arith.constant false
    %true = arith.constant true
    %results:2 = scf.for %i = %zero to %count step %one iter_args(%offset = %zero, %odd = %false) -> (index, i1) {
      %next = arith.addi %offset, %one : index
      %toggle = arith.xori %odd, %true : i1
      scf.yield %next, %toggle : index, i1
    }
    %at = scf.if %results#1 -> (index) {
      %plus = arith.addi %results#0, %one : index
      scf.yield %plus : index
    } else {
      scf.yield %results#0 : index
    }
    %view = memref.subview %src[%at] [1] [1] : memref<5xi32> to memref<1xi32, strided<[1], offset: ?>>
    memref.copy %view, %dst : memref<1xi32, strided<[1], offset: ?>> to memref<1xi32>
    return
  }
}|} in
  assert (List.length ast.functions=2);
  List.iter (fun (n,offset) ->
    let configuration = `Assoc ["arguments",`List [`Null;`Null;`Int n]] in
    let lowered = H.Mlir.lower ~entry:"carried" ~configuration ast in
    let copy = operation lowered "memref.copy" in
    assert (copy.reads=external_bytes 0 (4*offset) 4);
    assert (copy.writes=external_bytes 1 0 4)
  ) [0,0;1,2;2,2;3,4]

let dynamic_slices () =
  let lowered = parse "fixtures/dynamic_slices.mlir" |> H.Mlir.lower in
  let extract = operation lowered "tensor.extract_slice" in
  let materialize = operation lowered "bufferization.materialize_in_destination" in
  assert (extract.reads = external_bytes 0 12 4 @ external_bytes 0 20 4);
  assert (extract.writes=materialize.reads && materialize.writes=external_bytes 1 0 8)

let indexed () =
  let ast = parse_inline "indexed.mlir" {|func.func @gather_scatter(%src: memref<4xf32>, %offsets: memref<2xi64>, %mask: memref<2xi8>, %other: memref<2xf32>, %gathered: memref<2xf32>, %values: memref<2xf32>) {
  hivm.hir.indirect_load ins(%src : memref<4xf32>, %offsets : memref<2xi64>, %mask : memref<2xi8>, %other : memref<2xf32>) outs(%gathered : memref<2xf32>)
  hivm.hir.indirect_store ins(%values : memref<2xf32>, %offsets : memref<2xi64>, %mask : memref<2xi8>) outs(%src : memref<4xf32>)
  return
}|} in
  List.iter (fun (enabled,count) ->
    let configuration = launch (Printf.sprintf
      {|{"arguments":[{"storage":"source","initial":[3,5,7,9]},{"initial":[0,2]},{"initial":[0,%d]},{"initial":[10,20]},null,{"initial":[1,2]}]}|}
      enabled) in
    let lowered = H.lower_mlir ~configuration ast in
    List.iter (fun backend ->
      let report = H.analyze_mlir ~backend lowered in
      assert (field "address_unit" report=`String "bit");
      assert (List.length (races report)=count && H.replay_mlir lowered report=2*count);
      List.iter (fun r -> assert (field "conflicts" r=launch {|[["source",64,96]]|})) (races report);
      let hivm = H.analyze_mlir ~backend ~hivm:true lowered in
      assert (List.length (races hivm)=count);
      check_locations ast hivm
    ) Bug_traces.[Search;Solve]
  ) [1,1;0,0]

let masked_vector () =
  let ast = parse_inline "masked.mlir" {|module {
  func.func @vector_writer(%dst: memref<4xi32>, %mask: vector<4xi1>, %values: vector<4xi32>) {
    %zero = arith.constant 0 : index
    vector.maskedstore %dst[%zero], %mask, %values : memref<4xi32>, vector<4xi1>, vector<4xi32>
    return
  }
  func.func @scalar_writer(%dst: memref<4xi32>) {
    %one = arith.constant 1 : index
    %value = arith.constant 10 : i32
    memref.store %value, %dst[%one] : memref<4xi32>
    return
  }
}|} in
  List.iter (fun (enabled,count) ->
    let configuration = launch (Printf.sprintf {|{"streams":[
      {"entry":"vector_writer","block":0,"arguments":[{"storage":"target"},{"initial":[true,%b,false,false]},{"initial":[6,7,8,9]}]},
      {"entry":"scalar_writer","block":1,"arguments":[{"storage":"target"}]}
    ]}|} enabled) in
    let lowered = H.lower_mlir ~configuration ast in
    let report = H.analyze_mlir ~backend:Search lowered in
    assert (List.length (races report)=count && H.replay_mlir lowered report=2*count);
    List.iter (fun r -> assert (field "conflicts" r=launch {|[["target",32,64]]|})) (races report);
    check_locations ast (H.analyze_mlir ~backend:Search ~hivm:true lowered)
  ) [true,1;false,0]

let scheduled_mask () =
  let ast = parse_inline "scheduled-mask.mlir" {|func.func @gather(%src: memref<2xf32>, %offsets: memref<1xi64>, %mask: memref<1xi8>, %other: memref<1xf32>, %out: memref<1xf32>, %next_mask: memref<1xi8>) {
  hivm.hir.load ins(%next_mask : memref<1xi8>) outs(%mask : memref<1xi8>)
  hivm.hir.indirect_load ins(%src : memref<2xf32>, %offsets : memref<1xi64>, %mask : memref<1xi8>, %other : memref<1xf32>) outs(%out : memref<1xf32>)
  return
}|} in
  let configuration = launch {|{"arguments":[
    {"initial":[11,22]},{"initial":[1]},{"storage":"mask","initial":[0]},
    {"initial":[19]},{"storage":"output"},{"initial":[1]}
  ]}|} in
  let lowered = H.lower_mlir ~configuration ast in
  let device = match lowered with Device_mlir program -> program | _ -> assert false in
  let report = H.analyze_mlir ~backend:Solve lowered in
  match races report with
  | [race] ->
      assert (field "conflicts" race=launch {|[["mask",0,8]]|});
      let events = Array.of_list (J.to_list (field "events" report)) in
      let execute order =
        let prefix = List.map (fun id -> field "choice" events.(J.to_int id) |> Device_trace.parse_choice)
            (J.to_list (field order race)) in
        let state = Device_run.run ~prefix ~iteration_ordinals:true device.program device.memory device.bindings in
        let raw = Bytes.get_int32_le (Hashtbl.find state.memory (Device_value.Allocation "output")) 0 in
        Int32.float_of_bits raw in
      assert (List.sort Float.compare [execute "forward";execute "reverse"]=[19.;22.])
  | _ -> failwith "expected a race between the mask transfer and the gather"

let hfusion_indirect () =
  let ast = parse "fixtures/hfusion_carried_indirect.mlir" in
  let wide = 9007199254740993L in
  List.iter (fun count ->
    let configuration = launch (Printf.sprintf {|{"arguments":[
      {"shape":[3],"initial":[%Ld,467,3]},
      {"shape":[2],"storage":"output","initial":[0,-19]},2,%d
    ]}|} wide count) in
    let lowered = H.lower_mlir ~configuration ast in
    let device = match lowered with Device_mlir program -> program | _ -> assert false in
    let report = H.analyze_mlir ~backend:Search lowered in
    assert (races report=[]);
    let state = Device_run.run ~iteration_ordinals:true device.program device.memory device.bindings in
    let bytes = Hashtbl.find state.memory (Device_value.Allocation "output") in
    assert (Bytes.get_int64_le bytes 0=Int64.add wide (Int64.of_int (3*count)));
    assert (Bytes.get_int64_le bytes 8 = -19L)
  ) [0;2]

let cross_flag () =
  let ast = parse_inline "cross-flag.mlir" {|module {
  func.func @sender(%src: memref<1xf32>, %shared: memref<1xf32>) {
    hivm.hir.load ins(%src : memref<1xf32>) outs(%shared : memref<1xf32>)
    hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE2>, <PIPE_V>] flag = 0
    return
  }
  func.func @receiver(%shared: memref<1xf32>, %dst: memref<1xf32>) {
    hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE2>, <PIPE_V>] flag = 0
    hivm.hir.vexp ins(%shared : memref<1xf32>) outs(%dst : memref<1xf32>)
    return
  }
}|} in
  let configuration = launch {|{"edges":[[0,1]],"streams":[
    {"entry":"sender","arguments":[null,{"storage":"shared"}]},
    {"entry":"receiver","arguments":[{"storage":"shared"},null]}
  ]}|} in
  let lowered = H.lower_mlir ~configuration ast in
  let schedule = H.analyze_mlir ~backend:Search lowered in
  assert (races schedule=[]);
  let events = J.to_list (field "events" schedule) in
  List.iter (fun opcode -> assert (List.exists (fun e -> field "opcode" (field "origin" e)=`String opcode) events))
    ["hivm.hir.sync_block_set";"hivm.hir.sync_block_wait"]

let generic_matrix () =
  let ast = parse ~syntax:Generic "fixtures/hivm_mmad_parts.mlir" in
  let configuration = launch {|{"streams":[
    {"entry":"mmad_parts","arguments":[null,null,{"storage":"result"}]},
    {"entry":"mmad_parts","arguments":[null,null,{"storage":"result"}]}
  ]}|} in
  let lowered = H.lower_mlir ~configuration ast in
  List.iter (fun backend ->
    let report = H.analyze_mlir ~backend ~hivm:true lowered in
    check_locations ast report;
    (match races report with
     | [race] ->
         List.iter (fun order ->
           let steps = J.to_list (field order race) in
           List.iter (fun stream ->
             let stages = List.filter_map (fun event ->
               if field "stream" event=`Int stream && field "phase" event=`String "complete" then
                 Some (J.to_string (field "part" event)) else None) steps in
             assert (stages=["load";"signal_loaded";"wait_loaded";"compute"])
           ) [0;1]
         ) ["forward";"reverse"]
     | _ -> failwith "expected one matrix output race")
  ) Bug_traces.[Search;Solve]

let unsupported () =
  let ast = parse_inline "unsupported.mlir" {|func.func @unused(%buffer: memref<1xi32>) {
  memref.dealloc %buffer : memref<1xi32>
  return
}|} in
  let report=H.analyze_mlir ~backend:Search ~hivm:true (H.lower_mlir ast) in
  assert (field "status" report=`String "unknown" && races report=[]);
  match H.lower_mlir ~allow_prefix:false ast with
  | _ -> failwith "unsupported operation passed lowering"
  | exception Attention_runtime.Source.Error (span,message) ->
      assert (span.file="unsupported.mlir" && span.start.line=2);
      assert (String.starts_with ~prefix:"memref.dealloc:" message)

let unsupported_device_geometry () =
  let ast = parse_inline "device-geometry.mlir" {|func.func @unsupported(%offset: memref<1xindex>, %dst: memref<4xi32>, %mask: vector<4xi1>, %values: vector<4xi32>) {
  %zero = arith.constant 0 : index
  %at = memref.load %offset[%zero] : memref<1xindex>
  vector.maskedstore %dst[%at], %mask, %values : memref<4xi32>, vector<4xi1>, vector<4xi32>
  return
}|} in
  let program = H.lower_mlir ast in
  match H.analyze_mlir ~backend:Search program with
  | _ -> failwith "schedule-dependent geometry was accepted as fixed"
  | exception Invalid_argument message ->
      assert (String.starts_with ~prefix:"device-geometry.mlir:4:" message)

let counter_and_local_snapshot () =
  let ast=parse_inline "local-counter.mlir" {|module {
  func.func @count(%output: memref<6xi32>) {
    %lo = arith.constant 2 : index
    %hi = arith.constant 8 : index
    %step = arith.constant 2 : index
    %zero = arith.constant 0 : index
    %other = arith.constant 5 : index
    %value = arith.constant 12 : i32
    %slot = memref.alloca() : memref<1xindex>
    %alias = "memref.cast"(%slot) : (memref<1xindex>) -> memref<?xindex>
    scf.for %iv = %lo to %hi step %step {
      %a = "hivm.hir.multi_buffer_counter"() : () -> i64
      %b = "hivm.hir.multi_buffer_counter"() : () -> i64
      %sum = arith.addi %a, %b : i64
      %at = arith.index_cast %sum : i64 to index
      memref.store %at, %slot[%zero] : memref<1xindex>
      %snapshot = memref.load %alias[%zero] : memref<?xindex>
      memref.store %other, %slot[%zero] : memref<1xindex>
      memref.store %value, %output[%snapshot] : memref<6xi32>
    }
    return
  }
  func.func @main(%output: memref<6xi32>) {
    func.call @count(%output) : (memref<6xi32>) -> ()
    func.call @count(%output) : (memref<6xi32>) -> ()
    return
  }
}|} in
  let program=H.lower_mlir ~entry:"main" ~allow_prefix:false ast in
  let core=match program with Core_mlir p->p | _->assert false in
  let schedule=Race_report.Schedule.compile ~capacity:1 core.program in
  let offsets=Array.to_list schedule.nodes |> List.filter_map (fun n->
    match n.Race_report.Schedule.phase with
    | Emit {action=Immediate (Operation (_, {writes=(C.Input 0,byte)::_;_}));_} -> Some byte
    | _ -> None) in
  assert (offsets=[0;8;16;0;8;16]);
  List.iter (fun backend->let report=H.analyze_mlir ~backend program in
    assert (field "status" report=`String "complete" && races report=[])) [Search;Solve]

let debug_conflict () =
  let ast=parse_inline "debug-read.mlir" {|func.func @main(%src: memref<4xi32>, %dst: memref<4xi32>) {
    hivm.hir.load ins(%src : memref<4xi32>) outs(%dst : memref<4xi32>)
    %v = memref.subview %dst[1] [2] [1] : memref<4xi32> to memref<2xi32, strided<[1], offset: 1>>
    "hivm.hir.debug"(%v) {debugtype = "print", prefix = "values"} : (memref<2xi32, strided<[1], offset: 1>>) -> ()
    return
  }|} in
  let program=H.lower_mlir ~allow_prefix:false ast in
  List.iter (fun backend->
    let report=H.analyze_mlir ~backend program in
    assert (field "status" report=`String "complete" && H.replay_mlir program report=2);
    let source=H.project_mlir program report in
    check_locations ast source;
    match races source with
    | [r] ->
        let endpoints=List.map (fun k->field k r) ["first";"second"] in
        assert (List.exists (fun e->field "opcode" e=`String "hivm.hir.debug" &&
          field "phase" e=`String "execute") endpoints)
    | _->assert false) [Search;Solve]

let dense_float_bits () =
  let ast=parse_inline "hex-float.mlir" {|func.func @main() {
    %v = arith.constant dense<[0xFF800000, 0x3F800000]> : vector<2xf32>
    return
  }|} in
  let op=H.Module_ast.resolve ast ~entry:"@main" [0] in
  assert (List.assoc "value" op.decoded=`List [`String "-inf";`String "1.0"])

let ub_scalar_readback () =
  let source competing = Printf.sprintf {|func.func @main(%%out: memref<2xi32>, %%incoming: memref<1xindex>) {
    %%byte = arith.constant 32 : i64
    %%zero = arith.constant 0 : index
    %%one = arith.constant 1 : index
    %%value = arith.constant 3 : i32
    %%first = "hivm.hir.pointer_cast"(%%byte) : (i64) -> memref<1xindex, #hivm.address_space<ub>>
    %%alias = "hivm.hir.pointer_cast"(%%byte) : (i64) -> memref<1xindex, #hivm.address_space<ub>>
    memref.store %%one, %%first[%%zero] : memref<1xindex, #hivm.address_space<ub>>
    %s
    %%pos = memref.load %%alias[%%zero] : memref<1xindex, #hivm.address_space<ub>>
    memref.store %%value, %%out[%%pos] : memref<2xi32>
    return
  }|} competing in
  let lower variant =
    H.lower_mlir ~allow_prefix:false (parse_inline "ub-scalar.mlir" (source variant)) in
  let simple=lower "" in
  List.iter (fun backend ->
    let report=H.analyze_mlir ~backend simple in
    assert (field "status" report=`String "complete" && races report=[])) [Search;Solve];
  let concurrent=lower "hivm.hir.load ins(%incoming : memref<1xindex>) outs(%alias : memref<1xindex, #hivm.address_space<ub>>)" in
  match H.analyze_mlir ~backend:Search concurrent with
  | _ -> failwith "accepted a fixed address derived from a concurrent UB write"
  | exception Invalid_argument msg -> assert (String.starts_with ~prefix:"a concurrent" msg)

let large_loop_traces () =
  let check stage instruction =
    let ast=parse_inline "large-loop.mlir" (Printf.sprintf {|func.func @main(%%src: memref<1xi32>, %%dst: memref<1xi32>, %%n: index) {
      %%zero = arith.constant 0 : index
      %%one = arith.constant 1 : index
      scf.for %%i = %%zero to %%n step %%one {
        %s
      }
      %s
      return
    }|} instruction instruction) in
    let configuration=launch (Printf.sprintf {|{"stage":"%s","arguments":[null,null,70]}|} stage) in
    let p=H.lower_mlir ~configuration ast in
    List.iter (fun backend ->
      let core=H.analyze_mlir ~backend p in
      assert (field "trace_extent" core=`String "program_end" && field "prefix_rounds" core=`Int 2);
      assert (H.replay_mlir p core=2);
      let source=H.project_mlir p core in
      check_locations ast source;
      let race=List.hd (races source) in
      let check_direction key first second =
        let trace=J.to_list (field key race) in
        assert (List.length trace=142);
        assert (List.filter (fun e -> e=first || e=second) trace=[first;second]);
        assert (List.exists (fun e -> field "iterations" e=`List [`Int 69]) trace);
        assert (List.exists (fun e -> field "iterations" e=`List [] && field "phase" e=`String "complete") trace) in
      check_direction "forward" (field "first" race) (field "second" race);
      check_direction "reverse" (field "second" race) (field "first" race);
      let row=List.hd (races core) in
      let shorten fields key value=`Assoc ((key,value)::List.remove_assoc key (J.to_assoc fields)) in
      (match H.replay_mlir p (shorten core "prefix_rounds" (`Int 1)) with
       | exception Invalid_argument _ -> () | _ -> failwith "accepted incorrect race prefix round count");
      let row=shorten row "forward" (`List (List.rev (List.tl (List.rev (J.to_list (field "forward" row)))))) in
      (match H.replay_mlir p (shorten core "races" (`List [row])) with
       | exception Invalid_argument _ -> () | _ -> failwith "accepted incomplete large-loop execution")
    ) Bug_traces.[Search;Solve] in
  check "hivm" "hivm.hir.load ins(%src : memref<1xi32>) outs(%dst : memref<1xi32>)";
  check "hfusion" "memref.copy %src, %dst : memref<1xi32> to memref<1xi32>"

let late_source_race () =
  let ast=parse_inline "late-loop.mlir" {|func.func @main(%src: memref<1xi32>, %dst: memref<1xi32>, %n: index) {
    %zero = arith.constant 0 : index
    %one = arith.constant 1 : index
    %late = arith.constant 67 : index
    %launch = arith.constant 70 : index
    %enabled = arith.cmpi eq, %n, %launch : index
    scf.for %i = %zero to %n step %one {
      %at = arith.cmpi eq, %i, %late : index
      %both = arith.andi %at, %enabled : i1
      scf.if %both {
        memref.copy %src, %dst : memref<1xi32> to memref<1xi32>
        memref.copy %src, %dst : memref<1xi32> to memref<1xi32>
      }
    }
    return
  }|} in
  let analyze n = H.lower_mlir ~configuration:(`Assoc ["stage",`String "hfusion";
    "arguments",`List [`Null;`Null;`Int n]]) ast in
  let p=analyze 70 in
  let core=H.analyze_mlir ~backend:Solve p in
  assert (field "prefix_rounds" core=`Int 68 && H.replay_mlir p core=2);
  assert (field "status" (H.analyze_mlir ~backend:Solve (analyze 69))=`String "no-race")

let large_device_race () =
  let ast=parse_inline "device-loop.mlir" {|module {
    func.func @writer(%dst: memref<4xi32>, %mask: vector<4xi1>, %values: vector<4xi32>, %n: index) {
      %zero = arith.constant 0 : index
      %one = arith.constant 1 : index
      scf.for %i = %zero to %n step %one {
        vector.maskedstore %dst[%zero], %mask, %values : memref<4xi32>, vector<4xi1>, vector<4xi32>
      }
      return
    }
  }|} in
  let args=launch {|[{"storage":"shared"},{"initial":[true,false,false,false]},{"initial":[6,7,8,9]},70]|} in
  let stream b=`Assoc ["entry",`String "writer";"block",`Int b;"arguments",args] in
  let p=H.lower_mlir ~configuration:(`Assoc ["streams",`List [stream 0;stream 1]]) ast in
  let ()=match p with H.Device_mlir _ -> () | _ -> failwith "expected masked device program" in
  let core=H.analyze_mlir ~backend:Solve p in
  assert (field "trace_extent" core=`String "program_end" && H.replay_mlir p core=2);
  let source=H.project_mlir p core in
  check_locations ast source;
  let r=List.hd (races source) in
  List.iter (fun key ->
    let events=J.to_list (field key r) in
    List.iter (fun b -> assert (List.exists (fun e ->
      field "stream" e=`Int b && field "iterations" e=`List [`Int 69]) events)) [0;1])
    ["forward";"reverse"]

let symbolic_prefix_execution () =
  let check rounds stage op barrier expected =
    let ast=parse_inline "prefix-execution.mlir" (Printf.sprintf {|func.func @main(%%src: memref<1xi32>, %%dst: memref<1xi32>, %%n: index) {
      %%z = arith.constant 0 : index
      %%one = arith.constant 1 : index
      scf.for %%i = %%z to %%n step %%one {
        %s
        %s
      }
      return
    }|} op barrier) in
    let p=H.lower_mlir ~configuration:(`Assoc ["stage",`String stage;"arguments",`List [`Null;`Null;`Int rounds]]) ast in
    let report=H.analyze_mlir ~backend:Search ~hivm:true p in
    assert (field "analysis" report=`String "loop-smt" && field "graph_loop_bound" report=`Int expected);
    if expected=0 then assert (field "status" report=`String "no-race")
    else (
      assert (field "prefix_rounds" report=`Int expected);
      let race=List.hd (races report) in
      let check_order name a b=
        let trace=J.to_list (field name race) in
        assert (List.length trace=2*rounds);
        assert (List.filter (fun e->e=field a race || e=field b race) trace=[field a race;field b race]);
        assert (List.exists (fun e->field "iterations" e=`List [`Int (rounds-1)]) trace) in
      check_order "forward" "first" "second";check_order "reverse" "second" "first") in
  let copy="memref.copy %src, %dst : memref<1xi32> to memref<1xi32>" in
  List.iter (fun rounds->
    let expected=if rounds<2 then 0 else 2 in
    check rounds "hfusion" copy "" expected;
    check rounds "hfusion" copy "hfusion.barrier" 0;
    check rounds "hivm" "hivm.hir.load ins(%src : memref<1xi32>) outs(%dst : memref<1xi32>)" "" expected)
    [0;1;2;64;65;128]

let () =
  large_loop_traces (); late_source_race (); large_device_race (); symbolic_prefix_execution ();
  examples (); issue316 (); issue316_barrier_scope (); nested_async_calls (); reject_foreign_trace (); carried_views (); dynamic_slices (); indexed (); masked_vector (); scheduled_mask ();
  hfusion_indirect (); cross_flag (); generic_matrix (); unsupported (); unsupported_device_geometry ();
  counter_and_local_snapshot (); debug_conflict (); dense_float_bits (); ub_scalar_readback ()
