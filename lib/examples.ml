(* Two sourced Triton-like programs, shallow-embedded in OCaml. *)

open Language
open Effects

let triton_source title url note = { title; url; note }

let vector_add_program ~x ~y ~out ~n_elements ~block_size () =
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
  store ~ptr:out ~offsets ~values:sum ~mask ()

let fused_softmax_program ~x ~out ~n_rows:_ ~n_cols ~block_size () =
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
  store ~ptr:out ~offsets:linear_offsets ~values:softmax_output ~mask ()

let vector_add_source_text =
  {|
@triton.jit
def add_kernel(x_ptr, y_ptr, output_ptr, n_elements, BLOCK_SIZE: tl.constexpr):
    pid = tl.program_id(axis=0)
    offsets = pid * BLOCK_SIZE + tl.arange(0, BLOCK_SIZE)
    mask = offsets < n_elements
    x = tl.load(x_ptr + offsets, mask=mask)
    y = tl.load(y_ptr + offsets, mask=mask)
    output = x + y
    tl.store(output_ptr + offsets, output, mask=mask)
|}

let fused_softmax_source_text =
  {|
@triton.jit
def softmax_kernel(input_ptr, output_ptr, n_rows, n_cols, BLOCK_SIZE: tl.constexpr):
    row_idx = tl.program_id(0)
    col_offsets = tl.arange(0, BLOCK_SIZE)
    input_offsets = row_idx * n_cols + col_offsets
    mask = col_offsets < n_cols
    row = tl.load(input_ptr + input_offsets, mask=mask, other=-float("inf"))
    row_minus_max = row - tl.max(row, axis=0)
    numerator = tl.exp(row_minus_max)
    denominator = tl.sum(numerator, axis=0)
    softmax_output = numerator / denominator
    tl.store(output_ptr + input_offsets, softmax_output, mask=mask)
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
      id = "fused-softmax";
      title = "Fused Softmax";
      source =
        triton_source "Triton-Ascend Fused Softmax"
          "https://triton-ascend.readthedocs.io/zh-cn/latest/examples/02_fused_softmax_example.html"
          "Uses one program per row, power-of-two block padding, max/exp/sum reductions.";
      source_text = fused_softmax_source_text;
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
