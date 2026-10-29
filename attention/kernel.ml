module E = Extracted_semantics.Unified_semantics

type binding = Input of float array | Output
type output = { name : string; shape : int list; data : float array }
type result = { outputs : output list; steps : int; calls : int }

let run ?stage ?(max_steps=1000000) ?(trace=fun _ -> ()) ~file bindings =
  if max_steps <= 0 then invalid_arg "max_steps must be positive";
  let program = Parser.parse ~file (Attention.read_file file) in
  Validate.kernel ?stage program;
  let names = List.map fst bindings in
  if List.length names <> List.length (List.sort_uniq String.compare names) then
    invalid_arg "duplicate kernel binding";
  if List.sort String.compare names <>
     List.sort String.compare (List.map fst program.arguments) then
    invalid_arg "kernel bindings must match function arguments";
  let arguments = List.map (fun (name,ty) ->
    match ty with
    | Parser.ShapedType ("memref",shape,E.Float32Type)
      when shape <> [] && List.for_all ((<) 0) shape ->
        let size = List.fold_left (fun n d ->
          if n > max_int / d then invalid_arg "kernel shape overflow";
          n * d) 1 shape in
        let binding = List.assoc name bindings in
        (match binding with
        | Input data ->
            if Array.length data <> size then invalid_arg ("input shape mismatch: " ^ name);
            if Array.exists (fun x -> not (Float.is_finite x)) data then
              invalid_arg ("non-finite input: " ^ name)
        | Output -> ());
        name,shape,binding
    | _ -> invalid_arg "kernel entry requires static f32 memref arguments") program.arguments in
  let state = ref {Handlers.memory=E.empty_memory;marker=73} in
  let ctx = {Runner.state;steps=0;max_steps;current=None;pid=0;calls=0;loops=[];trace} in
  Runner.with_handlers ctx (fun () ->
    let allocated = List.map (fun (name,shape,binding) ->
      let id = Handlers.memory "sem_memref_alloc"
        (E.sem_memref_alloc E.ASGM E.Float32Type shape) in
      (match binding with
      | Input data ->
          let tensor = E.DefinedTensor (E.PackTensor (shape,E.Float32Type,Array.to_list data)) in
          Effect.perform (Handlers.Memory ("initialize_input",E.write_result tensor id))
      | Output -> ());
      name,shape,binding,id) arguments in
    let env = List.map (fun (name,shape,_,id) ->
      name,Runner.Memref (id,shape,E.Float32Type)) allocated in
    ignore (Runner.execute_block ctx env program.body);
    ctx.current <- None;
    let outputs = List.filter_map (fun (name,shape,binding,id) ->
      match binding with
      | Input _ -> None
      | Output ->
          let view = E.MemRefBackedTensor (id,shape,E.Float32Type,
            {E.access_restrict=false;access_writable=false}) in
          let value = Effect.perform (Handlers.Memory ("materialize_output",E.materialize view)) in
          let _,_,data = Handlers.packed value in
          let data = Array.of_list data in
          if Array.exists (fun x -> not (Float.is_finite x)) data then
            invalid_arg ("non-finite output: " ^ name);
          Some {name;shape;data}) allocated in
    if (!state).marker <> 73 then failwith "memory lens modified independent state";
    {outputs;steps=ctx.steps;calls=ctx.calls})
