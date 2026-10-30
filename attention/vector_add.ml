module E = Extracted_semantics.Unified_semantics
module R = Runner
open Parser

let run ?stage ?(max_steps=1000000) ?(trace=ignore) ~file a b =
  if max_steps <= 0 then invalid_arg "max_steps must be positive";
  let n = Array.length a in
  if n <> Array.length b || n > 2147483647 then invalid_arg "invalid vector-add input lengths";
  if Array.exists (fun x -> not (Float.is_finite x)) a ||
     Array.exists (fun x -> not (Float.is_finite x)) b then invalid_arg "non-finite vector-add input";
  let program = Parser.parse ~file (Attention.read_file file) in
  let ffts,args = match program.arguments with
    | (name,ScalarType ty)::rest when ty = scalar_type "i64" -> Some name,rest
    | args -> None,args in
  let i32 = ScalarType (scalar_type "i32") in
  let expected = [ShapedType ("memref",[-1],scalar_type "i8");
    ShapedType ("memref",[-1],scalar_type "i8");
    ShapedType ("memref",[-1],E.Float32Type); ShapedType ("memref",[-1],E.Float32Type);
    ShapedType ("memref",[-1],E.Float32Type)] @ List.init 7 (fun _ -> i32) in
  if List.map snd args <> expected then invalid_arg "unsupported compiled vector-add entry signature";
  let names = List.map fst program.arguments in
  if List.length names <> List.length (List.sort_uniq String.compare names) then
    invalid_arg "duplicate vector-add argument";
  let unused = List.map fst (List.filteri (fun i _ -> i < 2) args) @ Option.to_list ffts in
  let rec check ops = List.iter (fun (op : operation) ->
    List.iter (fun name -> if List.mem name op.operands then
      Source.fail op.span ("unsupported implicit vector-add argument " ^ name)) unused;
    check op.region; check op.else_region) ops in
  check program.body;
  Validate.kernel ?stage program;
  let state = ref {Handlers.memory=E.empty_memory;marker=73} in
  let ctx = {R.state;steps=0;max_steps;current=None;pid=0;calls=0;loops=[];trace} in
  R.with_handlers ctx (fun () ->
    let allocate ty length = Handlers.memory "sem_memref_alloc"
        (E.sem_memref_alloc E.ASGM ty [length]) in
    let input data =
      let id = allocate E.Float32Type n in
      Effect.perform (Handlers.Memory ("initialize_input",E.write_result
        (E.DefinedTensor (E.PackTensor ([n],E.Float32Type,Array.to_list data))) id)); id in
    let x = input a and y = input b in
    let z = allocate E.Float32Type n in
    let lock = allocate (scalar_type "i8") 1 and workspace = allocate (scalar_type "i8") 1 in
    let int value = R.Int (scalar_type "i32",Numeric.z_of_int value) in
    let programs = (n + 255) / 256 in
    for pid = 0 to programs - 1 do
      ctx.pid <- pid;
      let values = [R.Memref (lock,[1],scalar_type "i8");
        R.Memref (workspace,[1],scalar_type "i8");
        R.Memref (x,[n],E.Float32Type); R.Memref (y,[n],E.Float32Type);
        R.Memref (z,[n],E.Float32Type); int n; int programs; int 1; int 1;
        int pid; int 0; int 0] in
      let env = List.map2 (fun (name,_) value -> name,value) args values in
      let env = match ffts with None -> env
        | Some name -> (name,R.Int (scalar_type "i64",E.Z0))::env in
      ignore (R.execute_block ctx env program.body)
    done;
    ctx.current <- None;
    let tensor = Effect.perform (Handlers.Memory ("materialize_output",E.materialize
      (E.MemRefBackedTensor (z,[n],E.Float32Type,
        {E.access_restrict=false;access_writable=false})))) in
    let _,_,data = Handlers.packed tensor in
    if (!state).marker <> 73 then failwith "memory lens modified independent state";
    {Kernel.outputs=[{Kernel.name="%out";shape=[n];data=Array.of_list data}];
      steps=ctx.steps;calls=ctx.calls})
