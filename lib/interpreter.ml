(* True interpreter: effect handlers plus evaluators for each IR level. *)

open Effect.Deep

  open Effects

  type state = {
    global : (string, Tensor.t) Hashtbl.t;
    local : (string, Tensor.t) Hashtbl.t;
    mutable trace : string list;
  }

  let local_key core name = Printf.sprintf "core%d:%s" core name

  let add_trace state msg = state.trace <- msg :: state.trace

  let set_global global name tensor = Hashtbl.replace global name (Tensor.copy tensor)

  let make_state inputs output output_dims =
    let global = Hashtbl.create 16 in
    List.iter (fun (name, tensor) -> set_global global name tensor) inputs;
    Hashtbl.replace global output (Tensor.zeros output_dims);
    { global; local = Hashtbl.create 64; trace = [] }

  let get_global state name =
    match Hashtbl.find_opt state.global name with Some t -> t | None -> failwith ("unknown global tensor: " ^ name)

  let get_local state core name =
    match Hashtbl.find_opt state.local (local_key core name) with
    | Some t -> t
    | None -> failwith ("unknown local tensor: " ^ local_key core name)

  let round dtype x =
    match dtype with
    | F32 -> x
    | F16ish -> Float.round (x *. 1024.0) /. 1024.0
    | BF16ish -> Float.round (x *. 128.0) /. 128.0

  let pp_core = function None -> "host" | Some core -> Printf.sprintf "core%d" core

  let active_count mask = Array.fold_left (fun n b -> if b then n + 1 else n) 0 mask

  let valid_values values mask =
    match mask with
    | None -> Array.to_list values
    | Some mask ->
        Array.to_list (Array.mapi (fun i x -> (mask.(i), x)) values)
        |> List.filter_map (fun (keep, x) -> if keep then Some x else None)

  let map_masked2 dtype op lhs rhs mask =
    Array.mapi
      (fun i x ->
        let active = Option.fold ~none:true ~some:(fun m -> m.(i)) mask in
        if active then round dtype (op x rhs.(i)) else x)
      lhs

  let rec run state thunk =
    match_with thunk ()
      {
        retc = (fun value -> value);
        exnc = raise;
        effc =
          (fun (type a) (eff : a Effect.t) ->
            match eff with
            | Trace msg ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state msg;
                    continue k ())
            | Read_tensor (name, idx) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let value = Tensor.get (get_global state name) idx in
                    add_trace state (Printf.sprintf "read %s%s = %.4f" name (Tensor.pp_index idx) value);
                    continue k value)
            | Write_tensor (name, idx, value) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    Tensor.set (get_global state name) idx value;
                    add_trace state (Printf.sprintf "write %s%s = %.4f" name (Tensor.pp_index idx) value);
                    continue k ())
            | Launch_core (core, body) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state (Printf.sprintf "launch program_id/core%d" core);
                    run state body;
                    add_trace state (Printf.sprintf "join core%d" core);
                    continue k ())
            | Masked_load (name, indices, mask, other) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let tensor = get_global state name in
                    let values = Array.mapi (fun i idx -> if mask.(i) then Tensor.get tensor idx else other) indices in
                    add_trace state
                      (Printf.sprintf "masked.load %s lanes=%d active=%d" name (Array.length mask) (active_count mask));
                    continue k values)
            | Masked_store (name, indices, mask, values) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let tensor = get_global state name in
                    Array.iteri (fun i idx -> if mask.(i) then Tensor.set tensor idx values.(i)) indices;
                    add_trace state
                      (Printf.sprintf "masked.store %s lanes=%d active=%d" name (Array.length mask) (active_count mask));
                    continue k ())
            | Vector_binop { core; op; lhs; rhs; mask; dtype } ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let f = match op with Add -> ( +. ) | Mul -> ( *. ) in
                    let result = map_masked2 dtype f lhs rhs mask in
                    let opname = match op with Add -> "vector.add" | Mul -> "vector.mul" in
                    add_trace state
                      (Printf.sprintf "%s %s width=%d dtype=%s" (pp_core core) opname (Array.length lhs) (pp_dtype dtype));
                    continue k result)
            | Vector_fma { core; acc; a; b; mask; dtype } ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let result =
                      Array.mapi
                        (fun i x ->
                          let active = Option.fold ~none:true ~some:(fun m -> m.(i)) mask in
                          if active then round dtype (x +. (a.(i) *. b.(i))) else x)
                        acc
                    in
                    add_trace state
                      (Printf.sprintf "%s vector.fma width=%d dtype=%s" (pp_core core) (Array.length acc) (pp_dtype dtype));
                    continue k result)
            | Vector_reduce { core; op; values; mask; dtype } ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let valid = valid_values values mask in
                    let value =
                      match (op, valid) with
                      | Max, [] -> neg_infinity
                      | Max, x :: xs -> List.fold_left Float.max x xs
                      | Sum, xs -> List.fold_left (fun acc x -> round dtype (acc +. x)) 0.0 xs
                    in
                    let opname = match op with Max -> "vector.reduce.max" | Sum -> "vector.reduce.sum" in
                    add_trace state
                      (Printf.sprintf "%s %s lanes=%d active=%d dtype=%s" (pp_core core) opname (Array.length values)
                         (List.length valid) (pp_dtype dtype));
                    continue k value)
            | Vector_map { core; op; values; dtype } ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let f = match op with Exp -> Float.exp | Sqrt -> Float.sqrt | Relu -> fun x -> Float.max 0.0 x in
                    let result = Array.map (fun x -> round dtype (f x)) values in
                    let opname = match op with Exp -> "vector.exp" | Sqrt -> "vector.sqrt" | Relu -> "vector.relu" in
                    add_trace state
                      (Printf.sprintf "%s %s width=%d dtype=%s" (pp_core core) opname (Array.length values) (pp_dtype dtype));
                    continue k result)
            | Cast (from_dtype, to_dtype, value) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let result = round to_dtype value in
                    add_trace state
                      (Printf.sprintf "cast %s -> %s %.6f -> %.6f" (pp_dtype from_dtype) (pp_dtype to_dtype) value result);
                    continue k result)
            | Alloc_local (core, name, dims) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    Hashtbl.replace state.local (local_key core name) (Tensor.zeros dims);
                    add_trace state (Printf.sprintf "core%d alloc.local %s%s" core name (Tensor.pp_dims dims));
                    continue k ())
            | Read_local (core, name, idx) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    continue k (Tensor.get (get_local state core name) idx))
            | Write_local (core, name, idx, value) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    Tensor.set (get_local state core name) idx value;
                    continue k ())
            | Async_copy_in { core; local; global; pairs } ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let src = get_global state global in
                    let dst = get_local state core local in
                    List.iter (fun (local_idx, global_idx) -> Tensor.set dst local_idx (Tensor.get src global_idx)) pairs;
                    add_trace state
                      (Printf.sprintf "core%d async.copy %s -> %s (%d cells)" core global local (List.length pairs));
                    continue k ())
            | Async_copy_out { core; local; global; pairs } ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let src = get_local state core local in
                    let dst = get_global state global in
                    List.iter (fun (local_idx, global_idx) -> Tensor.set dst global_idx (Tensor.get src local_idx)) pairs;
                    add_trace state
                      (Printf.sprintf "core%d async.copy %s -> %s (%d cells)" core local global (List.length pairs));
                    continue k ())
            | Wait (core, token) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state (Printf.sprintf "core%d wait %s" core token);
                    continue k ())
            | Barrier (core, scope) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state (Printf.sprintf "core%d barrier %s" core scope);
                    continue k ())
            | _ -> None);
      }

  let trace state = List.rev state.trace

  let tensor state name = Tensor.copy (get_global state name)

module Eval = struct
  open Effects
  open Language

  let mask start width n = Array.init width (fun lane -> start + lane < n)

  let vector_indices_1 start width = Array.init width (fun lane -> [ start + lane ])

  let row_indices row width = Array.init width (fun lane -> [ row; lane ])

  let top_output_dims = function
    | Vector_add { n; _ } -> [ n ]
    | Fused_softmax { rows; cols; _ } -> [ rows; cols ]
    | Layer_norm { rows; cols; _ } -> [ rows; cols ]
    | Matmul_bias { m; n; _ } -> [ m; n ]
    | Toy_transpose_mul { rows; cols; _ } -> [ cols; rows ]

  let run_case (case : Examples.case) eval_program program =
    let state = make_state case.inputs case.output (top_output_dims case.command) in
    run state (fun () -> eval_program program);
    state

  let eval_top = function
    | Vector_add { x; y; out; n; _ } ->
        trace "L0 top: Triton-style vector add command";
        for i = 0 to n - 1 do
          write_tensor out [ i ] (read_tensor x [ i ] +. read_tensor y [ i ])
        done
    | Fused_softmax { x; out; rows; cols; _ } ->
        trace "L0 top: row-wise fused softmax";
        for row = 0 to rows - 1 do
          let max_v = ref neg_infinity in
          for col = 0 to cols - 1 do
            max_v := Float.max !max_v (read_tensor x [ row; col ])
          done;
          let denom = ref 0.0 in
          for col = 0 to cols - 1 do
            denom := !denom +. Float.exp (read_tensor x [ row; col ] -. !max_v)
          done;
          for col = 0 to cols - 1 do
            write_tensor out [ row; col ]
              (Float.exp (read_tensor x [ row; col ] -. !max_v) /. !denom)
          done
        done
    | Layer_norm { x; weight; bias; out; rows; cols; eps; dtype } ->
        trace "L0 top: layer normalization with dtype-sensitive accumulation";
        for row = 0 to rows - 1 do
          let sum = ref 0.0 in
          for col = 0 to cols - 1 do
            sum := !sum +. cast F32 dtype (read_tensor x [ row; col ])
          done;
          let mean = !sum /. float cols in
          let var_sum = ref 0.0 in
          for col = 0 to cols - 1 do
            let centered = cast F32 dtype (read_tensor x [ row; col ] -. mean) in
            var_sum := !var_sum +. (centered *. centered)
          done;
          let inv_std = 1.0 /. Float.sqrt ((!var_sum /. float cols) +. eps) in
          for col = 0 to cols - 1 do
            let normalized = (read_tensor x [ row; col ] -. mean) *. inv_std in
            write_tensor out [ row; col ]
              ((normalized *. read_tensor weight [ col ]) +. read_tensor bias [ col ])
          done
        done
    | Matmul_bias { a; b; z; out; m; n; k; _ } ->
        trace "L0 top: matmul plus bias";
        for i = 0 to m - 1 do
          for j = 0 to n - 1 do
            let acc = ref (read_tensor z [ j ]) in
            for kk = 0 to k - 1 do
              acc := !acc +. (read_tensor a [ i; kk ] *. read_tensor b [ kk; j ])
            done;
            write_tensor out [ i; j ] !acc
          done
        done
    | Toy_transpose_mul { a; b; out; rows; cols } ->
        trace "L0 top: MLIR Toy transpose(a) * transpose(b)";
        for i = 0 to rows - 1 do
          for j = 0 to cols - 1 do
            write_tensor out [ j; i ] (read_tensor a [ i; j ] *. read_tensor b [ i; j ])
          done
        done

  let eval_core_task = function
    | Core_vector_add { core; x; y; out; start; block; n } ->
        launch_core core (fun () ->
            for lane = 0 to block - 1 do
              let i = start + lane in
              if i < n then write_tensor out [ i ] (read_tensor x [ i ] +. read_tensor y [ i ])
              else trace (Printf.sprintf "core%d skip masked lane offset=%d" core i)
            done)
    | Core_row_softmax { core; x; out; row; cols; block } ->
        launch_core core (fun () ->
            trace (Printf.sprintf "core%d row program with padded block=%d" core block);
            let values = Array.init cols (fun col -> read_tensor x [ row; col ]) in
            let max_v = Array.fold_left Float.max neg_infinity values in
            let exps = Array.map (fun v -> Float.exp (v -. max_v)) values in
            let denom = Array.fold_left ( +. ) 0.0 exps in
            Array.iteri (fun col v -> write_tensor out [ row; col ] (v /. denom)) exps)
    | Core_row_layer_norm { core; x; weight; bias; out; row; cols; eps; dtype } ->
        launch_core core (fun () ->
            trace (Printf.sprintf "core%d layernorm row program dtype=%s" core (pp_dtype dtype));
            let values = Array.init cols (fun col -> read_tensor x [ row; col ]) in
            let mean = Array.fold_left ( +. ) 0.0 values /. float cols in
            let var =
              Array.fold_left (fun acc v -> acc +. ((v -. mean) *. (v -. mean))) 0.0 values
              /. float cols
            in
            let inv_std = 1.0 /. Float.sqrt (var +. eps) in
            for col = 0 to cols - 1 do
              write_tensor out [ row; col ]
                (((values.(col) -. mean) *. inv_std *. read_tensor weight [ col ])
                +. read_tensor bias [ col ])
            done)
    | Core_matmul_tile { core; a; b; z; out; row_lo; row_hi; col_lo; col_hi; k } ->
        launch_core core (fun () ->
            for i = row_lo to row_hi - 1 do
              for j = col_lo to col_hi - 1 do
                let acc = ref (read_tensor z [ j ]) in
                for kk = 0 to k - 1 do
                  acc := !acc +. (read_tensor a [ i; kk ] *. read_tensor b [ kk; j ])
                done;
                write_tensor out [ i; j ] !acc
              done
            done)
    | Core_toy_transpose_mul { core; a; b; out; rows; cols } ->
        launch_core core (fun () ->
            trace "partial lowering keeps transpose/mul semantics but exposes memref loop order";
            for i = 0 to rows - 1 do
              for j = 0 to cols - 1 do
                write_tensor out [ j; i ] (read_tensor a [ i; j ] *. read_tensor b [ i; j ])
              done
            done)

  let eval_core program =
    trace "L1 core/program mapping";
    List.iter eval_core_task program

  let eval_vector_task = function
    | Vec_vector_add { core; x; y; out; start; width; n } ->
        launch_core core (fun () ->
            let mask = mask start width n in
            let indices = vector_indices_1 start width in
            let xs = masked_load x indices mask 0.0 in
            let ys = masked_load y indices mask 0.0 in
            let zs = vector_binop (Some core) Add xs ys (Some mask) F32 in
            masked_store out indices mask zs)
    | Vec_row_softmax { core; x; out; row; cols; width } ->
        launch_core core (fun () ->
            let mask = Array.init width (fun lane -> lane < cols) in
            let indices = row_indices row width in
            let vals = masked_load x indices mask neg_infinity in
            let max_v = vector_reduce (Some core) Max vals (Some mask) F32 in
            let shifted = Array.map (fun v -> v -. max_v) vals in
            let exp_vals = vector_map (Some core) Exp shifted F32 in
            let denom = vector_reduce (Some core) Sum exp_vals (Some mask) F32 in
            let result = Array.mapi (fun i v -> if mask.(i) then v /. denom else 0.0) exp_vals in
            masked_store out indices mask result)
    | Vec_row_layer_norm { core; x; weight; bias; out; row; cols; dtype; eps } ->
        launch_core core (fun () ->
            let all = Array.make cols true in
            let indices = row_indices row cols in
            let vals = masked_load x indices all 0.0 in
            let sum = vector_reduce (Some core) Sum vals (Some all) dtype in
            let mean = sum /. float cols in
            let centered = Array.map (fun v -> v -. mean) vals in
            let sq = vector_binop (Some core) Mul centered centered (Some all) dtype in
            let var = vector_reduce (Some core) Sum sq (Some all) dtype /. float cols in
            let inv_std = 1.0 /. (vector_map (Some core) Sqrt [| var +. eps |] dtype).(0) in
            let normalized = Array.map (fun v -> (v -. mean) *. inv_std) vals in
            let gamma = masked_load weight (vector_indices_1 0 cols) all 0.0 in
            let beta = masked_load bias (vector_indices_1 0 cols) all 0.0 in
            let scaled = vector_binop (Some core) Mul normalized gamma (Some all) dtype in
            let result = vector_binop (Some core) Add scaled beta (Some all) F32 in
            masked_store out indices all result)
    | Vec_matmul_tile { core; a; b; z; out; row_lo; row_hi; col_lo; width; k } ->
        launch_core core (fun () ->
            for i = row_lo to row_hi - 1 do
              let acc = Array.init width (fun lane -> read_tensor z [ col_lo + lane ]) in
              let acc = ref acc in
              for kk = 0 to k - 1 do
                let a_vec = Array.make width (read_tensor a [ i; kk ]) in
                let b_vec = Array.init width (fun lane -> read_tensor b [ kk; col_lo + lane ]) in
                acc := vector_fma (Some core) !acc a_vec b_vec None F32
              done;
              Array.iteri (fun lane value -> write_tensor out [ i; col_lo + lane ] value) !acc
            done)
    | Vec_toy_transpose_mul { core; a; b; out; rows; cols } ->
        launch_core core (fun () ->
            trace "tensor-to-memref partial lowering: affine loop order i,j stores transposed indices";
            for i = 0 to rows - 1 do
              let lhs = Array.init cols (fun j -> read_tensor a [ i; j ]) in
              let rhs = Array.init cols (fun j -> read_tensor b [ i; j ]) in
              let product = vector_binop (Some core) Mul lhs rhs None F32 in
              Array.iteri (fun j v -> write_tensor out [ j; i ] v) product
            done)

  let eval_vector program =
    trace "L2 SIMD/T vector mapping";
    List.iter eval_vector_task program

  let pairs_1 start width n =
    List.init width (fun lane -> ([ lane ], [ start + lane ]))
    |> List.filter (function _, [ i ] -> i < n | _ -> true)

  let eval_mem_task = function
    | Vec_vector_add { core; x; y; out; start; width; n } ->
        launch_core core (fun () ->
            let active = Int.min width (Int.max 0 (n - start)) in
            let pairs = pairs_1 start width n in
            alloc_local core "x_ub" [ active ];
            alloc_local core "y_ub" [ active ];
            alloc_local core "out_ub" [ active ];
            async_copy_in { core; local = "x_ub"; global = x; pairs };
            async_copy_in { core; local = "y_ub"; global = y; pairs };
            wait core "gm_to_ub";
            let lhs = Array.init active (fun i -> read_local core "x_ub" [ i ]) in
            let rhs = Array.init active (fun i -> read_local core "y_ub" [ i ]) in
            let result = vector_binop (Some core) Add lhs rhs None F32 in
            Array.iteri (fun i v -> write_local core "out_ub" [ i ] v) result;
            barrier core "before_store";
            async_copy_out { core; local = "out_ub"; global = out; pairs };
            wait core "ub_to_gm")
    | Vec_row_softmax { core; x; out; row; cols; width } ->
        launch_core core (fun () ->
            let mask = Array.init width (fun lane -> lane < cols) in
            alloc_local core "row_ub" [ width ];
            alloc_local core "out_ub" [ width ];
            let pairs = List.init cols (fun col -> ([ col ], [ row; col ])) in
            async_copy_in { core; local = "row_ub"; global = x; pairs };
            wait core "gm_to_ub";
            let vals =
              Array.init width (fun lane ->
                  if mask.(lane) then read_local core "row_ub" [ lane ] else neg_infinity)
            in
            let max_v = vector_reduce (Some core) Max vals (Some mask) F32 in
            let exps = vector_map (Some core) Exp (Array.map (fun v -> v -. max_v) vals) F32 in
            let denom = vector_reduce (Some core) Sum exps (Some mask) F32 in
            Array.iteri
              (fun lane v -> if mask.(lane) then write_local core "out_ub" [ lane ] (v /. denom))
              exps;
            barrier core "before_store";
            async_copy_out { core; local = "out_ub"; global = out; pairs };
            wait core "ub_to_gm")
    | Vec_row_layer_norm { core; x; weight; bias; out; row; cols; dtype; eps } ->
        launch_core core (fun () ->
            let all = Array.make cols true in
            alloc_local core "x_ub" [ cols ];
            alloc_local core "weight_ub" [ cols ];
            alloc_local core "bias_ub" [ cols ];
            alloc_local core "out_ub" [ cols ];
            let row_pairs = List.init cols (fun col -> ([ col ], [ row; col ])) in
            let vec_pairs = List.init cols (fun col -> ([ col ], [ col ])) in
            async_copy_in { core; local = "x_ub"; global = x; pairs = row_pairs };
            async_copy_in { core; local = "weight_ub"; global = weight; pairs = vec_pairs };
            async_copy_in { core; local = "bias_ub"; global = bias; pairs = vec_pairs };
            wait core "gm_to_ub";
            let vals = Array.init cols (fun col -> read_local core "x_ub" [ col ]) in
            let mean = vector_reduce (Some core) Sum vals (Some all) dtype /. float cols in
            let centered = Array.map (fun v -> v -. mean) vals in
            let sq = vector_binop (Some core) Mul centered centered (Some all) dtype in
            let var = vector_reduce (Some core) Sum sq (Some all) dtype /. float cols in
            let inv_std = 1.0 /. (vector_map (Some core) Sqrt [| var +. eps |] dtype).(0) in
            for col = 0 to cols - 1 do
              let normalized = (vals.(col) -. mean) *. inv_std in
              let result =
                (normalized *. read_local core "weight_ub" [ col ])
                +. read_local core "bias_ub" [ col ]
              in
              write_local core "out_ub" [ col ] result
            done;
            barrier core "before_store";
            async_copy_out { core; local = "out_ub"; global = out; pairs = row_pairs };
            wait core "ub_to_gm")
    | Vec_matmul_tile { core; a; b; z; out; row_lo; row_hi; col_lo; width; k } ->
        launch_core core (fun () ->
            let rows = row_hi - row_lo in
            alloc_local core "a_ub" [ rows; k ];
            alloc_local core "b_ub" [ k; width ];
            alloc_local core "z_ub" [ width ];
            alloc_local core "out_ub" [ rows; width ];
            let a_pairs =
              List.concat (List.init rows (fun ri -> List.init k (fun kk -> ([ ri; kk ], [ row_lo + ri; kk ]))))
            in
            let b_pairs =
              List.concat (List.init k (fun kk -> List.init width (fun lane -> ([ kk; lane ], [ kk; col_lo + lane ]))))
            in
            let z_pairs = List.init width (fun lane -> ([ lane ], [ col_lo + lane ])) in
            async_copy_in { core; local = "a_ub"; global = a; pairs = a_pairs };
            async_copy_in { core; local = "b_ub"; global = b; pairs = b_pairs };
            async_copy_in { core; local = "z_ub"; global = z; pairs = z_pairs };
            wait core "gm_to_ub";
            for ri = 0 to rows - 1 do
              let acc = Array.init width (fun lane -> read_local core "z_ub" [ lane ]) in
              let acc = ref acc in
              for kk = 0 to k - 1 do
                let avec = Array.make width (read_local core "a_ub" [ ri; kk ]) in
                let bvec = Array.init width (fun lane -> read_local core "b_ub" [ kk; lane ]) in
                acc := vector_fma (Some core) !acc avec bvec None F32
              done;
              Array.iteri (fun lane value -> write_local core "out_ub" [ ri; lane ] value) !acc
            done;
            barrier core "before_store";
            let out_pairs =
              List.concat
                (List.init rows (fun ri ->
                     List.init width (fun lane -> ([ ri; lane ], [ row_lo + ri; col_lo + lane ]))))
            in
            async_copy_out { core; local = "out_ub"; global = out; pairs = out_pairs };
            wait core "ub_to_gm")
    | Vec_toy_transpose_mul { core; a; b; out; rows; cols } ->
        launch_core core (fun () ->
            alloc_local core "a_memref" [ rows; cols ];
            alloc_local core "b_memref" [ rows; cols ];
            alloc_local core "out_memref" [ cols; rows ];
            let pairs = List.concat (List.init rows (fun i -> List.init cols (fun j -> ([ i; j ], [ i; j ])))) in
            async_copy_in { core; local = "a_memref"; global = a; pairs };
            async_copy_in { core; local = "b_memref"; global = b; pairs };
            wait core "tensor_to_memref";
            for i = 0 to rows - 1 do
              let lhs = Array.init cols (fun j -> read_local core "a_memref" [ i; j ]) in
              let rhs = Array.init cols (fun j -> read_local core "b_memref" [ i; j ]) in
              let result = vector_binop (Some core) Mul lhs rhs None F32 in
              Array.iteri (fun j v -> write_local core "out_memref" [ j; i ] v) result
            done;
            barrier core "after_affine_loop";
            let out_pairs = List.concat (List.init cols (fun i -> List.init rows (fun j -> ([ i; j ], [ i; j ])))) in
            async_copy_out { core; local = "out_memref"; global = out; pairs = out_pairs };
            wait core "memref_to_tensor")

  let eval_mem_async program =
    trace "L3 memory/async mapping";
    List.iter eval_mem_task program
end
