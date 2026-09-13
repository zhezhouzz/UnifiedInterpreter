(* Real interpreter: runtime state plus H1-H4 handlers over one unified language. *)

open Effect.Deep
open Language
open Effects

type state = {
  global : (string, Tensor.t) Hashtbl.t;
  mutable trace : string list;
  mutable current_pid : int;
}

let make_state inputs output output_dims =
  let global = Hashtbl.create 16 in
  List.iter
    (fun (name, tensor) -> Hashtbl.replace global name (Tensor.copy tensor))
    inputs;
  Hashtbl.replace global output (Tensor.zeros output_dims);
  { global; trace = []; current_pid = 0 }

let add_trace state msg = state.trace <- msg :: state.trace

let trace state = List.rev state.trace

let tensor state name =
  match Hashtbl.find_opt state.global name with
  | Some tensor -> Tensor.copy tensor
  | None -> failwith ("unknown tensor: " ^ name)

let get_tensor state name =
  match Hashtbl.find_opt state.global name with
  | Some tensor -> tensor
  | None -> failwith ("unknown tensor: " ^ name)

let active mask lane =
  match mask with None -> true | Some mask -> mask.(lane)

let active_count mask =
  match mask with
  | None -> -1
  | Some mask -> Array.fold_left (fun n bit -> if bit then n + 1 else n) 0 mask

let pp_active mask width =
  match active_count mask with
  | -1 -> Printf.sprintf "active=%d/%d" width width
  | n -> Printf.sprintf "active=%d/%d" n width

let round dtype x =
  match dtype with
  | F32 -> x
  | F16ish -> Float.round (x *. 1024.0) /. 1024.0
  | BF16ish -> Float.round (x *. 128.0) /. 128.0

let map2 name lhs rhs f =
  if Array.length lhs <> Array.length rhs then
    invalid_arg (name ^ ": vector width mismatch");
  Array.mapi (fun i x -> f x rhs.(i)) lhs

let eval_int_binop op lhs rhs =
  let f = match op with IAdd -> ( + ) | IMul -> ( * ) in
  map2 (pp_int_binary op) lhs rhs f

let eval_int_cmp op lhs rhs =
  let f = match op with ILt -> ( < ) in
  map2 (pp_int_cmp op) lhs rhs f

let eval_float_binop dtype op lhs rhs =
  let f =
    match op with
    | FAdd -> ( +. )
    | FSub -> ( -. )
    | FMul -> ( *. )
    | FDiv -> ( /. )
  in
  map2 (pp_float_binary op) lhs rhs (fun x y -> round dtype (f x y))

let eval_float_map dtype op values =
  let f =
    match op with
    | Exp -> Float.exp
    | Sqrt -> Float.sqrt
    | Relu -> fun x -> Float.max 0.0 x
  in
  Array.map (fun x -> round dtype (f x)) values

let eval_reduce dtype op values mask =
  let values =
    Array.to_list (Array.mapi (fun i value -> (i, value)) values)
    |> List.filter_map (fun (i, value) ->
           if active mask i then Some value else None)
  in
  match (op, values) with
  | Max, [] -> neg_infinity
  | Max, x :: xs -> List.fold_left Float.max x xs
  | Sum, xs -> List.fold_left (fun acc x -> round dtype (acc +. x)) 0.0 xs

let eval_load state { ptr; offsets; mask; other } =
  let tensor = get_tensor state ptr in
  Array.mapi
    (fun lane offset ->
      if active mask lane then Tensor.get_linear tensor offset else other)
    offsets

let eval_store state { ptr; offsets; values; mask } =
  let tensor = get_tensor state ptr in
  Array.iteri
    (fun lane offset ->
      if active mask lane then Tensor.set_linear tensor offset values.(lane))
    offsets

module H1 = struct
  let name = "H1/source"

  let run state thunk =
    match_with thunk ()
      {
        retc = Fun.id;
        exnc = raise;
        effc =
          (fun (type a) (eff : a Effect.t) ->
            match eff with
            | Trace msg ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state msg;
                    continue k ())
            | Program_id axis ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H1 program_id(axis=%d) -> %d" axis
                         state.current_pid);
                    continue k state.current_pid)
            | Arange (start, stop) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let values = Array.init (stop - start) (fun i -> start + i) in
                    add_trace state
                      (Printf.sprintf "H1 arange(%d,%d) width=%d" start stop
                         (Array.length values));
                    continue k values)
            | Int_binop (op, lhs, rhs) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H1 %s width=%d" (pp_int_binary op)
                         (Array.length lhs));
                    continue k (eval_int_binop op lhs rhs))
            | Int_cmp (op, lhs, rhs) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H1 %s width=%d" (pp_int_cmp op)
                         (Array.length lhs));
                    continue k (eval_int_cmp op lhs rhs))
            | Load load ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H1 load %s width=%d %s" load.ptr
                         (Array.length load.offsets)
                         (pp_active load.mask (Array.length load.offsets)));
                    continue k (eval_load state load))
            | Store store ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H1 store %s width=%d %s" store.ptr
                         (Array.length store.offsets)
                         (pp_active store.mask (Array.length store.offsets)));
                    eval_store state store;
                    continue k ())
            | Float_binop (op, lhs, rhs, dtype) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H1 %s width=%d dtype=%s"
                         (pp_float_binary op) (Array.length lhs) (pp_dtype dtype));
                    continue k (eval_float_binop dtype op lhs rhs))
            | Float_map (op, values, dtype) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H1 %s width=%d dtype=%s"
                         (pp_elementwise op) (Array.length values)
                         (pp_dtype dtype));
                    continue k (eval_float_map dtype op values))
            | Reduce (op, values, mask, dtype) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H1 reduce.%s width=%d %s dtype=%s"
                         (pp_reduction op) (Array.length values)
                         (pp_active mask (Array.length values))
                         (pp_dtype dtype));
                    continue k (eval_reduce dtype op values mask))
            | Alloc_local (core, name, cells) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H1 observe alloc.local core%d %s[%d]" core
                         name cells);
                    continue k ())
            | Async_copy_in copy ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H1 observe async.copy.in core%d %s -> %s"
                         copy.core copy.global copy.local);
                    continue k ())
            | Async_copy_out copy ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H1 observe async.copy.out core%d %s -> %s"
                         copy.core copy.local copy.global);
                    continue k ())
            | Wait (core, token) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H1 observe wait core%d %s" core token);
                    continue k ())
            | Barrier (core, scope) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H1 observe barrier core%d %s" core scope);
                    continue k ())
            | _ -> None);
      }
end

module H2 = struct
  let name = "H2/core"

  let run state thunk =
    match_with thunk ()
      {
        retc = Fun.id;
        exnc = raise;
        effc =
          (fun (type a) (eff : a Effect.t) ->
            match eff with
            | Program_id axis ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf
                         "H2 bind program_id(axis=%d) to logical core %d" axis
                         state.current_pid);
                    continue k state.current_pid)
            | _ -> None);
      }
end

module H3 = struct
  let name = "H3/vector"

  let run state thunk =
    match_with thunk ()
      {
        retc = Fun.id;
        exnc = raise;
        effc =
          (fun (type a) (eff : a Effect.t) ->
            match eff with
            | Arange (start, stop) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let values = Array.init (stop - start) (fun i -> start + i) in
                    add_trace state
                      (Printf.sprintf "H3 vector.arange(%d,%d) width=%d" start
                         stop (Array.length values));
                    continue k values)
            | Int_binop (op, lhs, rhs) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H3 vector.%s width=%d" (pp_int_binary op)
                         (Array.length lhs));
                    continue k (eval_int_binop op lhs rhs))
            | Int_cmp (op, lhs, rhs) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let result = eval_int_cmp op lhs rhs in
                    add_trace state
                      (Printf.sprintf "H3 vector.%s width=%d active=%d"
                         (pp_int_cmp op) (Array.length lhs)
                         (Array.fold_left
                            (fun n bit -> if bit then n + 1 else n)
                            0 result));
                    continue k result)
            | Float_binop (op, lhs, rhs, dtype) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H3 vector.%s width=%d dtype=%s"
                         (pp_float_binary op) (Array.length lhs)
                         (pp_dtype dtype));
                    continue k (eval_float_binop dtype op lhs rhs))
            | Float_map (op, values, dtype) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H3 vector.%s width=%d dtype=%s"
                         (pp_elementwise op) (Array.length values)
                         (pp_dtype dtype));
                    continue k (eval_float_map dtype op values))
            | Reduce (op, values, mask, dtype) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H3 vector.reduce.%s width=%d %s dtype=%s"
                         (pp_reduction op) (Array.length values)
                         (pp_active mask (Array.length values))
                         (pp_dtype dtype));
                    continue k (eval_reduce dtype op values mask))
            | _ -> None);
      }
end

module H4 = struct
  let name = "H4/memory-async"

  let run state thunk =
    match_with thunk ()
      {
        retc = Fun.id;
        exnc = raise;
        effc =
          (fun (type a) (eff : a Effect.t) ->
            match eff with
            | Load load ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let core = state.current_pid in
                    let local = load.ptr ^ "_ub" in
                    let width = Array.length load.offsets in
                    add_trace state
                      (Printf.sprintf
                         "H4 lower load %s: alloc.local %s[%d], async.copy.in, wait"
                         load.ptr local width);
                    alloc_local core local width;
                    async_copy_in
                      { core; global = load.ptr; local; offsets = load.offsets; mask = load.mask };
                    wait core "gm_to_ub";
                    continue k (eval_load state load))
            | Store store ->
                Some
                  (fun (k : (a, _) continuation) ->
                    let core = state.current_pid in
                    let local = store.ptr ^ "_ub" in
                    let width = Array.length store.offsets in
                    add_trace state
                      (Printf.sprintf
                         "H4 lower store %s: alloc.local %s[%d], barrier, async.copy.out"
                         store.ptr local width);
                    alloc_local core local width;
                    barrier core "before_store";
                    async_copy_out
                      { core; global = store.ptr; local; offsets = store.offsets; mask = store.mask };
                    wait core "ub_to_gm";
                    eval_store state store;
                    continue k ())
            | Alloc_local (core, name, cells) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H4 alloc.local core%d %s[%d]" core name
                         cells);
                    continue k ())
            | Async_copy_in copy ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H4 async.copy.in core%d %s -> %s %s"
                         copy.core copy.global copy.local
                         (pp_active copy.mask (Array.length copy.offsets)));
                    continue k ())
            | Async_copy_out copy ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H4 async.copy.out core%d %s -> %s %s"
                         copy.core copy.local copy.global
                         (pp_active copy.mask (Array.length copy.offsets)));
                    continue k ())
            | Wait (core, token) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state (Printf.sprintf "H4 wait core%d %s" core token);
                    continue k ())
            | Barrier (core, scope) ->
                Some
                  (fun (k : (a, _) continuation) ->
                    add_trace state
                      (Printf.sprintf "H4 barrier core%d %s" core scope);
                    continue k ())
            | _ -> None);
      }
end

type scope =
  | Only_H1
  | H1_H2
  | H1_H3
  | H1_H4
  | H1_H4_H3

let pp_scope = function
  | Only_H1 -> "H1 { program }"
  | H1_H2 -> "H1 { H2 { program } }"
  | H1_H3 -> "H1 { H3 { program } }"
  | H1_H4 -> "H1 { H4 { program } }"
  | H1_H4_H3 -> "H1 { H4 { H3 { program } } }"

let run_scope state scope program =
  match scope with
  | Only_H1 -> H1.run state program
  | H1_H2 -> H1.run state (fun () -> H2.run state program)
  | H1_H3 -> H1.run state (fun () -> H3.run state program)
  | H1_H4 -> H1.run state (fun () -> H4.run state program)
  | H1_H4_H3 ->
      H1.run state (fun () -> H4.run state (fun () -> H3.run state program))

let run_case scope (case : case) =
  let state = make_state case.inputs case.output case.output_dims in
  add_trace state (Printf.sprintf "run %s over grid=%d" (pp_scope scope) case.grid);
  for pid = 0 to case.grid - 1 do
    state.current_pid <- pid;
    add_trace state (Printf.sprintf "launch logical program/core %d" pid);
    run_scope state scope case.program;
    add_trace state (Printf.sprintf "join logical program/core %d" pid)
  done;
  state

let run_program thunk =
  let state = make_state [] "out" [ 0 ] in
  run_scope state Only_H1 thunk;
  state

let same_tensor left left_name right right_name =
  Tensor.equal (tensor left left_name) (tensor right right_name)
