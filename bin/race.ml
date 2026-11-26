open Unified_interpreter
module J = Yojson.Safe.Util

let run argv =
  let command=ref [] and root=ref "benchmarks/litao" and backend=ref "bfs" in
  let n=ref None and save=ref None and timeout=ref 5000 and heads=ref 1 and json=ref false in
  let ast=ref None and hivm=ref false in
  let entry=ref None and launch=ref None and replay=ref None and project=ref None and syntax=ref None in
  let set_syntax s =
    if !syntax<>None then raise (Arg.Bad "choose one MLIR input syntax");
    syntax := Some s in
  Arg.parse_argv ~current:(ref 0) argv [
    "--root",Arg.Set_string root,"DIR Litao fixture directory";
    "--json",Arg.Set json," print catalog with input parameters";
    "--hivm-ast",Arg.String (fun path -> ast:=Some path),"FILE export replay actions for this HIVM AST JSON";
    "--hivm",Arg.Set hivm," export HIVM replay actions";
    "--backend",Arg.Symbol (["bfs";"smt";"symbolic"],(fun s -> backend:=s)),"METHOD race analysis";
    "--n",Arg.Int (fun x -> n:=Some x),"N concrete trip count or token length";
    "--kv-heads",Arg.Set_int heads,"N vectorlayout KV heads";
    "--timeout-ms",Arg.Set_int timeout,"MS symbolic SMT query timeout";
    "--entry",Arg.String (fun name -> entry := Some name),"NAME MLIR entry function";
    "--launch",Arg.String (fun path -> launch := Some path),"FILE MLIR launch parameters in JSON";
    "--generic",Arg.Unit (fun () -> set_syntax Hivm_trace.Module_ast.Generic)," read generic MLIR assembly";
    "--bishengir-opt",Arg.String (fun path -> set_syntax (Hivm_trace.Module_ast.BiSheng path)),"PATH normalize vendor assembly";
    "--replay",Arg.String (fun path -> replay := Some path),"FILE verify a Core report from this MLIR and launch";
    "--project",Arg.String (fun path -> project := Some path),"FILE project a saved Core report onto the input MLIR AST";
    "--save",Arg.String (fun p -> save:=Some p),"FILE write JSON report"]
    (fun s -> command:=s::!command) "race list | run NAME | mlir FILE | replay REPORT";
  let print doc=Yojson.Safe.to_channel stdout doc;print_newline () in
  let emit name doc = match !save with
    | None -> print doc
    | Some path ->
        Out_channel.with_open_bin path (fun ch -> Yojson.Safe.to_channel ch doc);
        Printf.printf "%s %s %s pairs=%d\n" name !backend (J.to_string (J.member "status" doc))
          (List.length (J.to_list (J.member "races" doc))) in
  let selected = List.rev !command in
  match selected with
  | ["mlir";file] ->
      if !n<>None || !ast<>None || !json || !heads<>1 then
        raise (Arg.Bad "use --launch to supply MLIR arguments and configuration");
      if !replay<>None && (!save<>None || !hivm || !project<>None) then
        raise (Arg.Bad "choose --replay or report generation");
      let mode = match !backend with "bfs" -> Bug_traces.Search | "smt" -> Solve
        | _ -> raise (Arg.Bad "MLIR analysis requires a concrete backend") in
      let source = In_channel.with_open_bin file In_channel.input_all in
      let module_ast = Hivm_trace.Module_ast.parse ?syntax:!syntax ~file source in
      let configuration = Option.map Yojson.Safe.from_file !launch in
      let lowered = Hivm_trace.lower_mlir ?entry:!entry ?configuration module_ast in
      (match !replay with
       | Some path -> Printf.printf "%s replayed=%d\n" file
           (Hivm_trace.replay_mlir lowered (Yojson.Safe.from_file path))
       | None -> emit file (match !project with
           | Some path -> Hivm_trace.project_mlir lowered (Yojson.Safe.from_file path)
           | None -> Hivm_trace.analyze_mlir ~backend:mode ~hivm:!hivm lowered))
  | _ ->
      if !entry<>None || !launch<>None || !replay<>None || !project<>None || !syntax<>None then
        raise (Arg.Bad "MLIR options require race mlir FILE");
      let catalog=Race_benchmarks.catalog !root in
      let directory = Filename.concat (Filename.dirname !root) "hivm" in
      (match selected with
       | ["list"] when !json ->
           let info (name,load) =
             let param,default=match load () with Race_benchmarks.Core x -> x.family.parameter<>[],x.default_n
               | Device _ -> true,Vectorlayout_input.default.length in
             `Assoc ["name",`String name;"symbolic_n",`Bool param;"default_n",(if param then `Int default else `Null);
                     "hivm_ast",`String (Hivm_trace.ast_file ~root:directory name)] in
           print (`List (List.map info catalog))
       | ["list"] -> List.iter (fun (name,_) -> print_endline name) catalog
       | ["source";name] -> print_string (Hivm_trace.fixture_source catalog name)
       | ["run";name] ->
           let method_=match !backend with "bfs" -> Benchmark_traces.Concrete Search | "smt" -> Concrete Solve
             | "symbolic" -> Symbolic | s -> invalid_arg s in
           let path = match !ast with None when !hivm -> Some (Hivm_trace.ast_file ~root:directory name)
             | path -> path in
           let doc = match path with
             | None -> Benchmark_traces.generate ?n:!n ~kv_heads:!heads ~timeout_ms:!timeout catalog method_ name
             | Some path ->
                 let pairing = Hivm_trace.registered_file ~root:directory catalog name path in
                 (match method_ with
                  | Concrete b -> Ir_scheduler.generate ?n:!n ~kv_heads:!heads ~timeout_ms:!timeout ~name
                      (match b with Search -> Bfs | Solve -> Smt) (Device pairing)
                  | Symbolic -> Hivm_trace.to_json (Hivm_trace.generate ?n:!n ~kv_heads:!heads
                                                   ~timeout_ms:!timeout method_ pairing)) in
           emit name doc
       | ["replay";path] ->
           let doc=Yojson.Safe.from_file path in
           let count=Benchmark_traces.replay catalog doc in
           Printf.printf "%s replayed=%d\n" (J.to_string (J.member "benchmark" doc)) count
       | _ -> raise (Arg.Bad "expected race list, run NAME, mlir FILE, or replay REPORT"))
