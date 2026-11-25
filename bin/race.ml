open Unified_interpreter
module J = Yojson.Safe.Util

let run argv =
  let command=ref [] and root=ref "benchmarks/litao" and backend=ref "bfs" in
  let n=ref None and save=ref None and timeout=ref 5000 and heads=ref 1 and json=ref false in
  let ast=ref None and hivm=ref false in
  Arg.parse_argv ~current:(ref 0) argv [
    "--root",Arg.Set_string root,"DIR Litao fixture directory";
    "--json",Arg.Set json," print catalog with input parameters";
    "--hivm-ast",Arg.String (fun path -> ast:=Some path),"FILE export replay actions for this HIVM AST JSON";
    "--hivm",Arg.Set hivm," export replay actions for the benchmark's registered HIVM AST";
    "--backend",Arg.Symbol (["bfs";"smt";"symbolic"],(fun s -> backend:=s)),"METHOD race analysis";
    "--n",Arg.Int (fun x -> n:=Some x),"N concrete trip count or token length";
    "--kv-heads",Arg.Set_int heads,"N vectorlayout KV heads";
    "--timeout-ms",Arg.Set_int timeout,"MS symbolic SMT query timeout";
    "--save",Arg.String (fun p -> save:=Some p),"FILE write JSON report"]
    (fun s -> command:=s::!command) "race list | run NAME | replay REPORT";
  let catalog=Race_benchmarks.catalog !root in
  let directory = Filename.concat (Filename.dirname !root) "hivm" in
  let print doc=Yojson.Safe.to_channel stdout doc;print_newline () in
  match List.rev !command with
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
            Hivm_trace.to_json (Hivm_trace.generate ?n:!n ~kv_heads:!heads ~timeout_ms:!timeout method_ pairing) in
      (match !save with None -> print doc | Some path ->
        Out_channel.with_open_bin path (fun ch -> Yojson.Safe.to_channel ch doc);
        Printf.printf "%s %s %s pairs=%d\n" name !backend (J.to_string (J.member "status" doc))
          (List.length (J.to_list (J.member "races" doc))))
  | ["replay";path] ->
      let doc=Yojson.Safe.from_file path in
      let count=Benchmark_traces.replay catalog doc in
      Printf.printf "%s replayed=%d\n" (J.to_string (J.member "benchmark" doc)) count
  | _ -> invalid_arg "expected race list, race run NAME, or race replay FILE"
