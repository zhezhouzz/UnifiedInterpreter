open Attention_runtime
module E = Extracted_semantics.Unified_semantics
module H = Handlers

let state () = ref {H.memory=E.empty_memory; marker=73}
let run f = H.run ~state:(state ()) ~on_call:ignore f
let tensor sh ty xs = H.unwrap (E.make_value sh ty xs)
let expect_error f =
  match f () with
  | _ -> failwith "expected semantic error"
  | exception H.Semantic_error _ -> ()

let () =
  let a = tensor [2;2] E.Float16Type [1.;2.;3.;4.] in
  let b = tensor [2;2] E.Float16Type [5.;6.;7.;8.] in
  let dst = tensor [2;2] E.Float32Type [1.;1.;1.;1.] in
  let result = run (fun () -> Effect.perform (H.HFusion (H.Matmul (a,b,dst)))) in
  assert (E.elements1 result = E.Ok [20.;23.;44.;51.]);
  let spec = {E.mm_b_transpose=false;mm_init=false;
    mm_real_m=E.Z0;mm_real_k=E.Z0;mm_real_n=E.Z0} in
  let result = run (fun () -> Effect.perform (H.HIVM (E.MmadRequest (spec,a,b,dst)))) in
  assert (E.elements1 result = E.Ok [20.;23.;44.;51.]);
  assert (Numeric.maxnum nan 3. = 3.);
  assert (Float.is_nan (Numeric.propagating_max nan 3.));
  assert (run (fun () -> Effect.perform
    (H.Common (H.Scalar_binary (E.ScalarMax,nan,3.)))) = 3.);
  let nan_result = run (fun () -> Effect.perform (H.HIVM (E.ReduceRequest
    (E.ReduceMax,tensor [1;2] E.Float32Type [nan;3.],
      E.EmptyTensor ([1;1],E.Float32Type),[1])))) in
  (match E.elements1 nan_result with E.Ok [x] -> assert (Float.is_nan x) | _ -> assert false);
  List.iter (fun (disabled,f) ->
    try ignore (H.run ~enable_hfusion:(disabled <> "hfusion") ~enable_hivm:(disabled <> "hivm")
      ~enable_common:(disabled <> "common") ~enable_memory:(disabled <> "memory")
      ~state:(state ()) ~on_call:ignore f);
      failwith "expected unhandled effect"
    with Effect.Unhandled _ -> ()
  ) [
    "hfusion",(fun () -> ignore (Effect.perform (H.HFusion (H.Matmul (a,b,dst)))));
    "hivm",(fun () -> ignore (Effect.perform (H.HIVM (E.MmadRequest (spec,a,b,dst)))));
    "common",(fun () -> ignore (Effect.perform (H.Common (H.Empty ([1],E.Float32Type)))));
    "memory",(fun () -> ignore (H.memory "alloc" (E.sem_memref_alloc E.ASGM E.Float32Type [1])));
  ];
  let s = state () in
  H.run ~state:s ~on_call:ignore (fun () ->
    let id = H.memory "alloc" (E.sem_memref_alloc E.ASGM E.Float32Type [2]) in
    let view = E.MemRefBackedTensor (id,[2],E.Float32Type,
      {E.access_restrict=false;access_writable=true}) in
    expect_error (fun () -> Effect.perform (H.Memory ("read",E.materialize view)));
    let before = !s in
    let write = E.write_result (tensor [3] E.Float32Type [1.;2.;3.]) id in
    expect_error (fun () -> Effect.perform (H.Memory ("invalid write",write)));
    assert (!s == before);
    let partial = E.bind (E.write_tensor_coordinates id [[0];[1]] [1.;2.])
        (fun _ -> E.Return (E.Error E.NumericFailure)) in
    expect_error (fun () -> Effect.perform (H.Memory ("rollback",partial)));
    assert (!s == before);
    let out_of_bounds = E.bind (E.read_tensor_coordinates id [[2]])
        (fun xs -> E.Return (E.Ok xs)) in
    expect_error (fun () -> Effect.perform (H.Memory ("bounds",out_of_bounds)));
    assert ((!s).marker = 73));
  expect_error (fun () -> run (fun () ->
    Effect.perform (H.HFusion (H.Matmul (a,b,E.EmptyTensor ([2;2],E.Float32Type))))));
  expect_error (fun () -> run (fun () ->
    Effect.perform (H.HIVM (E.CastRequest (E.default_cast,a,dst)))));
  print_endline "handlers: extracted matrix results, missing handlers, NaNs and atomic memory failures passed"
