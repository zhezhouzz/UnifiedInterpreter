module A = Hivm_trace.Module_ast
module J = Yojson.Safe.Util

let replace key value json =
  `Assoc ((key,value) :: List.remove_assoc key (J.to_assoc json))

let integers values = `List (List.map (fun n -> `Int n) values)

let sample rng = 11 + Random.State.int rng 10

let integer_input rng bits =
  if bits >= 6 then sample rng
  else
    let maximum = (1 lsl (bits - 1)) - 1 in
    let minimum = if maximum >= 11 then 11 else 0 in
    minimum + Random.State.int rng (maximum - minimum + 1)

let generic rng ast =
  let entries = List.filter (fun (_,(op:A.operation)) -> List.mem_assoc "hacc.entry" op.attributes) ast.A.functions in
  let entry = match entries, ast.functions with
    | [(name,_)],_ | _,[(name,_)] -> name
    | _ -> invalid_arg "automatic launch requires a unique entry function; specify --launch" in
  let extent = sample rng in
  let argument (_,ty) = match List.assoc ty ast.mlir_types with
    | A.Integer 1 -> `Bool (Random.State.bool rng)
    | A.Integer bits -> `Int (integer_input rng bits)
    | A.Float _ -> `Float (11. +. Random.State.float rng 9.)
    | A.Opaque -> invalid_arg ("unsupported launch argument type " ^ ty)
    | A.Shaped descriptor ->
        let shape = List.map (Option.value ~default:extent) descriptor.shape in
        let layout = match descriptor.layout with
          | A.Identity -> []
          | A.Opaque_layout -> invalid_arg ("unsupported launch layout " ^ ty)
          | A.Strided (offset,declared) ->
              let _,strides = List.fold_right2 (fun dim fixed (span,rest) ->
                let stride = Option.value ~default:span fixed in
                let steps = Z.of_int (max 0 (dim-1)) in
                Z.(to_int (of_int span + steps * abs (of_int stride))),stride::rest)
                shape declared (1,[]) in
              let low = List.fold_left2 (fun n dim stride ->
                let steps = Z.of_int (max 0 (dim-1)) in
                Z.(n + steps * of_int (Stdlib.min 0 stride))) Z.zero shape strides in
              ["strides",integers strides;"offset",`Int (Option.value ~default:(Z.to_int (Z.neg low)) offset)] in
        let initial = if List.mem 0 shape then [] else match List.assoc descriptor.element ast.mlir_types with
          | A.Integer 1 -> [`Int (Random.State.int rng 2)]
          | A.Integer bits -> [`Int (integer_input rng bits)]
          | A.Float _ -> [`Int (sample rng)]
          | _ -> [] in
        `Assoc (("shape",integers shape)::("initial",`List initial)::layout) in
  `Assoc ["entry",`String entry;"arguments",`List (List.map argument (A.entry ast entry).arguments)]

let generate ~seed ~source ~stage ast =
  let rng = Random.State.make [|seed|] in
  let root = match Sys.getenv_opt "ATTENTION_ROOT" with
    | Some path -> path | None -> Attention_runtime.Parser.project_root (Sys.getcwd ()) in
  let profiles = Yojson.Safe.from_file (Filename.concat root "benchmarks/scheduler/launch-profiles.json") in
  let digest = Digestif.SHA256.(to_hex (digest_string source)) in
  let config = match J.member (stage ^ "/" ^ digest) profiles with
    | `Null -> generic rng ast
    | profile ->
        let initialized = Hashtbl.create 8 in
        let stream spec =
          let entry = J.member "entry" spec |> J.to_string in
          let argument (_,ty) arg = match List.assoc ty ast.A.mlir_types,arg with
            | A.Shaped desc,`Assoc fields ->
                (match List.assoc desc.element ast.mlir_types, List.assoc_opt "bytes" fields with
                 | A.Float bits,Some (`Int bytes) ->
                     let storage = J.member "storage" arg |> J.to_string in
                     let fields = List.remove_assoc "initial" fields in
                     if Hashtbl.mem initialized storage then `Assoc fields else begin
                       Hashtbl.add initialized storage ();
                       let count = min 16 (bytes / ((bits+7)/8)) in
                       `Assoc (("initial",`List (List.init count (fun _ -> `Int (sample rng))))::fields)
                     end
                 | _ -> arg)
            | _ -> arg in
          let args = List.map2 argument (A.entry ast entry).arguments (J.member "arguments" spec |> J.to_list) in
          replace "arguments" (`List args) spec in
        replace "streams" (`List (List.map stream (J.member "streams" profile |> J.to_list))) profile in
  let capacity = Option.value ~default:1 (J.member "capacity" config |> J.to_int_option) in
  let config = replace "stage" (`String stage) config in
  let launch = Hivm_trace.Mlir.Launch.bind ~configuration:config ast in
  let capacity = if Hivm_trace.Mlir_device.required launch then 1
    else capacity + Random.State.int rng 2 in
  replace "capacity" (`Int capacity) config
