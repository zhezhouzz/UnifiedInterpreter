open Attention_runtime
module E = Extracted_semantics.Unified_semantics

let expect_invalid f =
  match f () with
  | _ -> failwith "invalid kernel input accepted"
  | exception Invalid_argument _ -> ()

let run_case name bindings expected =
  let example = Kernel_examples.get name in
  List.iter (fun stage ->
    let events = ref [] in
    let file = "../" ^ Kernel_examples.file example stage in
    let result = Kernel.run ~stage ~file ~trace:(fun e -> events := e :: !events) bindings in
    (match result.outputs with
    | [output] ->
        assert (output.shape = if name = "vector-add" then [8] else [3]);
        assert (fst (Attention.compare_array expected output.data))
    | _ -> assert false);
    assert (List.length !events = result.calls);
    let expected_entry = if stage = "hivm" then "HIVM.evaluate"
      else if name = "vector-add" then "sem_linalg_elemwise_binary" else "sem_linalg_reduce" in
    assert (List.exists (function `Assoc fields ->
      List.assoc_opt "ir_stage" fields = Some (`String stage) &&
      List.assoc_opt "entry" fields = Some (`String expected_entry)
      | _ -> false) !events);
    Printf.printf "%s/%s: numerical result and handler trace passed\n%!" name stage
  ) ["hfusion";"hivm"]

let () =
  List.iter (fun name ->
    let example = Kernel_examples.get name in
    run_case name example.bindings example.expected) ["vector-add";"row-sum"];
  run_case "vector-add"
    ["%a",Kernel.Input [|8.;7.;6.;5.;4.;3.;2.;1.|];
     "%b",Kernel.Input [|-8.;-7.;-6.;-5.;-4.;-3.;-2.;-1.|];"%out",Kernel.Output]
    (Array.make 8 0.);
  run_case "row-sum"
    ["%input",Kernel.Input [|4.;-3.;2.;-1.; 10.;20.;30.;40.; -2.;-4.;-6.;-8.|];
     "%out",Kernel.Output] [|2.;100.;-20.|];
  let example = Kernel_examples.get "vector-add" in
  let file = "../" ^ Kernel_examples.file example "hfusion" in
  expect_invalid (fun () -> Kernel.run ~file []);
  expect_invalid (fun () -> Kernel.run ~file (("%out",Kernel.Output)::example.bindings));
  expect_invalid (fun () -> Kernel.run ~file
    ["%a",Kernel.Input [|0.|];"%b",Kernel.Input (Array.make 8 0.);"%out",Kernel.Output]);
  expect_invalid (fun () -> Kernel.run ~file
    ["%a",Kernel.Input (Array.make 8 nan);"%b",Kernel.Input (Array.make 8 0.);"%out",Kernel.Output]);
  expect_invalid (fun () -> Kernel.run ~file ~max_steps:0 example.bindings);
  (match Kernel.run ~file ["%a",Kernel.Output;"%b",Kernel.Output;"%out",Kernel.Output] with
  | _ -> failwith "uninitialized input was read"
  | exception Source.Error (_,message) ->
      assert (String.ends_with ~suffix:"ReadUninitialized (program_id=0)" message));
  (match Kernel.run ~stage:"hivm" ~file example.bindings with
  | _ -> failwith "wrong-stage kernel accepted"
  | exception Source.Error _ -> ());
  (match Kernel.run ~file ~max_steps:1 example.bindings with
  | _ -> failwith "kernel execution budget ignored"
  | exception Source.Error (_,message) -> assert (message = "execution step budget exhausted"));
  let program = Parser.parse ~file (Attention.read_file file) in
  expect_invalid (fun () -> Validate.program program);
  print_endline "kernel bindings, uninitialized memory, stage and execution budget checks passed"
