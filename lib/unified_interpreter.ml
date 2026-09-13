open Effect
open Effect.Deep

module Tensor = struct
  type t = { dims : int list; data : float array }

  let product dims = List.fold_left ( * ) 1 dims

  let create dims fill = { dims; data = Array.make (product dims) fill }

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

  let of_array1 xs = { dims = [ Array.length xs ]; data = Array.copy xs }

  let rec offset dims idxs =
    match (dims, idxs) with
    | [], [] -> 0
    | d :: ds, i :: is ->
        if i < 0 || i >= d then invalid_arg "index out of bounds";
        (i * product ds) + offset ds is
    | _ -> invalid_arg "rank mismatch"

  let get t idxs = t.data.(offset t.dims idxs)

  let set t idxs value = t.data.(offset t.dims idxs) <- value

  let copy t = { dims = t.dims; data = Array.copy t.data }

  let equal a b =
    a.dims = b.dims
    && Array.length a.data = Array.length b.data
    && Array.for_all2 (fun x y -> Float.abs (x -. y) < 0.000001) a.data b.data

  let pp_matrix t =
    match t.dims with
    | [ m; n ] ->
        let lines =
          List.init m (fun i ->
              let cells =
                List.init n (fun j -> Printf.sprintf "%6.1f" (get t [ i; j ]))
              in
              "  [" ^ String.concat " " cells ^ " ]")
        in
        String.concat "\n" lines
    | [ n ] ->
        let cells =
          List.init n (fun i -> Printf.sprintf "%6.1f" (get t [ i ]))
        in
        "  [" ^ String.concat " " cells ^ " ]"
    | _ -> "<tensor>"
end

module Effects = struct
  type precision = F32 | F16ish

  type vector_fma = {
    core : int option;
    precision : precision;
    acc : float array;
    a : float array;
    b : float array;
  }

  type vector_max = { core : int option; x : float array; y : float array }

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
  type _ Effect.t += Vector_fma : vector_fma -> float array Effect.t
  type _ Effect.t += Vector_max : vector_max -> float array Effect.t
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

  let vector_fma core precision acc a b =
    perform (Vector_fma { core; precision; acc; a; b })

  let vector_max core x y = perform (Vector_max { core; x; y })

  let alloc_local core name dims = perform (Alloc_local (core, name, dims))

  let read_local core name idx = perform (Read_local (core, name, idx))

  let write_local core name idx value =
    perform (Write_local (core, name, idx, value))

  let async_copy_in plan = perform (Async_copy_in plan)

  let async_copy_out plan = perform (Async_copy_out plan)

  let wait core token = perform (Wait (core, token))

  let barrier core scope = perform (Barrier (core, scope))
end

module Runtime = struct
  open Effects

  type state = {
    global : (string, Tensor.t) Hashtbl.t;
    local : (string, Tensor.t) Hashtbl.t;
    mutable trace : string list;
  }

  let local_key core name = Printf.sprintf "core%d:%s" core name

  let add_trace state msg = state.trace <- msg :: state.trace

  let get_global state name =
    match Hashtbl.find_opt state.global name with
    | Some tensor -> tensor
    | None -> failwith ("unknown global tensor: " ^ name)

  let get_local state core name =
    let key = local_key core name in
    match Hashtbl.find_opt state.local key with
    | Some tensor -> tensor
    | None -> failwith ("unknown local tensor: " ^ key)

  let set_global global name tensor = Hashtbl.replace global name tensor

  let pp_index idx =
    "[" ^ String.concat "," (List.map string_of_int idx) ^ "]"

  let clone_initial () =
    let global = Hashtbl.create 8 in
    set_global global "A"
      (Tensor.of_array2
         [|
           [| 1.; 2.; 3.; 4. |];
           [| 2.; 1.; 0.; 1. |];
           [| 0.; 1.; 2.; 3. |];
           [| 3.; 1.; 1.; 0. |];
         |]);
    set_global global "B"
      (Tensor.of_array2
         [|
           [| 1.; 0.; 2.; 1. |];
           [| 0.; 1.; 1.; 0. |];
           [| 2.; 1.; 0.; 1. |];
           [| 1.; 2.; 1.; 0. |];
         |]);
    set_global global "Bias" (Tensor.of_array1 [| 0.5; -1.; 1.5; 0. |]);
    set_global global "C" (Tensor.create [ 4; 4 ] 0.0);
    { global; local = Hashtbl.create 32; trace = [] }

  let round precision x =
    match precision with
    | F32 -> x
    | F16ish -> Float.round (x *. 1024.0) /. 1024.0

  let pp_core = function None -> "host" | Some core -> Printf.sprintf "core%d" core

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
                    add_trace state
                      (Printf.sprintf "read %s%s = %.1f" name (pp_index idx) value);
                    continue k value)
            | Write_tensor (name, idx, value) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    Tensor.set (get_global state name) idx value;
                    add_trace state
                      (Printf.sprintf "write %s[%s] = %.1f" name
                         (String.concat "," (List.map string_of_int idx)) value);
                    continue k ())
            | Launch_core (core, body) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state (Printf.sprintf "launch core%d" core);
                    run state body;
                    add_trace state (Printf.sprintf "join core%d" core);
                    continue k ())
            | Vector_fma { core; precision; acc; a; b } ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let result =
                      Array.mapi
                        (fun i x -> round precision (x +. (a.(i) *. b.(i))))
                        acc
                    in
                    add_trace state
                      (Printf.sprintf "%s vector.fma width=%d"
                         (pp_core core) (Array.length acc));
                    continue k result)
            | Vector_max { core; x; y } ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let result = Array.mapi (fun i xi -> Float.max xi y.(i)) x in
                    add_trace state
                      (Printf.sprintf "%s vector.max width=%d"
                         (pp_core core) (Array.length x));
                    continue k result)
            | Alloc_local (core, name, dims) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    Hashtbl.replace state.local (local_key core name)
                      (Tensor.create dims 0.0);
                    add_trace state
                      (Printf.sprintf "core%d alloc.local %s" core name);
                    continue k ())
            | Read_local (core, name, idx) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let value = Tensor.get (get_local state core name) idx in
                    continue k value)
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
                    List.iter
                      (fun (local_idx, global_idx) ->
                        Tensor.set dst local_idx (Tensor.get src global_idx))
                      pairs;
                    add_trace state
                      (Printf.sprintf "core%d async.copy %s -> %s (%d cells)" core
                         global local (List.length pairs));
                    continue k ())
            | Async_copy_out { core; local; global; pairs } ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let src = get_local state core local in
                    let dst = get_global state global in
                    List.iter
                      (fun (local_idx, global_idx) ->
                        Tensor.set dst global_idx (Tensor.get src local_idx))
                      pairs;
                    add_trace state
                      (Printf.sprintf "core%d async.copy %s -> %s (%d cells)" core
                         local global (List.length pairs));
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

  let run_program thunk =
    let state = clone_initial () in
    run state thunk;
    state

  let tensor state name = Tensor.copy (get_global state name)

  let same_tensor left left_name right right_name =
    Tensor.equal (tensor left left_name) (tensor right right_name)

  let trace state = List.rev state.trace
end

module Top = struct
  open Effects

  type command =
    | Gemm_bias_relu of {
        a : string;
        b : string;
        bias : string;
        c : string;
        m : int;
        n : int;
        k : int;
      }

  let pp = function
    | Gemm_bias_relu { a; b; bias; c; m; n; k } ->
        Printf.sprintf
          "command %s[%d,%d] = relu(%s[%d,%d] @ %s[%d,%d] + %s[%d])" c m n a m k b
          k n bias n

  let eval = function
    | Gemm_bias_relu { a; b; bias; c; m; n; k } ->
        trace "L0 top-level tensor command";
        for i = 0 to m - 1 do
          for j = 0 to n - 1 do
            let acc = ref (read_tensor bias [ j ]) in
            for kk = 0 to k - 1 do
              acc :=
                !acc
                +. (read_tensor a [ i; kk ] *. read_tensor b [ kk; j ])
            done;
            write_tensor c [ i; j ] (Float.max 0.0 !acc)
          done
        done
end

module Core = struct
  open Effects

  type tile = {
    core : int;
    row_lo : int;
    row_hi : int;
    col_lo : int;
    col_hi : int;
    k : int;
    a : string;
    b : string;
    bias : string;
    c : string;
  }

  type program = tile list

  let pp_tile tile =
    Printf.sprintf
      "core%d computes C[%d:%d, %d:%d] with scalar reduction K=%d" tile.core
      tile.row_lo tile.row_hi tile.col_lo tile.col_hi tile.k

  let pp program = String.concat "\n" (List.map pp_tile program)

  let eval_tile tile =
    for i = tile.row_lo to tile.row_hi - 1 do
      for j = tile.col_lo to tile.col_hi - 1 do
        let acc = ref (read_tensor tile.bias [ j ]) in
        for kk = 0 to tile.k - 1 do
          acc :=
            !acc
            +. (read_tensor tile.a [ i; kk ] *. read_tensor tile.b [ kk; j ])
        done;
        write_tensor tile.c [ i; j ] (Float.max 0.0 !acc)
      done
    done

  let eval program =
    trace "L1 CV-core mapping";
    List.iter (fun tile -> launch_core tile.core (fun () -> eval_tile tile)) program
end

module Vector = struct
  open Effects

  type block = {
    core : int;
    row_lo : int;
    row_hi : int;
    col_lo : int;
    width : int;
    k : int;
    a : string;
    b : string;
    bias : string;
    c : string;
    precision : precision;
  }

  type program = block list

  let pp_block block =
    Printf.sprintf
      "core%d vector block C[%d:%d, %d:%d], width=%d, K=%d" block.core
      block.row_lo block.row_hi block.col_lo
      (block.col_lo + block.width) block.width block.k

  let pp program = String.concat "\n" (List.map pp_block program)

  let eval_block block =
    for i = block.row_lo to block.row_hi - 1 do
      let acc =
        Array.init block.width (fun lane ->
            read_tensor block.bias [ block.col_lo + lane ])
      in
      let acc = ref acc in
      for kk = 0 to block.k - 1 do
        let a_vec =
          Array.make block.width (read_tensor block.a [ i; kk ])
        in
        let b_vec =
          Array.init block.width (fun lane ->
              read_tensor block.b [ kk; block.col_lo + lane ])
        in
        acc := vector_fma (Some block.core) block.precision !acc a_vec b_vec
      done;
      let zeros = Array.make block.width 0.0 in
      let result = vector_max (Some block.core) !acc zeros in
      Array.iteri
        (fun lane value ->
          write_tensor block.c [ i; block.col_lo + lane ] value)
        result
    done

  let eval program =
    trace "L2 SIMD/T vector mapping";
    List.iter (fun block -> launch_core block.core (fun () -> eval_block block)) program
end

module Mem_async = struct
  open Effects

  type block = Vector.block

  type program = block list

  let pp_block block =
    Printf.sprintf
      "core%d async tile: GM(A,B,Bias) -> UB, vector.fma, barrier, UB(C) -> GM"
      block.Vector.core

  let pp program = String.concat "\n" (List.map pp_block program)

  let range n = List.init n Fun.id

  let eval_block block =
    let open Vector in
    launch_core block.core (fun () ->
        alloc_local block.core "A_ub" [ block.row_hi - block.row_lo; block.k ];
        alloc_local block.core "B_ub" [ block.k; block.width ];
        alloc_local block.core "Bias_ub" [ block.width ];
        alloc_local block.core "C_ub" [ block.row_hi - block.row_lo; block.width ];
        let a_pairs =
          List.concat_map
            (fun ri ->
              List.map
                (fun kk ->
                  ([ ri; kk ], [ block.row_lo + ri; kk ]))
                (range block.k))
            (range (block.row_hi - block.row_lo))
        in
        let b_pairs =
          List.concat_map
            (fun kk ->
              List.map
                (fun lane -> ([ kk; lane ], [ kk; block.col_lo + lane ]))
                (range block.width))
            (range block.k)
        in
        let bias_pairs =
          List.map
            (fun lane -> ([ lane ], [ block.col_lo + lane ]))
            (range block.width)
        in
        async_copy_in
          { core = block.core; local = "A_ub"; global = block.a; pairs = a_pairs };
        async_copy_in
          { core = block.core; local = "B_ub"; global = block.b; pairs = b_pairs };
        async_copy_in
          {
            core = block.core;
            local = "Bias_ub";
            global = block.bias;
            pairs = bias_pairs;
          };
        wait block.core "gm_to_ub";
        for ri = 0 to block.row_hi - block.row_lo - 1 do
          let acc =
            Array.init block.width (fun lane ->
                read_local block.core "Bias_ub" [ lane ])
          in
          let acc = ref acc in
          for kk = 0 to block.k - 1 do
            let a_vec =
              Array.make block.width (read_local block.core "A_ub" [ ri; kk ])
            in
            let b_vec =
              Array.init block.width (fun lane ->
                  read_local block.core "B_ub" [ kk; lane ])
            in
            acc := vector_fma (Some block.core) block.precision !acc a_vec b_vec
          done;
          let zeros = Array.make block.width 0.0 in
          let result = vector_max (Some block.core) !acc zeros in
          Array.iteri
            (fun lane value ->
              write_local block.core "C_ub" [ ri; lane ] value)
            result
        done;
        barrier block.core "before_store";
        let c_pairs =
          List.concat_map
            (fun ri ->
              List.map
                (fun lane ->
                  ([ ri; lane ], [ block.row_lo + ri; block.col_lo + lane ]))
                (range block.width))
            (range (block.row_hi - block.row_lo))
        in
        async_copy_out
          { core = block.core; local = "C_ub"; global = block.c; pairs = c_pairs };
        wait block.core "ub_to_gm")

  let eval program =
    trace "L3 on-chip memory plus async mapping";
    List.iter eval_block program
end

module Lowering = struct
  let ceil_div x y = (x + y - 1) / y

  let to_core = function
    | Top.Gemm_bias_relu { a; b; bias; c; m; n; k } ->
        let tile_m = 2 in
        let tile_n = 2 in
        let rows = ceil_div m tile_m in
        let cols = ceil_div n tile_n in
        List.concat
          (List.init rows (fun r ->
               List.init cols (fun col ->
                   let core = (r * cols) + col in
                   {
                     Core.core;
                     row_lo = r * tile_m;
                     row_hi = Int.min m ((r + 1) * tile_m);
                     col_lo = col * tile_n;
                     col_hi = Int.min n ((col + 1) * tile_n);
                     k;
                     a;
                     b;
                     bias;
                     c;
                   })))

  let to_vector core_program =
    List.concat_map
      (fun (tile : Core.tile) ->
        let width = 2 in
        let blocks = ceil_div (tile.col_hi - tile.col_lo) width in
        List.init blocks (fun b ->
            let col_lo = tile.col_lo + (b * width) in
            let actual_width = Int.min width (tile.col_hi - col_lo) in
            {
              Vector.core = tile.core;
              row_lo = tile.row_lo;
              row_hi = tile.row_hi;
              col_lo;
              width = actual_width;
              k = tile.k;
              a = tile.a;
              b = tile.b;
              bias = tile.bias;
              c = tile.c;
              precision = Effects.F32;
            }))
      core_program

  let to_mem_async vector_program = vector_program
end

module Example = struct
  type t = { command : Top.command }

  let make () =
    {
      command =
        Top.Gemm_bias_relu
          { a = "A"; b = "B"; bias = "Bias"; c = "C"; m = 4; n = 4; k = 4 };
    }
end

module Demo = struct
  let section title =
    print_endline "";
    print_endline ("== " ^ title ^ " ==")

  let print_state label state =
    Printf.printf "%s C:\n%s\n" label
      (Tensor.pp_matrix (Runtime.tensor state "C"))

  let print_trace state =
    let trace = Runtime.trace state in
    trace |> List.to_seq |> Seq.take 36 |> List.of_seq
    |> List.iter (fun line -> print_endline ("  " ^ line));
    if List.length trace > 36 then
      Printf.printf "  ... %d more events\n" (List.length trace - 36)

  let run example =
    let core = Lowering.to_core example.Example.command in
    let vector = Lowering.to_vector core in
    let mem_async = Lowering.to_mem_async vector in
    section "L0 source command";
    print_endline (Top.pp example.command);
    section "L1 CV-core mapping IR";
    print_endline (Core.pp core);
    section "L2 SIMD/T vector IR";
    print_endline (Vector.pp vector);
    section "L3 memory/async IR";
    print_endline (Mem_async.pp mem_async);
    section "Execution";
    let top_state = Runtime.run_program (fun () -> Top.eval example.command) in
    let core_state = Runtime.run_program (fun () -> Core.eval core) in
    let vector_state = Runtime.run_program (fun () -> Vector.eval vector) in
    let mem_state = Runtime.run_program (fun () -> Mem_async.eval mem_async) in
    print_state "L0" top_state;
    print_state "L1" core_state;
    print_state "L2" vector_state;
    print_state "L3" mem_state;
    section "Agreement";
    Printf.printf "L0 == L1: %b\n"
      (Runtime.same_tensor top_state "C" core_state "C");
    Printf.printf "L0 == L2: %b\n"
      (Runtime.same_tensor top_state "C" vector_state "C");
    Printf.printf "L0 == L3: %b\n"
      (Runtime.same_tensor top_state "C" mem_state "C");
    section "L3 trace sample";
    print_trace mem_state
end
