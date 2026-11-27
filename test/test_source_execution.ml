open Stdlib
module H = Hivm_trace
module R = H.Execution
module V = H.Execution_value

let parse source = H.Module_ast.parse ~file:"execution.mlir" source
let configuration = Yojson.Safe.from_string
let word result bank i = Bytes.get_int32_le (List.assoc bank result.R.memory) (4*i)

let delayed_copy () =
  let ast = parse {|
module {
  func.func @consumer(%src: memref<1xi32>, %out: memref<1xi32>) {
    %zero = arith.constant 0 : index
    %eleven = arith.constant 11 : i32
    hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE2>, <PIPE_V>] flag = 0
    func.call @copy(%src, %out) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<1xi32>, memref<1xi32>) -> ()
    memref.store %eleven, %src[%zero] : memref<1xi32>
    return
  }
  func.func @producer() {
    hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE2>, <PIPE_V>] flag = 0
    return
  }
  func.func private @copy(%a: memref<1xi32>, %b: memref<1xi32>) {
    memref.copy %a, %b : memref<1xi32> to memref<1xi32>
    return
  }
}|} in
  let launch = configuration {|{"streams":[
    {"entry":"consumer","core":"vector","arguments":[{"storage":"src","initial":[2]},{"storage":"out"}]},
    {"entry":"producer","core":"cube","arguments":[]}]}|} in
  let result = R.run_module ~stage:"hivm" ~launch ast in
  assert (result.status=Finished && result.tasks=3 && word result "out" 0=11l)

let view_and_loop () =
  let ast = parse {|
func.func @kernel(%src: memref<4xi32>, %n: index) -> (index, memref<1xi32, strided<[1], offset: 1>>) {
  %z = arith.constant 0 : index
  %one = arith.constant 1 : index
  %nine = arith.constant 9 : i32
  %sub = memref.subview %src[2] [2] [1] : memref<4xi32> to memref<2xi32, strided<[1], offset: 2>>
  %v = memref.reinterpret_cast %sub to offset: [1], sizes: [1], strides: [1] : memref<2xi32, strided<[1], offset: 2>> to memref<1xi32, strided<[1], offset: 1>>
  memref.store %nine, %v[%z] : memref<1xi32, strided<[1], offset: 1>>
  %count = scf.for %i = %z to %n step %one iter_args(%sum = %z) -> (index) {
    %next = arith.addi %sum, %one : index
    scf.yield %next : index
  }
  return %count, %v : index, memref<1xi32, strided<[1], offset: 1>>
}|} in
  let launch = configuration {|{"arguments":[{"storage":"src","base_bytes":4,"initial":[1,2,3,4,5]},50000]}|} in
  let run ?max_steps () = R.run_module ?max_steps ~stage:"hfusion" ~launch ast in
  let result = run () in
  assert (result.status=Finished && result.steps>100000);
  assert (List.init 5 (word result "src")=[1l;2l;9l;4l;5l]);
  (match result.returned.(0) with
   | [V.Scalar (V.C.VInt n); V.Buffer b] ->
       assert (Z.equal n (Z.of_int 50000) && b.base=8 && V.number (V.get b 0)=9)
   | _ -> assert false);
  match (run ~max_steps:10 ()).status with R.Step_limit _ -> () | _ -> assert false

let () = delayed_copy (); view_and_loop ()
