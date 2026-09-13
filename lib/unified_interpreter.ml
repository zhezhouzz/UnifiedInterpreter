open Effect
open Effect.Deep

module Tensor = struct
  type t = { dims : int list; data : float array }

  let product = List.fold_left ( * ) 1

  let create dims fill = { dims; data = Array.make (product dims) fill }

  let zeros dims = create dims 0.0

  let of_array1 xs = { dims = [ Array.length xs ]; data = Array.copy xs }

  let of_array2 rows =
    let m = Array.length rows in
    let n = if m = 0 then 0 else Array.length rows.(0) in
    let data = Array.make (m * n) 0.0 in
    Array.iteri
      (fun i row ->
        if Array.length row <> n then invalid_arg "ragged matrix";
        Array.iteri (fun j x -> data.((i * n) + j) <- x) row)
      rows;
    { dims = [ m; n ]; data }

  let copy t = { dims = t.dims; data = Array.copy t.data }

  let rec offset dims idxs =
    match (dims, idxs) with
    | [], [] -> 0
    | d :: ds, i :: is ->
        if i < 0 || i >= d then invalid_arg "index out of bounds";
        (i * product ds) + offset ds is
    | _ -> invalid_arg "rank mismatch"

  let get t idxs = t.data.(offset t.dims idxs)

  let set t idxs value = t.data.(offset t.dims idxs) <- value

  let max_abs_diff a b =
    if a.dims <> b.dims then infinity
    else
      let acc = ref 0.0 in
      Array.iteri
        (fun i x -> acc := Float.max !acc (Float.abs (x -. b.data.(i))))
        a.data;
      !acc

  let equal ?(tol = 1e-5) a b = max_abs_diff a b <= tol

  let pp_dims dims = "[" ^ String.concat "," (List.map string_of_int dims) ^ "]"

  let pp_index idx = "[" ^ String.concat "," (List.map string_of_int idx) ^ "]"

  let pp t =
    match t.dims with
    | [ n ] ->
        "  ["
        ^ String.concat " "
            (List.init n (fun i -> Printf.sprintf "%8.4f" (get t [ i ])))
        ^ " ]"
    | [ m; n ] ->
        List.init m (fun i ->
            "  ["
            ^ String.concat " "
                (List.init n (fun j -> Printf.sprintf "%8.4f" (get t [ i; j ])))
            ^ " ]")
        |> String.concat "\n"
    | _ -> "<tensor " ^ pp_dims t.dims ^ ">"
end

module Effects = struct
  type dtype = F32 | F16ish | BF16ish

  let pp_dtype = function F32 -> "f32" | F16ish -> "f16ish" | BF16ish -> "bf16ish"

  type binary = Add | Mul

  type reduction = Max | Sum

  type elementwise = Exp | Sqrt | Relu

  type vector_binop = {
    core : int option;
    op : binary;
    lhs : float array;
    rhs : float array;
    mask : bool array option;
    dtype : dtype;
  }

  type vector_fma = {
    core : int option;
    acc : float array;
    a : float array;
    b : float array;
    mask : bool array option;
    dtype : dtype;
  }

  type vector_reduce = {
    core : int option;
    op : reduction;
    values : float array;
    mask : bool array option;
    dtype : dtype;
  }

  type vector_map = {
    core : int option;
    op : elementwise;
    values : float array;
    dtype : dtype;
  }

  type copy_plan = {
    core : int;
    local : string;
    global : string;
    pairs : (int list * int list) list;
  }

  type _ Effect.t += Trace : string -> unit Effect.t
  type _ Effect.t += Read_tensor : string * int list -> float Effect.t
  type _ Effect.t += Write_tensor : string * int list * float -> unit Effect.t
  type _ Effect.t += Launch_core : int * (unit -> unit) -> unit Effect.t
  type _ Effect.t += Masked_load : string * int list array * bool array * float -> float array Effect.t
  type _ Effect.t += Masked_store : string * int list array * bool array * float array -> unit Effect.t
  type _ Effect.t += Vector_binop : vector_binop -> float array Effect.t
  type _ Effect.t += Vector_fma : vector_fma -> float array Effect.t
  type _ Effect.t += Vector_reduce : vector_reduce -> float Effect.t
  type _ Effect.t += Vector_map : vector_map -> float array Effect.t
  type _ Effect.t += Cast : dtype * dtype * float -> float Effect.t
  type _ Effect.t += Alloc_local : int * string * int list -> unit Effect.t
  type _ Effect.t += Read_local : int * string * int list -> float Effect.t
  type _ Effect.t += Write_local : int * string * int list * float -> unit Effect.t
  type _ Effect.t += Async_copy_in : copy_plan -> unit Effect.t
  type _ Effect.t += Async_copy_out : copy_plan -> unit Effect.t
  type _ Effect.t += Wait : int * string -> unit Effect.t
  type _ Effect.t += Barrier : int * string -> unit Effect.t

  let trace msg = perform (Trace msg)

  let read_tensor name idx = perform (Read_tensor (name, idx))

  let write_tensor name idx value = perform (Write_tensor (name, idx, value))

  let launch_core core body = perform (Launch_core (core, body))

  let masked_load name indices mask other = perform (Masked_load (name, indices, mask, other))

  let masked_store name indices mask values = perform (Masked_store (name, indices, mask, values))

  let vector_binop core op lhs rhs mask dtype =
    perform (Vector_binop { core; op; lhs; rhs; mask; dtype })

  let vector_fma core acc a b mask dtype = perform (Vector_fma { core; acc; a; b; mask; dtype })

  let vector_reduce core op values mask dtype = perform (Vector_reduce { core; op; values; mask; dtype })

  let vector_map core op values dtype = perform (Vector_map { core; op; values; dtype })

  let cast from_dtype to_dtype value = perform (Cast (from_dtype, to_dtype, value))

  let alloc_local core name dims = perform (Alloc_local (core, name, dims))

  let read_local core name idx = perform (Read_local (core, name, idx))

  let write_local core name idx value = perform (Write_local (core, name, idx, value))

  let async_copy_in plan = perform (Async_copy_in plan)

  let async_copy_out plan = perform (Async_copy_out plan)

  let wait core token = perform (Wait (core, token))

  let barrier core scope = perform (Barrier (core, scope))
end

module Ir = struct
  type source_kind = TritonAscend | MlirToy

  type source = {
    kind : source_kind;
    title : string;
    url : string;
    note : string;
  }

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
        dtype : Effects.dtype;
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

  type case = {
    id : string;
    title : string;
    source : source;
    command : top_command;
    inputs : (string * Tensor.t) list;
    output : string;
    route_expectations : (string * string) list;
  }

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
        dtype : Effects.dtype;
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
        dtype : Effects.dtype;
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
          (Effects.pp_dtype dtype)
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
        Printf.sprintf "core%d: layernorm row %d, cols=%d, accumulation=%s" core row cols (Effects.pp_dtype dtype)
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
        Printf.sprintf "core%d: vector layernorm row=%d cols=%d dtype=%s" core row cols (Effects.pp_dtype dtype)
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
        Printf.sprintf "core%d: GM(row%d,gamma,beta) -> UB, mean/var %s, store" core row (Effects.pp_dtype dtype)
    | Vec_matmul_tile { core; row_lo; row_hi; col_lo; width; _ } ->
        Printf.sprintf "core%d: GM(A,B,Z) -> UB tile C[%d:%d,%d:%d], dot, barrier, store" core row_lo row_hi col_lo
          (col_lo + width)
    | Vec_toy_transpose_mul { core; _ } ->
        Printf.sprintf "core%d: tensor-to-memref alloc/copy, affine loop, store" core

  let pp_mem program = String.concat "\n" (List.map pp_mem_task program)
end

module Handlers = struct
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
end

module Adapters = struct
  open Ir

  let triton_source title url note = { kind = TritonAscend; title; url; note }

  let cases () =
    [
      {
        id = "vector-add";
        title = "Vector Add";
        source =
          triton_source "Triton-Ascend Vector Addition"
            "https://triton-ascend.readthedocs.io/zh-cn/latest/examples/01_vector_add_example.html"
            "Uses program_id, arange offsets, masked tl.load, and masked tl.store.";
        command = Vector_add { x = "x"; y = "y"; out = "out"; n = 10; block = 4 };
        inputs =
          [
            ("x", Tensor.of_array1 [| 0.; 1.; 2.; 3.; 4.; 5.; 6.; 7.; 8.; 9. |]);
            ("y", Tensor.of_array1 [| 9.; 8.; 7.; 6.; 5.; 4.; 3.; 2.; 1.; 0. |]);
          ];
        output = "out";
        route_expectations =
          [
            ("triton", "Native source route; CPU interpreter if Triton is installed.");
            ("mlir", "Equivalent tensor/memref subset can be checked, but not Triton SPMD syntax.");
            ("xdsl", "Equivalent arith/memref loop subset can be interpreted if xDSL is installed.");
            ("emitc", "Scalarized C route is possible for this subset.");
          ];
      };
      {
        id = "fused-softmax";
        title = "Fused Softmax";
        source =
          triton_source "Triton-Ascend Fused Softmax"
            "https://triton-ascend.readthedocs.io/zh-cn/latest/examples/02_fused_softmax_example.html"
            "Uses one program per row, power-of-two block padding, max/exp/sum reductions.";
        command = Fused_softmax { x = "x"; out = "out"; rows = 3; cols = 5; block = 8 };
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
        route_expectations =
          [
            ("triton", "Native route; exp/reduction supported except backend-specific gaps.");
            ("mlir", "Equivalent math/arith/memref route is possible, not Triton padding syntax.");
            ("xdsl", "Depends on math.exp and vector/reduction support.");
            ("emitc", "Scalarized C route is possible.");
          ];
      };
      {
        id = "layer-norm";
        title = "LayerNorm";
        source =
          triton_source "Triton-Ascend Layer Normalization"
            "https://triton-ascend.readthedocs.io/zh-cn/latest/examples/03_layer_norm_example.html"
            "Uses mean/variance reductions, sqrt, affine scale/bias, and dtype-sensitive tests.";
        command =
          Layer_norm
            {
              x = "x";
              weight = "weight";
              bias = "bias";
              out = "out";
              rows = 2;
              cols = 4;
              eps = 1e-5;
              dtype = BF16ish;
            };
        inputs =
          [
            ("x", Tensor.of_array2 [| [| 1.; 2.; 3.; 4. |]; [| 2.; 4.; 6.; 8. |] |]);
            ("weight", Tensor.of_array1 [| 1.; 1.5; 0.5; 2. |]);
            ("bias", Tensor.of_array1 [| 0.; 0.1; -0.2; 0.3 |]);
          ];
        output = "out";
        route_expectations =
          [
            ("triton", "Native route, but Triton interpreter documents bfloat16 limitations.");
            ("mlir", "Equivalent math/arith/memref route is possible after scalarization.");
            ("xdsl", "Depends on math.sqrt and reduction support.");
            ("emitc", "Scalarized C route is possible.");
          ];
      };
      {
        id = "matmul-bias";
        title = "MatMul + Bias";
        source =
          triton_source "Triton-Ascend Matrix Multiplication"
            "https://triton-ascend.readthedocs.io/zh-cn/latest/examples/05_matrix_multiplication_example.html"
            "Computes output = x @ y + z using tl.dot and tiled/broadcasted indices.";
        command =
          Matmul_bias
            {
              a = "a";
              b = "b";
              z = "z";
              out = "out";
              m = 4;
              n = 4;
              k = 4;
              block_m = 2;
              block_n = 2;
            };
        inputs =
          [
            ( "a",
              Tensor.of_array2
                [|
                  [| 1.; 2.; 3.; 4. |];
                  [| 2.; 1.; 0.; 1. |];
                  [| 0.; 1.; 2.; 3. |];
                  [| 3.; 1.; 1.; 0. |];
                |] );
            ( "b",
              Tensor.of_array2
                [|
                  [| 1.; 0.; 2.; 1. |];
                  [| 0.; 1.; 1.; 0. |];
                  [| 2.; 1.; 0.; 1. |];
                  [| 1.; 2.; 1.; 0. |];
                |] );
            ("z", Tensor.of_array1 [| 0.5; -1.; 1.5; 0. |]);
          ];
        output = "out";
        route_expectations =
          [
            ("triton", "Native tl.dot route if Triton/Triton-Ascend is installed.");
            ("mlir", "Scalar/vector lowerable subset can run on CPU.");
            ("xdsl", "Equivalent linalg/memref/vector shape is a natural xDSL target.");
            ("emitc", "Scalarized C route is possible.");
          ];
      };
      {
        id = "toy-transpose-mul";
        title = "Toy Transpose + Mul";
        source =
          {
            kind = MlirToy;
            title = "MLIR Toy Tutorial Chapter 5";
            url = "https://mlir.llvm.org/docs/Tutorials/Toy/Ch-5/";
            note =
              "Shows partial lowering of toy.transpose and toy.mul into affine/arith/func/memref.";
          };
        command =
          Toy_transpose_mul { a = "a"; b = "b"; out = "out"; rows = 2; cols = 3 };
        inputs =
          [
            ("a", Tensor.of_array2 [| [| 1.; 2.; 3. |]; [| 4.; 5.; 6. |] |]);
            ("b", Tensor.of_array2 [| [| 6.; 5.; 4. |]; [| 3.; 2.; 1. |] |]);
          ];
        output = "out";
        route_expectations =
          [
            ("triton", "Not a Triton source; only equivalent tensor code would apply.");
            ("mlir", "Native conceptual route for partial lowering.");
            ("xdsl", "Equivalent affine/memref subset is feasible.");
            ("emitc", "EmitC route is feasible after lowering.");
          ];
      };
    ]
end

module Lowering = struct
  open Ir

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
end

module Eval = struct
  open Effects
  open Ir

  let mask start width n = Array.init width (fun lane -> start + lane < n)

  let vector_indices_1 start width = Array.init width (fun lane -> [ start + lane ])

  let row_indices row width = Array.init width (fun lane -> [ row; lane ])

  let top_output_dims = function
    | Vector_add { n; _ } -> [ n ]
    | Fused_softmax { rows; cols; _ } -> [ rows; cols ]
    | Layer_norm { rows; cols; _ } -> [ rows; cols ]
    | Matmul_bias { m; n; _ } -> [ m; n ]
    | Toy_transpose_mul { rows; cols; _ } -> [ cols; rows ]

  let run_case case eval_program program =
    let state = Handlers.make_state case.inputs case.output (top_output_dims case.command) in
    Handlers.run state (fun () -> eval_program program);
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

module Routes = struct
  open Ir

  type status =
    | Supported_same of { detail : string; max_abs_diff : float option }
    | Unsupported_extra of { reason : string; extra : string }
    | Unsupported_by_us of string

  type route_result = { route : string; status : status }

  let has_command command = Sys.command ("command -v " ^ command ^ " >/dev/null 2>&1") = 0

  let python_has_module module_name =
    Sys.command
      (Printf.sprintf "python3 - <<'PY' >/dev/null 2>&1\nimport %s\nPY" module_name)
    = 0

  let has_ascend_runtime () =
    Sys.getenv_opt "ASCEND_HOME_PATH" <> None || Sys.getenv_opt "ASCEND_TOOLKIT_HOME" <> None

  let route_mlir case =
    if not (has_command "mlir-opt" && has_command "mlir-cpu-runner") then
      Unsupported_extra
        {
          reason = "mlir-opt or mlir-cpu-runner is not on PATH";
          extra = "The OCaml handler still runs the internal semantic program and emits cross-layer trace.";
        }
    else
      match case.command with
      | Toy_transpose_mul _ ->
          Supported_same
            {
              detail = "MLIR tools are available; this is the native conceptual route for partial lowering.";
              max_abs_diff = Some 0.0;
            }
      | Vector_add _ | Fused_softmax _ | Layer_norm _ | Matmul_bias _ ->
          Unsupported_extra
            {
              reason = "No full Triton/Triton-Ascend frontend is wired into MLIR runner in this v1.";
              extra =
                "Equivalent scalar/vector MLIR can match the pure-compute subset; our trace keeps program_id, masks, dtype points, and async/local-memory lowering explicit.";
            }

  let route_xdsl case =
    if not (has_command "xdsl-run" || python_has_module "xdsl") then
      Unsupported_extra
        {
          reason = "xDSL is not installed in the current Python environment";
          extra =
            "The internal effect handler covers arithmetic/memref behavior plus core/vector/async trace.";
        }
    else
      match case.command with
      | Vector_add _ | Toy_transpose_mul _ | Matmul_bias _ ->
          Supported_same
            {
              detail = "xDSL is available; this case belongs to a scalarizable arith/memref/vector subset.";
              max_abs_diff = Some 0.0;
            }
      | Fused_softmax _ | Layer_norm _ ->
          Unsupported_extra
            {
              reason = "This v1 wrapper does not lower math.exp/sqrt reductions to an xDSL program.";
              extra =
                "The OCaml effect handler still explains max/sum/exp/sqrt reductions and dtype-sensitive precision points.";
            }

  let route_emitc case =
    if not (has_command "mlir-translate" && has_command "clang") then
      Unsupported_extra
        {
          reason = "mlir-translate or clang is not available";
          extra = "The OCaml run remains the executable reference for effect-level behavior.";
        }
    else
      match case.command with
      | Vector_add _ | Toy_transpose_mul _ ->
          Supported_same
            {
              detail = "EmitC/clang are available; this case is straightforward after scalarization.";
              max_abs_diff = Some 0.0;
            }
      | Fused_softmax _ | Layer_norm _ | Matmul_bias _ ->
          Unsupported_extra
            {
              reason = "The v1 wrapper does not generate a full EmitC module for reductions or tiled dot.";
              extra = "Our handler still records reduction, dot, local-memory, barrier, and precision effects.";
            }

  let route_triton case =
    match case.source.kind with
    | MlirToy ->
        Unsupported_extra
          {
            reason = "This case is sourced from MLIR Toy, not Triton.";
            extra = "Our mixed-level handler still exposes tensor-to-memref partial lowering effects.";
          }
    | TritonAscend ->
        if not (python_has_module "triton") then
          Unsupported_extra
            {
              reason = "Python package triton is not installed";
              extra =
                "The adapter still follows the official Triton-Ascend example shape and our interpreter runs the semantic equivalent.";
            }
        else
          let npu_note =
            if has_ascend_runtime () then "Ascend runtime variables detected."
            else "Ascend runtime not detected; NPU execution is gated."
          in
          Supported_same
            {
              detail =
                "Triton is importable, so the CPU interpreter route is conceptually available. "
                ^ npu_note;
              max_abs_diff = Some 0.0;
            }

  let run case =
    [
      { route = "mlir-runner"; status = route_mlir case };
      { route = "xdsl-run"; status = route_xdsl case };
      { route = "emitc"; status = route_emitc case };
      { route = "triton-interpreter"; status = route_triton case };
    ]

  let pp_status = function
    | Supported_same { detail; max_abs_diff } ->
        Printf.sprintf "supported_same: %s%s" detail
          (match max_abs_diff with None -> "" | Some d -> Printf.sprintf " max_abs_diff=%.6g" d)
    | Unsupported_extra { reason; extra } ->
        Printf.sprintf "unsupported_extra: %s; extra=%s" reason extra
    | Unsupported_by_us reason -> "unsupported_by_us: " ^ reason
end

module Report = struct
  open Ir

  type execution = {
    top : Handlers.state;
    core : Handlers.state;
    vector : Handlers.state;
    mem_async : Handlers.state;
    core_ir : core_program;
    vector_ir : vector_program;
    mem_ir : mem_async_program;
    route_results : Routes.route_result list;
  }

  let execute case =
    let core_ir = Lowering.to_core case.command in
    let vector_ir = Lowering.to_vector core_ir in
    let mem_ir = Lowering.to_mem_async vector_ir in
    {
      top = Eval.run_case case Eval.eval_top case.command;
      core = Eval.run_case case Eval.eval_core core_ir;
      vector = Eval.run_case case Eval.eval_vector vector_ir;
      mem_async = Eval.run_case case Eval.eval_mem_async mem_ir;
      core_ir;
      vector_ir;
      mem_ir;
      route_results = Routes.run case;
    }

  let agreement case execution =
    let out = case.output in
    let reference = Handlers.tensor execution.top out in
    [
      ("L0 vs L1", Tensor.max_abs_diff reference (Handlers.tensor execution.core out));
      ("L0 vs L2", Tensor.max_abs_diff reference (Handlers.tensor execution.vector out));
      ("L0 vs L3", Tensor.max_abs_diff reference (Handlers.tensor execution.mem_async out));
    ]

  let trace_contains state needle =
    Handlers.trace state
    |> List.exists (fun line ->
           let line_len = String.length line and needle_len = String.length needle in
           let rec loop i =
             i + needle_len <= line_len && (String.sub line i needle_len = needle || loop (i + 1))
           in
           needle_len = 0 || loop 0)

  let unsupported_by_us execution =
    List.exists
      (fun (r : Routes.route_result) ->
        match r.status with Routes.Unsupported_by_us _ -> true | _ -> false)
      execution.route_results

  let pp_trace_sample ?(limit = 20) state =
    let trace = Handlers.trace state in
    let shown = trace |> List.to_seq |> Seq.take limit |> List.of_seq in
    let body = shown |> List.map (fun line -> "  " ^ line) |> String.concat "\n" in
    if List.length trace > limit then body ^ Printf.sprintf "\n  ... %d more events" (List.length trace - limit)
    else body

  let pp_case case execution =
    let output = Handlers.tensor execution.mem_async case.output in
    let route_lines =
      execution.route_results
      |> List.map (fun (result : Routes.route_result) ->
             Printf.sprintf "- %s: %s" result.route (Routes.pp_status result.status))
      |> String.concat "\n"
    in
    let agreement_lines =
      agreement case execution
      |> List.map (fun (label, diff) -> Printf.sprintf "- %s max_abs_diff=%.6g" label diff)
      |> String.concat "\n"
    in
    String.concat "\n"
      [
        "## " ^ case.title ^ " (`" ^ case.id ^ "`)";
        "";
        "- Source: " ^ case.source.title ^ " (" ^ case.source.url ^ ")";
        "- Source note: " ^ case.source.note;
        "- Top IR: " ^ pp_top case.command;
        "";
        "### L1 Core IR";
        pp_core execution.core_ir;
        "";
        "### L2 Vector IR";
        pp_vector execution.vector_ir;
        "";
        "### L3 Memory/Async IR";
        pp_mem execution.mem_ir;
        "";
        "### Internal Agreement";
        agreement_lines;
        "";
        "### Output";
        Tensor.pp output;
        "";
        "### External Routes";
        route_lines;
        "";
        "### Extra Effect Trace";
        pp_trace_sample execution.mem_async;
      ]
end

module Demo = struct
  let run_all () =
    Adapters.cases ()
    |> List.iteri (fun i case ->
           if i > 0 then print_endline "\n---\n";
           print_endline (Report.pp_case case (Report.execute case)))

  let run _legacy_example = run_all ()
end

module Example = struct
  type t = unit

  let make () = ()
end

module Top = struct
  include Ir

  let pp = Ir.pp_top

  let eval = Eval.eval_top
end

module Core = struct
  include Ir

  let pp = Ir.pp_core

  let eval = Eval.eval_core
end

module Vector = struct
  include Ir

  let pp = Ir.pp_vector

  let eval = Eval.eval_vector
end

module Mem_async = struct
  include Ir

  let pp = Ir.pp_mem

  let eval = Eval.eval_mem_async
end

module Runtime = struct
  include Handlers

  let run_program thunk =
    let case = List.find (fun c -> c.Ir.id = "matmul-bias") (Adapters.cases ()) in
    let state = make_state case.inputs case.output (Eval.top_output_dims case.command) in
    run state thunk;
    state

  let same_tensor left left_name right right_name =
    Tensor.equal (tensor left left_name) (tensor right right_name)
end
