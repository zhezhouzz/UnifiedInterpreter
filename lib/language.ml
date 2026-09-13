(* Language definition: datatypes for the source command and lowered IR levels. *)

type dtype = F32 | F16ish | BF16ish

let pp_dtype = function F32 -> "f32" | F16ish -> "f16ish" | BF16ish -> "bf16ish"

type binary = Add | Mul

type reduction = Max | Sum

type elementwise = Exp | Sqrt | Relu

  type top_command =
    | Vector_add of { x : string; y : string; out : string; n : int; block : int }
    | Fused_softmax of { x : string; out : string; rows : int; cols : int; block : int }
    | Layer_norm of {
        x : string;
        weight : string;
        bias : string;
        out : string;
        rows : int;
        cols : int;
        eps : float;
        dtype : dtype;
      }
    | Matmul_bias of {
        a : string;
        b : string;
        z : string;
        out : string;
        m : int;
        n : int;
        k : int;
        block_m : int;
        block_n : int;
      }
    | Toy_transpose_mul of { a : string; b : string; out : string; rows : int; cols : int }

  type core_task =
    | Core_vector_add of { core : int; x : string; y : string; out : string; start : int; block : int; n : int }
    | Core_row_softmax of { core : int; x : string; out : string; row : int; cols : int; block : int }
    | Core_row_layer_norm of {
        core : int;
        x : string;
        weight : string;
        bias : string;
        out : string;
        row : int;
        cols : int;
        eps : float;
        dtype : dtype;
      }
    | Core_matmul_tile of {
        core : int;
        a : string;
        b : string;
        z : string;
        out : string;
        row_lo : int;
        row_hi : int;
        col_lo : int;
        col_hi : int;
        k : int;
      }
    | Core_toy_transpose_mul of { core : int; a : string; b : string; out : string; rows : int; cols : int }

  type core_program = core_task list

  type vector_task =
    | Vec_vector_add of { core : int; x : string; y : string; out : string; start : int; width : int; n : int }
    | Vec_row_softmax of { core : int; x : string; out : string; row : int; cols : int; width : int }
    | Vec_row_layer_norm of {
        core : int;
        x : string;
        weight : string;
        bias : string;
        out : string;
        row : int;
        cols : int;
        dtype : dtype;
        eps : float;
      }
    | Vec_matmul_tile of {
        core : int;
        a : string;
        b : string;
        z : string;
        out : string;
        row_lo : int;
        row_hi : int;
        col_lo : int;
        width : int;
        k : int;
      }
    | Vec_toy_transpose_mul of { core : int; a : string; b : string; out : string; rows : int; cols : int }

  type vector_program = vector_task list

  type mem_async_program = vector_program

  let pp_top = function
    | Vector_add { x; y; out; n; block } ->
        Printf.sprintf "%s[0:%d] = %s + %s, BLOCK_SIZE=%d" out n x y block
    | Fused_softmax { x; out; rows; cols; block } ->
        Printf.sprintf "%s[%d,%d] = row_softmax(%s), padded BLOCK_SIZE=%d" out rows cols x block
    | Layer_norm { x; weight; bias; out; rows; cols; eps; dtype } ->
        Printf.sprintf "%s[%d,%d] = layer_norm(%s,%s,%s,eps=%g,dtype=%s)" out rows cols x weight bias eps
          (pp_dtype dtype)
    | Matmul_bias { a; b; z; out; m; n; k; block_m; block_n } ->
        Printf.sprintf "%s[%d,%d] = %s[%d,%d] @ %s[%d,%d] + %s, BLOCK_M=%d, BLOCK_N=%d" out m n a m k b k n
          z block_m block_n
    | Toy_transpose_mul { a; b; out; rows; cols } ->
        Printf.sprintf "%s[%d,%d] = transpose(%s[%d,%d]) * transpose(%s[%d,%d])" out cols rows a rows cols b rows cols

  let pp_core_task = function
    | Core_vector_add { core; start; block; n; _ } ->
        Printf.sprintf "core%d: vector-add offsets [%d:%d) masked by n=%d" core start (start + block) n
    | Core_row_softmax { core; row; cols; block; _ } ->
        Printf.sprintf "core%d: softmax row %d, cols=%d padded-block=%d" core row cols block
    | Core_row_layer_norm { core; row; cols; dtype; _ } ->
        Printf.sprintf "core%d: layernorm row %d, cols=%d, accumulation=%s" core row cols (pp_dtype dtype)
    | Core_matmul_tile { core; row_lo; row_hi; col_lo; col_hi; k; _ } ->
        Printf.sprintf "core%d: matmul tile C[%d:%d,%d:%d], K=%d" core row_lo row_hi col_lo col_hi k
    | Core_toy_transpose_mul { core; rows; cols; _ } ->
        Printf.sprintf "core%d: partially lowered toy.transpose + toy.mul over %dx%d" core rows cols

  let pp_core program = String.concat "\n" (List.map pp_core_task program)

  let pp_vector_task = function
    | Vec_vector_add { core; start; width; n; _ } ->
        Printf.sprintf "core%d: vector.add width=%d offsets [%d:%d), mask < %d" core width start (start + width) n
    | Vec_row_softmax { core; row; cols; width; _ } ->
        Printf.sprintf "core%d: vector softmax row=%d width=%d valid-cols=%d" core row width cols
    | Vec_row_layer_norm { core; row; cols; dtype; _ } ->
        Printf.sprintf "core%d: vector layernorm row=%d cols=%d dtype=%s" core row cols (pp_dtype dtype)
    | Vec_matmul_tile { core; row_lo; row_hi; col_lo; width; k; _ } ->
        Printf.sprintf "core%d: vector dot C[%d:%d,%d:%d], width=%d, K=%d" core row_lo row_hi col_lo (col_lo + width) width k
    | Vec_toy_transpose_mul { core; rows; cols; _ } ->
        Printf.sprintf "core%d: memref/vector form for transpose+mul over %dx%d" core rows cols

  let pp_vector program = String.concat "\n" (List.map pp_vector_task program)

  let pp_mem_task = function
    | Vec_vector_add { core; start; width; _ } ->
        Printf.sprintf "core%d: GM(x,y) -> UB, vector.add [%d:%d), UB(out) -> GM" core start (start + width)
    | Vec_row_softmax { core; row; _ } ->
        Printf.sprintf "core%d: GM(row%d) -> UB, max/exp/sum, UB(out) -> GM" core row
    | Vec_row_layer_norm { core; row; dtype; _ } ->
        Printf.sprintf "core%d: GM(row%d,gamma,beta) -> UB, mean/var %s, store" core row (pp_dtype dtype)
    | Vec_matmul_tile { core; row_lo; row_hi; col_lo; width; _ } ->
        Printf.sprintf "core%d: GM(A,B,Z) -> UB tile C[%d:%d,%d:%d], dot, barrier, store" core row_lo row_hi col_lo
          (col_lo + width)
    | Vec_toy_transpose_mul { core; _ } ->
        Printf.sprintf "core%d: tensor-to-memref alloc/copy, affine loop, store" core

  let pp_mem program = String.concat "\n" (List.map pp_mem_task program)
