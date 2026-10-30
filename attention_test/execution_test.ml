open Attention_runtime

let check_case label input =
  let expected = Attention.reference input in
  let results = List.map (fun (name,stage,file) ->
    let seen = Hashtbl.create 20 in
    let trace event = match event with
      | `Assoc fields ->
          (match List.assoc_opt "program_id" fields with
          | Some (`Int pid) ->
              Hashtbl.replace seen pid ();
              if pid >= 4 then assert (List.assoc_opt "entry" fields <> Some (`String "sem_memref_copy"))
          | _ -> ());
          if Sys.getenv_opt "ATTENTION_TEST_PROGRESS" = Some "1" &&
             List.assoc_opt "entry" fields <> Some (`String "eval_scalar_operation") then
            (Yojson.Basic.to_channel stderr event; output_char stderr '\n'; flush stderr)
      | _ -> ()
    in
    let result = Attention.run ~stage ~trace ~file input in
    let ok_o,err_o = Attention.compare_array expected.o result.o in
    let ok_lse,err_lse = Attention.compare_array expected.lse result.lse in
    Printf.printf "%s/%s: steps=%d calls=%d O error=%g LSE error=%g\n%!"
      label name result.steps result.calls err_o err_lse;
    assert (Hashtbl.length seen = 20);
    assert (ok_o && ok_lse);
    result
  ) ["archived-hfusion", "hfusion", "../artifacts/flash_attention/ir/hfusion_level.mlir";
     "archived-hivm", "hivm", "../artifacts/flash_attention/ir/attention_hivm_compute.mlir";
     "compiled-hfusion", "hfusion", "../artifacts/kernel_IR/attention/hfusion.mlir";
     "compiled-hivm", "hivm", "../artifacts/kernel_IR/attention/hivm.mlir"] in
  match results with
  | a::rest -> List.iter (fun (b : Attention.output) ->
      assert (fst (Attention.compare_array a.o b.o));
      assert (fst (Attention.compare_array a.lse b.lse))) rest
  | _ -> assert false

let check_mutation random =
  let file = "fixtures/attention_hivm_vadd.mlir" in
  let replacement = "hivm.hir.vadd" in
    let changed = ref false in
    let trace = function
      | `Assoc fields when List.assoc_opt "opcode" fields = Some (`String replacement) &&
          List.assoc_opt "result" fields = Some (`String "%37") -> changed := true
      | _ -> () in
    let actual = Attention.run ~trace ~file random in
    assert (!changed);
    assert (not (fst (Attention.compare_array (Attention.reference random).o actual.o)));
    print_endline "vadd MLIR fixture changes both trace and numerical output"


let () =
  let random = Attention.default_input () in
  let jobs = [
    (fun () -> check_case "seeded" random);
    (fun () -> check_case "zero-QK" {random with q=Array.make 16384 0.; k=Array.make 16384 0.});
    (fun () -> check_case "constant" {random with q=Array.make 16384 0.125;
      k=Array.make 16384 (-0.25); v=Array.make 16384 0.75});
    (fun () -> check_mutation random)
  ] in
  (* Cases own independent interpreter states. Programs inside each interpreter
     still execute sequentially; this parallelizes only the test harness. *)
  let domains = List.map (fun f -> Domain.spawn (fun () ->
    try f (); Ok () with exn -> Error exn)) jobs in
  let results = List.map Domain.join domains in
  List.iter (function Ok () -> () | Error exn -> raise exn) results
