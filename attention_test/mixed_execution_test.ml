open Attention_runtime

let () =
  let input = Attention.default_input () in
  let expected = Attention.reference input in
  let seen = Hashtbl.create 8 in
  let trace = function
    | `Assoc fields ->
        (match List.assoc_opt "result" fields, List.assoc_opt "ir_stage" fields,
            List.assoc_opt "entry" fields with
        | Some (`String result),Some (`String stage),Some (`String entry) ->
            Hashtbl.replace seen (result,stage,entry) ()
        | _ -> ())
    | _ -> assert false in
  let result = Attention.run ~stage:"mixed" ~trace
    ~file:"../examples/attention_mixed.mlir" input in
  let ok_o,error_o = Attention.compare_array expected.o result.o in
  let ok_lse,error_lse = Attention.compare_array expected.lse result.lse in
  assert (ok_o && ok_lse);
  List.iter (fun key -> assert (Hashtbl.mem seen key))
    ["%17","hfusion","sem_linalg_matmul";
     "%18","hivm","HIVM.evaluate";
     "%reduced","hfusion","sem_linalg_reduce";
     "%38","common","eval_scalar_operation";
     "%20","hivm","HIVM.evaluate";
     "%22","hfusion","sem_hfusion_cast";
     "%37","hivm","HIVM.evaluate"];
  Printf.printf "mixed attention: O error=%g LSE error=%g; both computation handlers passed\n%!"
    error_o error_lse
