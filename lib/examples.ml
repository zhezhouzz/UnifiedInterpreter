(* Two sourced Triton-like programs, shallow-embedded in OCaml. *)

open Language
open Effects

let triton_source title url note = { title; url; note }

let vector_add_program ~x ~y ~out ~n_elements ~block_size () =
  default_handler_stack (fun () ->
      trace "enter vector_add";
      let pid = program_id 0 in
      let offsets =
        iadd
          (ibroadcast block_size (pid * block_size))
          (arange 0 block_size)
      in
      let mask = ilt offsets (ibroadcast block_size n_elements) in
      let x_vals = load ~ptr:x ~offsets ~mask ~other:0.0 () in
      let y_vals = load ~ptr:y ~offsets ~mask ~other:0.0 () in
      let sum = fadd x_vals y_vals in
      store ~ptr:out ~offsets ~values:sum ~mask ();
      trace "leave vector_add")

let vector_add_user_scoped_program ~x ~y ~out ~n_elements ~block_size () =
  source_to_simd_stack (fun () ->
      trace "enter vector_add_user_scoped";
      let pid = program_id 0 in
      let offsets =
        iadd
          (ibroadcast block_size (pid * block_size))
          (arange 0 block_size)
      in
      let mask = ilt offsets (ibroadcast block_size n_elements) in
      with_on_chip_memory (fun () ->
          let x_vals = load ~ptr:x ~offsets ~mask ~other:0.0 () in
          let y_vals = load ~ptr:y ~offsets ~mask ~other:0.0 () in
          let sum = fadd x_vals y_vals in
          with_sync_ops (fun () ->
              alloc_local pid "manual_h5_midpoint" 1;
              barrier pid "after_vector_fadd";
              wait pid "after_vector_fadd");
          store ~ptr:out ~offsets ~values:sum ~mask ());
      trace "leave vector_add_user_scoped")

let fused_softmax_program ~x ~out ~n_rows:_ ~n_cols ~block_size () =
  default_handler_stack (fun () ->
      trace "enter fused_softmax";
      let row_idx = program_id 0 in
      let col_offsets = arange 0 block_size in
      let row_base = ibroadcast block_size (row_idx * n_cols) in
      let linear_offsets = iadd row_base col_offsets in
      let mask = ilt col_offsets (ibroadcast block_size n_cols) in
      let row =
        load ~ptr:x ~offsets:linear_offsets ~mask ~other:neg_infinity ()
      in
      let row_max = reduce_max row ~mask () in
      let row_minus_max = fsub row (fbroadcast block_size row_max) in
      let numerator = exp row_minus_max in
      let denominator = reduce_sum numerator ~mask () in
      let softmax_output = fdiv numerator (fbroadcast block_size denominator) in
      store ~ptr:out ~offsets:linear_offsets ~values:softmax_output ~mask ();
      trace "leave fused_softmax")

let vector_add_source_text =
  {|
default_handler_stack (fun () ->
  let pid = program_id 0 in
  let offsets =
    iadd
      (ibroadcast BLOCK_SIZE (pid * BLOCK_SIZE))
      (arange 0 BLOCK_SIZE)
  in
  let mask = ilt offsets (ibroadcast BLOCK_SIZE n_elements) in
  let x = load ~ptr:x_ptr ~offsets ~mask ~other:0.0 () in
  let y = load ~ptr:y_ptr ~offsets ~mask ~other:0.0 () in
  let output = fadd x y in
  store ~ptr:output_ptr ~offsets ~values:output ~mask ())
|}

let vector_add_user_scoped_source_text =
  {|
(* Same Triton-like vector-add body, but the user explicitly chooses
   handler scopes as part of the program term. *)
source_to_simd_stack (fun () ->
  let pid = program_id 0 in
  let offsets = pid * BLOCK_SIZE + arange 0 BLOCK_SIZE in
  let mask = offsets < n_elements in
  with_on_chip_memory (fun () ->
    let x = load x_ptr offsets mask in
    let y = load y_ptr offsets mask in
    let output = x + y in
    with_sync_ops (fun () ->
      alloc_local "manual_h5_midpoint";
      barrier "after_vector_fadd";
      wait "after_vector_fadd");
    store output_ptr offsets output mask))
|}

let fused_softmax_source_text =
  {|
default_handler_stack (fun () ->
  let row_idx = program_id 0 in
  let col_offsets = arange 0 BLOCK_SIZE in
  let input_offsets =
    iadd (ibroadcast BLOCK_SIZE (row_idx * n_cols)) col_offsets
  in
  let mask = ilt col_offsets (ibroadcast BLOCK_SIZE n_cols) in
  let row =
    load ~ptr:input_ptr ~offsets:input_offsets ~mask ~other:neg_infinity ()
  in
  let row_minus_max =
    fsub row (fbroadcast BLOCK_SIZE (reduce_max row ~mask ()))
  in
  let numerator = exp row_minus_max in
  let denominator = reduce_sum numerator ~mask () in
  let softmax_output = fdiv numerator (fbroadcast BLOCK_SIZE denominator) in
  store ~ptr:output_ptr ~offsets:input_offsets ~values:softmax_output ~mask ())
|}

let cases () =
  let vector_n = 10 in
  let vector_block = 4 in
  let softmax_rows = 3 in
  let softmax_cols = 5 in
  let softmax_block = 8 in
  [
    {
      id = "vector-add";
      title = "Vector Add";
      source =
        triton_source "Triton-Ascend Vector Addition"
          "https://triton-ascend.readthedocs.io/zh-cn/latest/examples/01_vector_add_example.html"
          "Uses program_id, arange offsets, masked tl.load, and masked tl.store.";
      source_text = vector_add_source_text;
      source_language = "ocaml";
      grid = ceil_div vector_n vector_block;
      inputs =
        [
          ("x", Tensor.of_array1 [| 0.; 1.; 2.; 3.; 4.; 5.; 6.; 7.; 8.; 9. |]);
          ("y", Tensor.of_array1 [| 9.; 8.; 7.; 6.; 5.; 4.; 3.; 2.; 1.; 0. |]);
        ];
      output = "out";
      output_dims = [ vector_n ];
      program =
        vector_add_program ~x:"x" ~y:"y" ~out:"out" ~n_elements:vector_n
          ~block_size:vector_block;
    };
    {
      id = "vector-add-user-scoped";
      title = "Vector Add With User Handler Scopes";
      source =
        triton_source "Triton-Ascend Vector Addition"
          "https://triton-ascend.readthedocs.io/zh-cn/latest/examples/01_vector_add_example.html"
          "Same vector-add computation, but memory/sync lowering scopes are chosen inside the program.";
      source_text = vector_add_user_scoped_source_text;
      source_language = "ocaml";
      grid = ceil_div vector_n vector_block;
      inputs =
        [
          ("x", Tensor.of_array1 [| 0.; 1.; 2.; 3.; 4.; 5.; 6.; 7.; 8.; 9. |]);
          ("y", Tensor.of_array1 [| 9.; 8.; 7.; 6.; 5.; 4.; 3.; 2.; 1.; 0. |]);
        ];
      output = "out";
      output_dims = [ vector_n ];
      program =
        vector_add_user_scoped_program ~x:"x" ~y:"y" ~out:"out"
          ~n_elements:vector_n ~block_size:vector_block;
    };
    {
      id = "fused-softmax";
      title = "Fused Softmax";
      source =
        triton_source "Triton-Ascend Fused Softmax"
          "https://triton-ascend.readthedocs.io/zh-cn/latest/examples/02_fused_softmax_example.html"
          "Uses one program per row, power-of-two block padding, max/exp/sum reductions.";
      source_text = fused_softmax_source_text;
      source_language = "ocaml";
      grid = softmax_rows;
      inputs =
        [
          ( "x",
            Tensor.of_array2
              [|
                [| 1.; 2.; 3.; 4.; 5. |];
                [| 1.; 1.; 2.; 3.; 5. |];
                [| -2.; -1.; 0.; 1.; 2. |];
              |] );
        ];
      output = "out";
      output_dims = [ softmax_rows; softmax_cols ];
      program =
        fused_softmax_program ~x:"x" ~out:"out" ~n_rows:softmax_rows
          ~n_cols:softmax_cols ~block_size:softmax_block;
    };
  ]
