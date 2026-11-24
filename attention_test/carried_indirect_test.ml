open Attention_runtime

let int = fun n -> Numeric.Integer n
let buffer data output =
  Kernel.Buffer {shape=[List.length data];data=Some (List.map int data);output}

let () =
  let file = "fixtures/carried_indirect.mlir" in
  let wide = 9007199254740993L in
  List.iter (fun count ->
    let args = [
      "%src",buffer [wide;467L;3L] false;
      "%out",buffer [0L;-19L] true;
      "%stride",Kernel.Scalar (int 2L);
      "%count",Kernel.Scalar (int count);
    ] in
    let result = Kernel.run_bound ~file ~stage:"hfusion" args in
    let expected = Int64.add wide (Int64.mul count 3L) in
    match result.buffers with
    | [{name="%out";shape=[2];cells=[Numeric.Integer updated;Numeric.Integer untouched]}] ->
        assert (updated = expected && untouched = -19L)
    | _ -> failwith "unexpected masked store result"
  ) [0L;2L];
  print_endline "carried loop results, dynamic strides and masked i64 memory access passed"
