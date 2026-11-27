open Unified_interpreter
module J = Yojson.Safe.Util

let assoc = J.to_assoc
let dict xs = `Assoc xs
let list xs = `List xs
let text x = `String x
let int n = `Int n
let field k x = J.member k x
let cases () = Yojson.Safe.from_file "benchmarks/ir-pairs/catalog.json" |> field "benchmarks" |> assoc
let module_path stage case =
  let digest = J.to_string (field "sha256" (field stage case)) in
  "benchmarks/scheduler/modules/" ^ digest ^ ".json"

let scene_model ?query_length () =
  let open Z3 in
  let ctx = mk_context [] in
  let solver = Solver.mk_solver ctx None in
  let choose name lo hi =
    let x = Arithmetic.Integer.mk_const_s ctx name in
    let num = Arithmetic.Integer.mk_numeral_i ctx in
    Solver.add solver [Arithmetic.mk_ge ctx x (num lo);Arithmetic.mk_le ctx x (num hi)];
    name,x in
  let vars = [choose "query_length" 1 16;choose "active_rows" 1 1;
    choose "key_length" 1 256;choose "sparse_index" 0 1;choose "physical_page" 0 1] in
  let num = Arithmetic.Integer.mk_numeral_i ctx in
  let get n = List.assoc n vars in
  Option.iter (fun q -> Solver.add solver [Boolean.mk_eq ctx (get "query_length") (num q)]) query_length;
  Solver.add solver [Arithmetic.mk_lt ctx (Arithmetic.mk_mul ctx [get "sparse_index";num 128]) (get "key_length")];
  match Solver.check solver [] with
  | SATISFIABLE ->
      let model = Option.get (Solver.get_model solver) in
      dict (List.map (fun (name,x) -> name,int (Z.to_int (Arithmetic.Integer.get_big_int
        (Option.get (Model.eval model x true))))) vars)
  | _ -> invalid_arg "no launch input satisfies the nonempty sparse tile constraints"

let input_request ?n name =
  let catalog = Race_benchmarks.catalog "benchmarks/litao" in
  if List.mem_assoc name Hfusion_race.catalog then begin
    let file,launch,default = List.assoc name Hfusion_race.catalog in
    let program = Attention_runtime.Parser.parse ~file (Attention_runtime.Attention.read_file file) in
    let count = match n with Some _ -> n | None -> default in
    let value = function
      | Hfusion_trace.Parameter -> int (Option.get count)
      | Integer i -> int i | Float f -> `Float f
      | Buffer b -> dict ["storage",text b.allocation;"elements",int b.elements;
            "offset",int b.offset;"shape",list (List.map int b.shape);"strides",list (List.map int b.strides);
            "initialized",`Bool b.initialized] in
    let instances = List.mapi (fun id bindings ->
      let args = List.map (fun (key,_) -> value (List.assoc key bindings)) program.arguments in
      dict ["stream",int id;"entry",text program.name;"arguments",list args]) (launch program) in
    dict ["kind",text "tensor";"instances",list instances],count
  end else if String.starts_with ~prefix:"vectorlayout/" name then begin
    let config = {Vectorlayout_input.default with length=Option.value n ~default:Vectorlayout_input.default.length} in
    let input = Vectorlayout_input.make_hivm config in
    dict ["kind",text "vectorlayout";"config",dict ["length",int config.length;"dimension",int config.dimension;
          "group",int config.group;"kv_heads",int config.kv_heads;"splits",int config.splits];
          "bindings",Device_trace.bindings input],Some config.length
  end else if String.starts_with ~prefix:"cv/scene1/" name then
    dict ["kind",text "scene1";"model",scene_model ?query_length:n ()],n
  else
    let model = match Benchmark_traces.find catalog name with
      | Race_benchmarks.Core launch -> launch | Device _ -> invalid_arg "expected Core launch" in
    let entries,count,inputs = Hivm_trace.benchmark_arguments ?n name model in
    let entries = List.map (fun (id,entry) -> dict ["stream",int id;"entry",text entry]) entries in
    dict ["kind",text "core";"entries",list entries;"inputs",inputs],Option.map Z.to_int count

let registered_ast ?file stage case =
  let ast = Ir_scheduler.Ast.read (Option.value file ~default:(module_path stage case)) in
  if ast.source_sha256 <> J.to_string_option (field "sha256" (field stage case))
  then invalid_arg "registered AST does not match its source";
  ast

let generate ?n ?inputs ?file ?timeout_ms stage name backend =
  let case = List.assoc name (cases ()) in
  let launch,count = match inputs with
    | None -> let l,count = input_request ?n name in
        dict (("extra_arguments",field "extra_arguments" case)::assoc l), count
    | Some x -> Ir_scheduler.Catalog.explicit x,n in
  let ast = registered_ast ?file stage case in
  let level = if stage="hivm" then Ir_scheduler.HIVM else HFusion in
  Ir_scheduler.Catalog.generate ?n:count ?timeout_ms ~name backend (Module (level,ast,launch))

let replay doc =
  let stage = J.to_string (field "stage" doc) and name = J.to_string (field "benchmark" doc) in
  let ast = registered_ast stage (List.assoc name (cases ())) in
  Printf.printf "%s replayed=%d\n" name (Ir_scheduler.Catalog.replay_module ast doc)

let stage_of args =
  match List.filter (fun stage -> List.mem ("--"^stage) args || List.mem ("--"^stage^"-ast") args)
          ["hivm";"hfusion"] with
  | [] -> None | [stage] -> Some stage
  | _ -> invalid_arg "select one IR stage"

let info core stage name case =
  let tensor = List.assoc_opt name Hfusion_race.catalog in
  let parameter,default = match List.assoc_opt name core,tensor with
    | Some load,_ -> (match load () with
        | Race_benchmarks.Core c -> c.family.parameter<>[],Some c.default_n
        | Device _ -> true,Some Vectorlayout_input.default.length)
    | _,Some (_,_,n) -> n<>None,n | _ -> false,None in
  let ast = if stage="hivm" && List.mem_assoc name core then text (Hivm_trace.ast_file name)
    else if stage="hfusion" && tensor<>None then `Null else text (module_path stage case) in
  dict ["name",text name;"ir",field "path" (field stage case);stage^"_ast",ast;
        "native_catalog",`Bool (if stage="hivm" then List.mem_assoc name core else tensor<>None);
        "symbolic_n",`Bool (parameter && (if stage="hivm" then List.mem_assoc name core else tensor<>None));
        "default_n",(if parameter then Option.fold ~none:`Null ~some:int default else `Null)]

let dispatch args =
  let stages,rest = List.partition (fun x -> x="--hivm" || x="--hfusion") args in
  let args = rest @ stages in
  match args,stage_of args with
  | ["launch-request";name;_],Some stage ->
      let case = List.assoc name (cases ()) in
      let launch,n = input_request name in
      let extra = if stage="hfusion" then field "extra_arguments" case else `Null in
      let launch = dict (("extra_arguments",extra)::assoc launch) in
      Yojson.Safe.to_channel stdout (dict ["stage",text stage;"name",text name;"launch",launch;
        "n",Option.fold ~none:`Null ~some:int n]); print_newline (); true
  | "list"::flags,Some stage ->
      if List.exists (fun s -> not (List.mem s ["--hfusion";"--hivm";"--json"])) flags then
        invalid_arg "unknown catalog option";
      let all = cases () in
      let core = Race_benchmarks.catalog "benchmarks/litao" in
      if List.mem "--json" flags then (Yojson.Safe.to_channel stdout
        (list (List.map (fun (name,case) -> info core stage name case) all)); print_newline ())
      else List.iter (fun (name,_) -> print_endline name) all;
      true
  | "replay"::file::_,_ when field "format" (Yojson.Safe.from_file file) = text "ir-race-1" ->
      replay (Yojson.Safe.from_file file); true
  | "run"::name::options,Some stage when List.mem_assoc name (cases ()) &&
      not (if stage="hivm" then List.mem_assoc name (Race_benchmarks.catalog "benchmarks/litao")
           else List.mem_assoc name Hfusion_race.catalog) ->
      let backend = ref Precedence.Bfs and n = ref None and save = ref None and launch = ref None
      and file = ref None and timeout = ref 5000 in
      Arg.parse_argv ~current:(ref 0) (Array.of_list ("race run"::options))
        ["--hivm",Arg.Unit ignore," HIVM"; "--hfusion",Arg.Unit ignore," HFusion";
         "--backend",Arg.Symbol (["bfs";"smt"],(fun x -> backend:=(if x="smt" then Smt else Bfs)))," solver";
         "--launch",Arg.String (fun f -> launch:=Some (Yojson.Safe.from_file f)),"FILE launch bindings";
         "--"^stage^"-ast",Arg.String (fun path -> file:=Some path),"FILE source module AST";
         "--timeout-ms",Arg.Set_int timeout,"MS solver timeout";
         "--n",Arg.Int (fun x -> n:=Some x),"N input parameter"; "--save",Arg.String (fun f -> save:=Some f),"FILE report"]
        (fun x -> raise (Arg.Bad x)) "race run NAME";
      let report = generate ?n:!n ?inputs:!launch ?file:!file ~timeout_ms:!timeout stage name !backend in
      (match !save with None -> Yojson.Safe.to_channel stdout report; print_newline ()
       | Some f -> Yojson.Safe.to_file f report);
      true
  | _ -> false
