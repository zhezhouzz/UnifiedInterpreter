(* Lowering passes between the language levels defined in [Language]. *)

open Language

  let ceil_div x y = (x + y - 1) / y

  let range n = List.init n Fun.id

  let to_core = function
    | Vector_add { x; y; out; n; block } ->
        range (ceil_div n block)
        |> List.map (fun core ->
               Core_vector_add { core; x; y; out; start = core * block; block; n })
    | Fused_softmax { x; out; rows; cols; block } ->
        range rows
        |> List.map (fun row ->
               Core_row_softmax { core = row; x; out; row; cols; block })
    | Layer_norm { x; weight; bias; out; rows; cols; eps; dtype } ->
        range rows
        |> List.map (fun row ->
               Core_row_layer_norm { core = row; x; weight; bias; out; row; cols; eps; dtype })
    | Matmul_bias { a; b; z; out; m; n; k; block_m; block_n } ->
        let row_tiles = ceil_div m block_m in
        let col_tiles = ceil_div n block_n in
        List.concat
          (range row_tiles
          |> List.map (fun rt ->
                 range col_tiles
                 |> List.map (fun ct ->
                        let core = (rt * col_tiles) + ct in
                        Core_matmul_tile
                          {
                            core;
                            a;
                            b;
                            z;
                            out;
                            row_lo = rt * block_m;
                            row_hi = Int.min m ((rt + 1) * block_m);
                            col_lo = ct * block_n;
                            col_hi = Int.min n ((ct + 1) * block_n);
                            k;
                          })))
    | Toy_transpose_mul { a; b; out; rows; cols } ->
        [ Core_toy_transpose_mul { core = 0; a; b; out; rows; cols } ]

  let to_vector core_program =
    List.concat_map
      (function
        | Core_vector_add { core; x; y; out; start; block; n } ->
            [ Vec_vector_add { core; x; y; out; start; width = block; n } ]
        | Core_row_softmax { core; x; out; row; cols; block } ->
            [ Vec_row_softmax { core; x; out; row; cols; width = block } ]
        | Core_row_layer_norm { core; x; weight; bias; out; row; cols; eps; dtype } ->
            [ Vec_row_layer_norm { core; x; weight; bias; out; row; cols; dtype; eps } ]
        | Core_matmul_tile { core; a; b; z; out; row_lo; row_hi; col_lo; col_hi; k } ->
            [
              Vec_matmul_tile
                { core; a; b; z; out; row_lo; row_hi; col_lo; width = col_hi - col_lo; k };
            ]
        | Core_toy_transpose_mul { core; a; b; out; rows; cols } ->
            [ Vec_toy_transpose_mul { core; a; b; out; rows; cols } ])
      core_program

  let to_mem_async vector_program = vector_program
