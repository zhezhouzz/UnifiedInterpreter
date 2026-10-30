module E = Extracted_semantics.Unified_semantics
module R = Runner

type input = { q : float array; k : float array; v : float array; scale : float }
type output = { o : float array; lse : float array; steps : int; calls : int }

let default_input () =
  let rng = Random.State.make [| 2026; 1013 |] in
  let matrix () = Array.init (128 * 128) (fun _ -> Random.State.float rng 0.5 -. 0.25) in
  let q = matrix () and k = matrix () and v = matrix () in
  {q;k;v;scale = 1. /. sqrt 128.}

let validate_input input =
  List.iter (fun (name,a) ->
    if Array.length a <> 16384 then invalid_arg (name ^ " must contain 128x128 elements");
    if Array.exists (fun x -> not (Float.is_finite x)) a then
      invalid_arg (name ^ " contains non-finite input")) ["Q",input.q;"K",input.k;"V",input.v];
  if not (Float.is_finite input.scale) then invalid_arg "scale must be finite"

let read_file file =
  let ic = open_in file in
  Fun.protect ~finally:(fun () -> close_in ic)
    (fun () -> really_input_string ic (in_channel_length ic))

let run ?stage ?(max_steps=1000000) ?(trace=fun _ -> ()) ~file input =
  validate_input input;
  let program = Parser.parse ~file (read_file file) in
  let abi = Validate.attention_abi ?stage program in
  let state = ref {Handlers.memory = E.empty_memory; marker = 73} in
  let ctx = {R.state; steps=0; max_steps; current=None; pid=0; calls=0; loops=[]; trace} in
  let allocate ty size data =
    (* External input binding uses the extracted memory constructor. Kernel
       allocation, reads and writes go through the Memory effect handler. *)
    match data with
    | Some xs ->
        let allocation,memory = E.allocate_buffer E.ASGM ty (Array.to_list xs) (!state).memory in
        let descriptor = {E.descriptor_allocation=allocation; descriptor_offset=E.Z0;
          descriptor_sizes=[size]; descriptor_strides=[Numeric.z_of_int 1]} in
        let id,memory = E.insert_descriptor descriptor memory in
        state := {!state with memory}; R.Memref (id,[size],ty)
    | None ->
        let id = R.with_handlers ctx (fun () ->
          Handlers.memory "sem_memref_alloc"
            (E.sem_memref_alloc E.ASGM ty [size])) in
        R.Memref (id,[size],ty)
  in
  let q = allocate E.Float16Type 16384 (Some input.q) in
  let k = allocate E.Float16Type 16384 (Some input.k) in
  let v = allocate E.Float16Type 16384 (Some input.v) in
  let lse = allocate abi.lse_type 128 None in
  let o = allocate abi.o_type 16384 None in
  let scratch = allocate E.Float32Type 16384 None in
  let lock = allocate (R.scalar_type "i8") 1 None in
  let workspace = allocate (R.scalar_type "i8") 1 None in
  let int value = R.Int (R.scalar_type "i32",Numeric.z_of_int value) in
  let bindings = [abi.sync_lock,lock; abi.workspace,workspace;
    abi.q,q; abi.k,k; abi.v,v; abi.lse,lse; abi.o,o; abi.scratch,scratch;
    abi.scale,R.Float (E.Float32Type,input.scale);
    abi.grid_x,int 20; abi.grid_y,int 1; abi.grid_z,int 1;
    abi.pid_y,int 0; abi.pid_z,int 0] in
  let bindings = match abi.ffts with
    | None -> bindings
    | Some name -> (name,R.Int (R.scalar_type "i64",E.Z0)) :: bindings in
  R.with_handlers ctx (fun () ->
    for pid = 0 to 19 do
      ctx.pid <- pid;
      let env = (abi.pid_x,int pid) :: bindings in
      ignore (R.execute_block ctx env program.body)
    done);
  ctx.current <- None;
  let read = function
    | R.Memref (id,sh,ty) ->
        let view = E.MemRefBackedTensor (id,sh,ty,
            {E.access_restrict=false; access_writable=false}) in
        let value = R.with_handlers ctx (fun () ->
          Effect.perform (Handlers.Memory ("materialize_output",E.materialize view))) in
        let _,_,xs = Handlers.packed value in Array.of_list xs
    | _ -> assert false
  in
  let o = read o and lse = read lse in
  if (!state).marker <> 73 then failwith "memory lens modified independent state";
  {o;lse;steps=ctx.steps;calls=ctx.calls}

(* Independent mathematical reference: no extracted code or handlers. *)
let reference input =
  validate_input input;
  let o = Array.make 16384 0. and lse = Array.make 128 0. in
  for i = 0 to 127 do
    let scores = Array.init 128 (fun j ->
      let sum = ref 0. in
      for d = 0 to 127 do
        sum := !sum +. input.q.(i*128+d) *. input.k.(j*128+d)
      done;
      !sum *. input.scale) in
    let maximum = Array.fold_left max neg_infinity scores in
    let weights = Array.map (fun x -> exp (x -. maximum)) scores in
    let total = Array.fold_left ( +. ) 0. weights in
    lse.(i) <- maximum +. log total;
    for d = 0 to 127 do
      let sum = ref 0. in
      for j = 0 to 127 do sum := !sum +. weights.(j) *. input.v.(j*128+d) done;
      o.(i*128+d) <- !sum /. total
    done
  done;
  {o;lse;steps=0;calls=0}

let compare_array expected actual =
  if Array.length expected <> Array.length actual then invalid_arg "comparison shape";
  let max_error = ref 0. and passed = ref true in
  Array.iteri (fun i x ->
    let y = actual.(i) in
    let error = abs_float (x -. y) in
    if not (Float.is_finite x && Float.is_finite y) ||
       error > 1e-10 +. 1e-9 *. abs_float x then passed := false;
    max_error := max !max_error error) expected;
  !passed,!max_error
