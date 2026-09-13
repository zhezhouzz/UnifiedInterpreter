let () =
  let open Unified_interpreter in
  let example = Example.make () in
  let top = Runtime.run_program (fun () -> Top.eval example.command) in
  let core = Runtime.run_program (fun () -> Core.eval (Lowering.to_core example.command)) in
  let vector =
    Runtime.run_program (fun () ->
        Vector.eval (Lowering.to_vector (Lowering.to_core example.command)))
  in
  let mem_async =
    Runtime.run_program (fun () ->
        Mem_async.eval
          (Lowering.to_mem_async
             (Lowering.to_vector (Lowering.to_core example.command))))
  in
  assert (Runtime.same_tensor top "C" core "C");
  assert (Runtime.same_tensor top "C" vector "C");
  assert (Runtime.same_tensor top "C" mem_async "C")
