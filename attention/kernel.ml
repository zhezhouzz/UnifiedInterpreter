module E = Extracted_semantics.Unified_semantics

type binding = Input of float array | Output
type output = { name : string; shape : int list; data : float array }
type result = { outputs : output list; steps : int; calls : int }

type argument =
  | Scalar of Numeric.cell
  | Buffer of { shape : int list; data : Numeric.cell list option; output : bool }
type buffer = { name : string; shape : int list; cells : Numeric.cell list }
type invocation = { buffers : buffer list; steps : int; calls : int }

let input_cell ty cell =
  let invalid () = invalid_arg "invalid kernel scalar or buffer element" in
  match Numeric.is_float ty, cell with
  | true,Numeric.Floating x when Float.is_finite x -> cell
  | true,Numeric.Integer x -> Numeric.Floating (Int64.to_float x)
  | false,Numeric.Integer x when Numeric.canonical ty x = x -> cell
  | _ -> invalid ()

let execute ?stage ?(max_steps=1000000) ?(trace=ignore) (program : Parser.program) bindings =
  if max_steps <= 0 then invalid_arg "max_steps must be positive";
  Validate.kernel ?stage program;
  let names = List.map fst bindings in
  if List.length names <> List.length (List.sort_uniq String.compare names) then
    invalid_arg "duplicate kernel binding";
  if List.sort String.compare names <>
     List.sort String.compare (List.map fst program.arguments) then
    invalid_arg "kernel bindings must match function arguments";
  let state = ref {Handlers.memory=E.empty_memory;marker=73} in
  let ctx = {Runner.state;steps=0;max_steps;current=None;pid=0;calls=0;loops=[];trace} in
  Runner.with_handlers ctx (fun () ->
    let arguments = List.map (fun (name,ty) ->
      match ty,List.assoc name bindings with
      | Parser.ScalarType ty,Scalar cell ->
          (name,Runner.of_cell ty (input_cell ty cell)),false
      | Parser.ShapedType ("memref",declared,ty),Buffer {shape;data;output} ->
          if List.length shape <> List.length declared ||
             not (List.for_all2 (fun n d -> n >= 0 && (d = -1 || n = d)) shape declared)
          then invalid_arg ("input shape mismatch: " ^ name);
          let size = Tensor_ops.size shape in
          let id = Handlers.memory "sem_memref_alloc" (E.sem_memref_alloc E.ASGM ty shape) in
          Option.iter (fun cells ->
            if List.length cells <> size then invalid_arg ("input size mismatch: " ^ name);
            let tensor = Handlers.unwrap (E.make_value shape ty (List.map (input_cell ty) cells)) in
            Effect.perform (Handlers.Memory ("initialize_input",E.write_result tensor id))) data;
          (name,Runner.Memref (id,shape,ty)),output
      | _ -> invalid_arg ("invalid kernel argument binding: " ^ name)) program.arguments in
    let env = List.map fst arguments in
    ignore (Runner.execute_block ctx env program.body);
    ctx.current <- None;
    let buffers = List.filter_map (function
      | (name,Runner.Memref (id,shape,ty)),true ->
          let view = E.MemRefBackedTensor (id,shape,ty,
            {E.access_restrict=false;access_writable=false}) in
          let value = Effect.perform (Handlers.Memory ("materialize_output",E.materialize view)) in
          let _,_,cells = Handlers.packed value in
          Some {name;shape;cells}
      | _ -> None) arguments in
    if (!state).marker <> 73 then failwith "memory lens modified independent state";
    {buffers;steps=ctx.steps;calls=ctx.calls})

let run_bound ?stage ?max_steps ?trace ~file bindings =
  let program = Parser.parse ~file (Attention.read_file file) in
  execute ?stage ?max_steps ?trace program bindings

let run ?stage ?max_steps ?trace ~file bindings =
  let program = Parser.parse ~file (Attention.read_file file) in
  let bindings = List.map (fun (name,binding) ->
    match List.assoc_opt name program.arguments with
    | Some (Parser.ShapedType ("memref",shape,E.Float32Type))
      when shape <> [] && List.for_all ((<) 0) shape ->
        let arg = match binding with
          | Input data -> Buffer {shape;data=Some (Array.to_list data |>
              List.map (fun x -> Numeric.Floating x));output=false}
          | Output -> Buffer {shape;data=None;output=true} in
        name,arg
    | _ -> invalid_arg "kernel entry requires static f32 memref arguments") bindings in
  let execution = execute ?stage ?max_steps ?trace program bindings in
  let outputs = List.map (fun (buffer : buffer) ->
    let data = List.map Numeric.as_float buffer.cells |> Array.of_list in
    if Array.exists (fun x -> not (Float.is_finite x)) data then
      invalid_arg ("non-finite output: " ^ buffer.name);
    {name=buffer.name;shape=buffer.shape;data}) execution.buffers in
  {outputs;steps=execution.steps;calls=execution.calls}
