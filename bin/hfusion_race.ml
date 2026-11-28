module H = Hfusion_trace
module A = Attention_runtime
let buffer allocation initialized shape =
  let elements,strides=List.fold_right (fun d (n,ss) -> d*n,n::ss) shape (1,[]) in
  H.Buffer {allocation;elements;initialized;offset=0;shape;strides}

let kernels name =
  let example=A.Kernel_examples.get name in
  let launch program =
    [List.map (fun (name,ty) -> match ty with
      | A.Parser.ShapedType ("memref",shape,_) ->
          name,buffer name (List.assoc name example.bindings<>A.Kernel.Output) shape
      | _ -> invalid_arg "unexpected example kernel signature") program.A.Parser.arguments] in
  A.Kernel_examples.file example "hfusion",launch,None

let attention _ =
  List.init 20 (fun pid -> List.init 16 (fun i ->
    let name="%arg"^string_of_int i in
    let value=match i with
      | 1|2 -> buffer "unused" false [1]
      | 3|4|5 -> buffer name true [16384]
      | 6 -> buffer name false [128]
      | 7|8 -> buffer name false [16384]
      | 9 -> H.Float (1. /. sqrt 128.)
      | 13 -> H.Integer pid | _ -> H.Integer 0 in
    name,value))

let strided _ =
  List.mapi (fun pid lane -> ["%input",buffer ("input"^string_of_int pid) true [1];
    "%out",buffer "output" false [7];"%lane",H.Integer lane;"%start",H.Integer 0;"%n",H.Parameter]) [0;3]
let catalog = [
  "tensor-entry-add",("benchmarks/hfusion/tensor-entry-add.mlir",
    (fun _ -> [["%a",buffer "%a" true [8]; "%b",buffer "%b" true [8]; "%out",buffer "%out" false [8]]]),None);
  "vector-add",kernels "vector-add";"row-sum",kernels "row-sum";
  "flash-attention",("artifacts/flash_attention/ir/hfusion_level.mlir",attention,None);
  "strided-output",("benchmarks/hfusion/strided-output.mlir",strided,Some 4)]

let run argv =
  let args=ref [] and backend=ref H.Bfs and ir=ref None and ast=ref None and launch=ref None
  and n=ref None and timeout=ref 5000 and save=ref None and json=ref false in
  let file r p=r:=Some p in
  Arg.parse_argv ~current:(ref 0) argv [
    "--hfusion",Arg.Unit ignore," select HFusion IR";
    "--hfusion-ast",Arg.String (file ast),"FILE attention frontend AST JSON";
    "--hfusion-ir",Arg.String (file ir),"FILE HFusion MLIR test input";
    "--launch",Arg.String (file launch),"FILE per-instance argument bindings";
    "--backend",Arg.Symbol (["bfs";"smt";"symbolic"],(function "bfs" -> backend:=H.Bfs
      | "smt" -> backend:=H.Smt | _ -> backend:=H.Symbolic)),"METHOD race analysis";
    "--n",Arg.String (fun i -> n:=Some (Z.of_string i)),"N concrete launch parameter";
    "--timeout-ms",Arg.Set_int timeout,"MS solver timeout";
    "--json",Arg.Set json," print catalog as JSON";
    "--save",Arg.String (file save),"FILE write JSON report"]
    (fun s -> args:=s::!args) "race list --hfusion | race run NAME --hfusion [options]";
  let print doc=Yojson.Safe.to_channel stdout doc;print_newline () in
  let program entry =
    let parse path=A.Parser.parse ~file:path (A.Attention.read_file path) in
    match !ir,!ast,entry with
    | Some _,Some _,_ -> invalid_arg "choose one HFusion AST source"
    | None,Some p,_ -> H.read_ast p | Some p,None,_ -> parse p
    | None,None,Some (path,_,_) -> parse path
    | _ -> invalid_arg "custom program requires --hfusion-ast or --hfusion-ir" in
  match List.rev !args with
  | ["list"] when !json -> print (`List (List.map (fun (name,(path,_,n)) ->
      `Assoc ["name",`String name;"ir",`String path;"symbolic_n",`Bool (n<>None);
              "default_n",Option.fold ~none:`Null ~some:(fun n -> `Int n) n]) catalog))
  | ["list"] -> List.iter (fun (name,_) -> print_endline name) catalog
  | ["run";name] ->
      let entry=List.assoc_opt name catalog in
      let program=program entry in
      let bindings=match !launch,entry with Some path,_ -> H.launch_of_json (Yojson.Safe.from_file path)
        | None,Some (_,launch,_) -> launch program | _ -> invalid_arg "custom program requires --launch" in
      let n=match !n,!backend,!launch,entry with
        | None,(H.Bfs|H.Smt),None,Some (_,_,default) -> Option.map Z.of_int default | _ -> !n in
      let prepared = H.prepare program bindings in
      let result = match !backend with
        | (Bfs | Smt) when Option.fold ~none:true ~some:Z.fits_int n ->
            Ir_scheduler.Catalog.generate ?n:(Option.map Z.to_int n) ~timeout_ms:!timeout ~name
              (if !backend=Bfs then Bfs else Smt) (Tensor prepared)
        | method_ ->
            let report=H.generate ?n ~timeout_ms:!timeout method_ prepared |> H.to_json in
            `Assoc (("benchmark",`String name)::Yojson.Safe.Util.to_assoc report) in
      (match !save with None -> print result | Some path ->
        Out_channel.with_open_bin path (fun ch -> Yojson.Safe.to_channel ch result))
  | ["replay";path] ->
      let report=Yojson.Safe.from_file path in
      let name=Yojson.Safe.Util.(to_string (member "benchmark" report)) in
      let count=H.replay_report (program (List.assoc_opt name catalog)) report in
      Printf.printf "%s replayed=%d\n" name count
  | _ -> invalid_arg "expected HFusion race list, run NAME or replay FILE"
