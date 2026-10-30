open Attention_runtime

let reject f = match f () with
  | _ -> failwith "invalid vector-add input accepted"
  | exception Invalid_argument _ -> ()
  | exception Source.Error _ -> ()

let () =
  List.iter (fun n ->
    let a = Array.init n (fun i -> float_of_int (i mod 31 - 15) /. 4.) in
    let b = Array.init n (fun i -> float_of_int (i mod 17 - 8) /. 8.) in
    let expected = Array.map2 ( +. ) a b in
    List.iter (fun stage ->
      let file = "../artifacts/kernel_IR/vector-add/" ^ stage ^ ".mlir" in
      let fills = ref 0 and pids = Hashtbl.create 8 in
      let trace = function
        | `Assoc fields ->
            (match List.assoc_opt "program_id" fields, List.assoc_opt "opcode" fields with
            | Some (`Int pid), Some _ -> Hashtbl.replace pids pid ()
            | _ -> ());
            (match List.assoc_opt "opcode" fields,List.assoc_opt "entry" fields with
            | Some (`String "linalg.fill"),Some (`String "sem_linalg_fill")
            | Some (`String "hivm.hir.vbrc"),Some (`String "HIVM.evaluate") -> incr fills
            | _ -> ())
        | _ -> () in
      let result = Vector_add.run ~stage ~trace ~file a b in
      (match result.outputs with
      | [output] -> assert (output.shape = [n]);
          assert (fst (Attention.compare_array expected output.data))
      | _ -> assert false);
      assert (Hashtbl.length pids = (n + 255) / 256);
      assert (!fills = if n mod 256 = 0 then 0 else 2);
      Printf.printf "compiled vector-add/%s length=%d: result, programs and tail branches passed\n%!" stage n
    ) ["hfusion";"hivm"]
  ) [0;1;255;256;257;512;513;777];
  let file = "../artifacts/kernel_IR/vector-add/hfusion.mlir" in
  reject (fun () -> Vector_add.run ~file [|1.|] [||]);
  reject (fun () -> Vector_add.run ~file [|nan|] [|1.|]);
  reject (fun () -> Vector_add.run ~file ~max_steps:1 [|1.|] [|2.|]);
  reject (fun () -> Vector_add.run ~file ~stage:"hivm" [|1.|] [|2.|]);
  let file = "fixtures/dynamic_slices.mlir" in
  let fills = ref 0 in
  let result = Kernel.run ~file ~stage:"hfusion" ~trace:(function
    | `Assoc fields when List.assoc_opt "entry" fields = Some (`String "sem_linalg_fill") -> incr fills
    | _ -> ()) ["%input",Kernel.Input (Array.init 8 float_of_int);"%out",Kernel.Output] in
  assert (!fills = 1);
  (match result.outputs with [output] -> assert (output.data = [|3.;5.|]) | _ -> assert false);
  let program = Parser.parse ~file (Attention.read_file file) in
  let invalid = List.map (fun (op : Parser.operation) ->
    if op.opcode = "memref.subview" then {op with attributes=List.map (fun (key,value) ->
      key,if key = "offsets" then `List [`Assoc ["static",`Int (-1)]] else value) op.attributes}
    else op) program.body in
  reject (fun () -> Validate.kernel {program with body=invalid});
  (match Parser.parse ~file:"integer.mlir"
    "func.func @f() { %n = arith.constant -9223372036854775808 : i64 return }" with
  | _ -> failwith "out-of-range integer constant accepted"
  | exception Failure message ->
      assert (String.ends_with ~suffix:"([-2^62, 2^62-1])" message));
  print_endline "nested strided slices, both if branches and invalid inputs passed"
