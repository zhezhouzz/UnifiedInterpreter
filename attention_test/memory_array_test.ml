open Attention_runtime
module E = Extracted_semantics.Unified_semantics
module H = Handlers

let z = Numeric.z_of_int
let unwrap = function E.Ok x -> x | E.Error _ -> failwith "unexpected memory error"
let storage size =
  let _, memory = E.allocate_memref E.ASGM E.Float32Type [size] E.empty_memory in
  match E.lookup_buffer 0 memory with Some b -> b | None -> assert false

let check_cell buffer index expected =
  match expected, E.read_buffer_cell buffer (z index) with
  | None, E.Error E.ReadUninitializedCell -> ()
  | Some a, E.Ok b -> assert (a = b)
  | _ -> failwith "array memory disagrees with reference"

let () =
  let size = 8195 in
  let initial = storage size in
  assert (E.read_buffer_cell initial (z (-1)) = E.Error E.ViewAddressOutOfBounds);
  assert (E.read_buffer_cell initial (z size) = E.Error E.ViewAddressOutOfBounds);
  assert (E.write_buffer_cell initial (z size) 1. = E.Error E.ViewAddressOutOfBounds);
  assert (E.write_buffer_cell initial (z (-1)) 1. = E.Error E.ViewAddressOutOfBounds);
  let huge_address = Numeric.z_of_big (Z.shift_left Z.one 80) in
  assert (E.read_buffer_cell initial huge_address = E.Error E.ViewAddressOutOfBounds);
  assert (E.write_buffer_cell initial huge_address 1. = E.Error E.ViewAddressOutOfBounds);
  assert (E.read_buffer_cell (storage 0) E.Z0 = E.Error E.ViewAddressOutOfBounds);
  let versions = ref [initial, Array.make size None] in
  let rng = Random.State.make [|4096; 2026|] in
  for step = 0 to 999 do
    let old, reference = List.nth !versions (Random.State.int rng (List.length !versions)) in
    let index = if step mod 4 = 0 then [|0;4095;4096;8192;8194|].(step mod 5)
      else Random.State.int rng size in
    let value = float_of_int step in
    let updated = unwrap (E.write_buffer_cell old (z index) value) in
    let expected = Array.copy reference in
    expected.(index) <- Some value;
    check_cell old index reference.(index);
    check_cell updated index (Some value);
    List.iter (fun (buffer, model) ->
      List.iter (fun i -> check_cell buffer i model.(i)) [0;4095;4096;8192;8194;index]) !versions;
    versions := (updated,expected) :: (if List.length !versions < 12 then !versions
      else List.filteri (fun i _ -> i < 11) !versions)
  done;
  List.iter (fun (buffer, model) -> Array.iteri (check_cell buffer) model) !versions;
  let values = List.init size float_of_int in
  let _, memory = E.allocate_buffer E.ASGM E.Float32Type values E.empty_memory in
  let initialized = Option.get (E.lookup_buffer 0 memory) in
  List.iteri (fun i value -> check_cell initialized i (Some value)) values;
  (* 验证超过单个 PArray 上限的逻辑 buffer 不会被截短。 *)
  let large = storage 5000000 in
  let large' = unwrap (E.write_buffer_cell large (z 4999999) 42.) in
  check_cell large' 4999999 (Some 42.);
  check_cell large 4999999 None;
  (* 批量访问覆盖跨页、负 stride、重复地址与错误发生顺序。 *)
  let bulk = unwrap (E.write_coordinates initial E.Z0 [z 1]
    [[4096];[0];[4096];[8194]] [1.;2.;3.;4.]) in
  assert (E.read_coordinates bulk (z 8194) [z (-1)] [[0];[4098];[8194]]
    = E.Ok [4.;3.;2.]);
  assert (E.read_coordinates bulk E.Z0 [z 1] [[4096];[0]] = E.Ok [3.;2.]);
  assert (E.read_coordinates bulk E.Z0 [z 1] [[1];[0;0]]
    = E.Error E.ReadUninitializedCell);
  assert (E.read_coordinates bulk (z (-1)) [z 1] [[0];[0;0]]
    = E.Error E.ViewAddressOutOfBounds);
  assert (E.write_coordinates bulk E.Z0 [z 1] [[9000];[0;0]] [1.;2.]
    = E.Error E.ViewAddressOutOfBounds);
  assert (E.write_coordinates bulk E.Z0 [z 1] [[9000];[0]] []
    = E.Error E.InvalidViewRank);
  assert (E.write_coordinates bulk E.Z0 [z 1] [[0];[9000]] [1.]
    = E.Error E.InvalidViewRank);
  check_cell initial 4096 None;
  check_cell bulk 4096 (Some 3.);
  (* 实际写入后发生错误，重新读取保存的状态和当前状态。 *)
  let state = ref {H.memory=E.empty_memory; marker=73} in
  H.run ~state ~on_call:ignore (fun () ->
    let id = H.memory "allocate" (E.sem_memref_alloc E.ASGM E.Float32Type [2]) in
    let write xs = E.write_result (H.unwrap (E.make_value [2] E.Float32Type xs)) id in
    ignore (Effect.perform (H.Memory ("initialize",write [1.;2.])));
    let saved = !state in
    let fail_after_write = E.bind (write [9.;10.])
      (fun _ -> E.Return (E.Error E.NumericFailure)) in
    (match Effect.perform (H.Memory ("failed computation",fail_after_write)) with
     | _ -> failwith "expected NumericFailure"
     | exception H.Semantic_error E.NumericFailure -> ());
    let read memory =
      match E.read_view memory id with
      | E.Ok (E.PackTensor (_,_,xs)) -> xs
      | E.Error _ -> failwith "cannot read saved state" in
    assert (read saved.memory = [1.;2.]);
    assert (read (!state).memory = [1.;2.]);
    ignore (Effect.perform (H.Memory ("successful computation",write [3.;4.])));
    assert (read (!state).memory = [3.;4.]);
    assert (read saved.memory = [1.;2.]);
    assert ((!state).marker = 73));
  print_endline "PArray: branching versions, page boundaries, large buffers and lens failure semantics passed"
