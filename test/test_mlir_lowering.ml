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
      assert (List.hd (List.rev events)=field last race);
      List.iter (fun event ->
        let entry = J.to_string (field "entry" event) in
        let path = List.map J.to_int (J.to_list (field "path" event)) in
        let op = H.Module_ast.resolve ast ~entry path in
        assert (`String op.opcode=field "opcode" event)
      ) events in
    check "forward" "second";
    check "reverse" "first"
  ) (races report)

let issue316 () =
  let configuration = launch {|{"arguments":[{"shape":[3072]},null,3]}|} in
  List.iter (fun (file,count) ->
    let ast = parse ("../examples/kernels/" ^ file ^ ".mlir") in
    let lowered = H.lower_mlir ~configuration ast in
    List.iter (fun backend ->
      let core = H.analyze_mlir ~backend lowered in
      assert (List.length (races core)=count && H.replay_mlir lowered core=2*count);
      let hivm = H.analyze_mlir ~backend ~hivm:true lowered in
      assert (List.length (races hivm)=count);
      check_locations ast hivm
    ) Bug_traces.[Search;Solve]
  ) ["issue316_vexp_hivm",0;"issue316_missing_ready_hivm",5]

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
  match H.lower_mlir ast with
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

let () =
  examples (); issue316 (); carried_views (); dynamic_slices (); indexed (); masked_vector (); scheduled_mask ();
  hfusion_indirect (); cross_flag (); generic_matrix (); unsupported (); unsupported_device_geometry ()
