open Stdlib
open Unified_interpreter
module Ast = Attention_runtime.Parser
module C = Core_lang
module J = Yojson.Safe.Util
module Module_ast = Hivm_module
open Hivm_event
open Trace_projection

let resolve (program : Ast.program) path =
  let rec descend body = function
    | i :: rest when i >= 0 ->
        (match List.nth_opt body i with
         | Some (op : Ast.operation) -> if rest = [] then op else descend op.region rest
         | None -> invalid "%s: unknown AST path %s" program.name (path_name path))
    | _ -> invalid "%s: invalid AST path %s" program.name (path_name path) in
  descend program.body path

let decode_ast file doc =
  Ast.check_integer_range file doc;
  { Ast.name = J.member "name" doc |> J.to_string;
    arguments = J.member "arguments" doc |> J.to_list |> List.map Ast.argument;
    body = J.member "body" doc |> J.to_list |> List.map Ast.operation }

let read_ast file = decode_ast file (Yojson.Safe.from_file file)

type binding = { core_site : int list; origin : origin }
type stream_pair = { stream_id : int; program : Ast.program; bindings : binding list }
type core_pairing = {
  name : string; launch : Race_benchmarks.launch; pipes : (int * pipe) list;
  entries : (int * string) list; sites : (int * int list, event_site) Hashtbl.t;
  inputs : Race_report.Schedule.t option -> Z.t option -> Yojson.Safe.t;
}
type pairing = Core of core_pairing | Layout of Vectorlayout.variant * Module_ast.t

(* 只省略在单条流中求值的纯控制和标量指令。每个其余位置都必须有来源。 *)
let core_sites body =
  let rec walk site loops cmd rest =
    let next cmd = walk (0 :: site) loops cmd rest in
    match cmd with
    | C.Return _ | End | Yield _ -> rest
    | Scalar (_, _, _, cmd) -> next cmd
    | Branch _ | Branch_values _ | While_values _ | Call_values _ | Block_counter _ | Peer_sync _ | Core_barrier _ -> invalid "paired control flow needs an explicit source mapping at %s"
                    (path_name (List.rev site))
    | For (_, _, _, _, body, cmd) | For_values (_, _, _, _, _, _, body, cmd) ->
        walk (0 :: site) (List.rev site :: loops) body (walk (1 :: site) loops cmd rest)
    | (Issue (_, _, _, cmd) | Sync (_, _, _, _, cmd) | Barrier (_, cmd) | Alloc (_, _, _, cmd)) as action ->
        (List.rev site, List.rev loops, action) :: next cmd in
  walk [] [] body []

(* 这里列出有具体执行含义的设备动作。其他指令只有经过纯操作分类才可省略。 *)
type role = Work of string * pipe | Flag of C.signal | Handoff of C.signal | Fence | Allocation

let operations (op : Ast.operation) =
  let work name pipe = [None, Work (name, pipe)] in
  match op.opcode with
  | "hivm.hir.load" when op.result=None -> work "load" MTE2
  | "hivm.hir.nd2nz" when op.result=None -> work "nd2nz" MTE2
  | "hivm.hir.store" when op.result=None -> work "store" MTE3
  | "hivm.hir.fixpipe" when op.result=None -> work "fixpipe" FIX
  | "hivm.hir.mmadL1" when op.result=None && List.length op.operands=7 ->
      [Some "load", Work ("mmadL1.load", MTE1);
       Some "signal_loaded", Handoff LocalSet; Some "wait_loaded", Handoff LocalWait;
       Some "compute", Work ("mmadL1", M)]
  | "hivm.hir.set_flag" -> [None, Flag LocalSet]
  | "hivm.hir.wait_flag" -> [None, Flag LocalWait]
  | "hivm.hir.sync_block_set" -> [None, Flag BlockSet]
  | "hivm.hir.sync_block_wait" -> [None, Flag BlockWait]
  | "hivm.hir.pipe_barrier" -> [None, Fence]
  | "memref.alloc" | "memref.alloca" -> [None, Allocation]
  | "memref.store" -> work "scalarstore" S
  | "memref.load" -> work "scalarload" S
  | "scf.for" | "scf.yield" | "func.return" | "memref.cast" | "memref.subview"
  | "memref.reinterpret_cast" | "memref.expand_shape" | "memref.collapse_shape" -> []
  | opcode when String.starts_with ~prefix:"arith." opcode -> []
  | opcode when op.result=None && List.mem opcode ["hivm.hir.vexp";"hivm.hir.vabs";"hivm.hir.vadd";
        "hivm.hir.vsub";"hivm.hir.vmul";"hivm.hir.vdiv";"hivm.hir.vln";
        "hivm.hir.vcast";"hivm.hir.vbrc";"hivm.hir.vreduce"] ->
      work (String.sub opcode 9 (String.length opcode - 9)) V
  | opcode -> invalid "no replay semantics for HIVM operation %s" opcode

let ast_sites (program : Ast.program) =
  let rec block parent loops body =
    List.mapi (fun i (op : Ast.operation) ->
      let path = parent @ [i] in
      let own = List.map (fun (part, role) ->
        {path;opcode=op.opcode;part}, loops, role, op) (operations op) in
      let nested = if op.opcode = "scf.for" then loops @ [path] else loops in
      own @ block path nested op.region) body |> List.concat in
  block [] [] program.body

let attribute (op : Ast.operation) name =
  match List.assoc_opt name op.attributes with
  | Some value -> value | None -> invalid "%s lacks attribute %s" op.opcode name

let attribute_pipe op key expected =
  if attribute op key <> `String expected then invalid "%s: expected %s=%s" op.Ast.opcode key expected

let check_role (launch : Race_benchmarks.launch) stream pipes (op : Ast.operation) role cmd =
  let pipe p = pipe_of pipes p in
  match role, cmd with
  | Allocation, C.Alloc _ -> ()
  | Work (name,q), C.Issue (p,f,_,_) when pipe p = q && launch.op_name f = name &&
                                          C.scalar_endpoint stream p = (q = S) -> ()
  | Fence, C.Barrier (b,_) ->
      attribute_pipe op "pipe" (match b with All -> "PIPE_ALL" | Pipe p -> pipe_name (pipe p))
  | Handoff mode, C.Sync (m,p,Data q,_,_) when mode=m && pipe p=MTE1 && pipe q=M -> ()
  | Flag mode, C.Sync (m,p,q,flag,_) when mode = m ->
      let source, target, flag_attr = match mode with
        | LocalSet | LocalWait -> "set_pipe","wait_pipe","fixed"
        | BlockSet | BlockWait -> "tpipe","pipe","static_flag_id" in
      attribute_pipe op source (pipe_name (pipe p));
      attribute_pipe op target (pipe_name (match q with ScalarEnd -> S | Data n -> pipe n));
      (match flag, List.assoc_opt flag_attr op.attributes, op.operands with
       | C.Literal (VEvent k), Some (`Int actual), [] when actual = k -> ()
       | Var _, None, [_] -> ()
       | _ -> invalid "%s: mismatched flag operand" op.opcode)
  | _ -> invalid "%s: Core action or pipe differs" op.opcode

let unique label xs =
  if List.length xs <> List.length (List.sort_uniq compare xs) then invalid "duplicate %s" label

let pair ~name ~(launch : Race_benchmarks.launch) ~pipes ~streams =
  unique "pipe number" (List.map fst pipes);
  unique "pipe name" (List.map snd pipes);
  if List.exists (fun (p,q) -> p = C.scalar_pipe && q <> S) pipes then
    invalid "%s: inconsistent scalar pipe mapping" name;
  unique "stream" (List.map (fun s -> s.stream_id) streams);
  unique "Core stream" (List.map (fun (s : C.stream) -> s.id) launch.family.streams);
  let sites = Hashtbl.create 32 in
  let entries = List.map (fun (s : C.stream) ->
    let where = match List.find_opt (fun b -> b.stream_id = s.id) streams with
      | None -> invalid "%s: missing HIVM entry for stream %d" name s.id | Some b -> b in
    List.iter (fun p -> ignore (pipe_of pipes p)) s.pipes;
    let static = core_sites s.body and target = ast_sites where.program in
    let anchors = List.map (fun b -> b.core_site,b.origin) where.bindings in
    unique "Core site" (List.map fst anchors);
    if List.length target <> List.length static || List.length anchors <> List.length static then
      invalid "%s stream %d: incomplete pairing (%d Core actions, %d HIVM actions, %d bindings)"
        name s.id (List.length static) (List.length target) (List.length anchors);
    let loop_origins = Hashtbl.create 8 and loop_sites = Hashtbl.create 8 in
    let handoff_flags = Hashtbl.create 4 in
    let bind_loop table key value =
      match Hashtbl.find_opt table key with
      | None -> Hashtbl.add table key value
      | Some old when old = value -> ()
      | Some _ -> invalid "%s: inconsistent loop mapping" name in
    List.iter2 (fun (site,loops,cmd) (actual,nesting,role,op) ->
      (match List.assoc_opt site anchors with
       | Some origin when origin = actual -> ()
       | _ -> invalid "%s stream %d site %s: expected %s at %s" name s.id
                (path_name site) actual.opcode (path_name actual.path));
      if List.length loops <> List.length nesting then invalid "%s: different loop nesting at %s" name (path_name site);
      List.iter2 (fun c h -> bind_loop loop_origins c h; bind_loop loop_sites h c) loops nesting;
      check_role launch s pipes op role cmd;
      (match role,cmd with
       | Handoff LocalSet,C.Sync (_,_,_,flag,_) -> Hashtbl.add handoff_flags actual.path flag
       | Handoff LocalWait,C.Sync (_,_,_,flag,_) when Hashtbl.find handoff_flags actual.path <> flag ->
           invalid "%s: different handoff flags at %s" name (path_name actual.path)
       | _ -> ());
      Hashtbl.add sites (s.id,site) (match role with Allocation -> Ordinary | _ -> Direct actual)) static target;
    s.id, where.program.name) launch.family.streams in
  if List.length streams <> List.length entries then invalid "%s: extra stream mapping" name;
  Core {name;launch;pipes;entries;sites;inputs=(fun _ _ -> launch.fixture)}

let strings xs = `List (List.map (fun x -> `String x) xs)

let registration = function
  | "fixture/hivm-two-loads" -> "two_loads_hivm","f52b917d54aa1bbf5c806caaaae2c6ba",[0,MTE2],"%n"
  | "issue316/ordered" -> "issue316_vexp_hivm","971be75f217e6e766d5bbaaca9e2720d",[0,MTE2;1,V],"%tile_count"
  | "issue316/missing-ready" -> "issue316_missing_ready_hivm","06217c513484621849a59f62747a6913",[0,MTE2;1,V],"%tile_count"
  | "vectorlayout/ok" | "vectorlayout/fail" ->
      invalid "vectorlayout needs both kernel entries: use registered_module or registered_file"
  | name -> invalid "%s has no registered HIVM pairing" name

(* 源位置只用于诊断。绑定到具体 AST 的其余字段，包括操作数、类型、属性及 region。 *)
let same_program (a : Ast.program) (b : Ast.program) =
  let rec node (a : Ast.operation) (b : Ast.operation) =
    {a with span=b.span; region=b.region; attributes=b.attributes} = b &&
    Yojson.Safe.sort (`Assoc a.attributes) = Yojson.Safe.sort (`Assoc b.attributes) &&
    List.equal node a.region b.region in
  a.name = b.name && a.arguments = b.arguments && List.equal node a.body b.body

let rec semantic_json = function
  | `Assoc fields -> `Assoc (List.filter_map (fun (key,value) ->
      if key="span" then None else Some (key,semantic_json value)) fields)
  | `List xs -> `List (List.map semantic_json xs)
  | value -> value

let from_registration catalog name pipes n_argument digest program =
  match Benchmark_traces.find catalog name with
  | Race_benchmarks.Core launch ->
      let streams = match launch.family.streams with
        | [s] ->
            let core = core_sites s.body and nodes = ast_sites program in
            if List.length core <> List.length nodes then invalid "%s: incomplete pairing" name;
            let bindings = List.map2 (fun (core_site,_,_) (origin,_,_,_) ->
              {core_site;origin}) core nodes in
            [{stream_id=s.id;program;bindings}]
        | _ -> invalid "%s: expected a single entry" name in
      let fixture = `Assoc ["arguments",strings (List.map fst program.Ast.arguments);
                            "n_argument",`String n_argument;"ast_digest",`String digest] in
      pair ~name ~launch:{launch with fixture} ~pipes ~streams
  | Device _ -> invalid "%s requires a paired Core program" name

let reference root name =
  let stem,expected,pipes,n_argument = registration name in
  let file = Filename.concat root (stem ^ ".ast.json") in
  let json = Yojson.Safe.from_file file in
  let identity = Yojson.Safe.sort (semantic_json json) in
  let digest = Digest.to_hex (Digest.string (Yojson.Safe.to_string identity)) in
  if digest <> expected then invalid "%s: reference AST differs from the registered Core model" name;
  file,json,identity,digest,pipes,n_argument

let registered ?(root="benchmarks/hivm") catalog name program =
  let file,json,_,digest,pipes,n_argument = reference root name in
  if not (same_program program (decode_ast file json)) then invalid "%s: HIVM AST differs" name;
  from_registration catalog name pipes n_argument digest program

let core_file ~root catalog name file =
  let _,_,identity,digest,pipes,n_argument = reference root name in
  let json = Yojson.Safe.from_file file in
  (* 完整前端输出还包含地址空间和步幅，即使旧版 OCaml AST 只保留形状也要核对。 *)
  if Yojson.Safe.sort (semantic_json json) <> identity then invalid "%s: HIVM AST differs" name;
  from_registration catalog name pipes n_argument digest (decode_ast file json)

let legacy = function "fixture/hivm-two-loads" | "issue316/ordered" | "issue316/missing-ready" -> true
  | _ -> false

let ast_file ?(root="benchmarks/hivm") name =
  let stem = match name with
    | "vectorlayout/ok" -> "vectorlayout_ok" | "vectorlayout/fail" -> "vectorlayout_fail"
    | name when legacy name -> let stem,_,_,_ = registration name in stem
    | name -> name in
  Filename.concat root (stem ^ ".ast.json")

(* @reserve 将新缓冲区的描述符写入共享槽。回放只调度函数体内的共享写入。 *)
let allocation_site ast (origin : origin) (op : Module_ast.operation) =
  match op.opcode with
  | "memref.alloc" | "memref.alloca" -> Ordinary
  | "func.call" when List.assoc_opt "callee" op.properties = Some "@reserve" ->
      let callee = "@reserve" in
      let block = Module_ast.entry ast callee in
      let slot = fst (List.hd block.arguments) in
      let stores = List.filter_map Fun.id (List.mapi (fun i (op : Module_ast.operation) ->
        match op.opcode, op.operands with
        | "memref.store", [_; dst; _] when dst = slot -> Some {path=[i];opcode=op.opcode;part=None}
        | _ -> None) block.body) in
      (match stores with
       | [target] -> In_call {call_path=origin.path;callee;target}
       | _ -> invalid "%s: expected one store to the shared descriptor slot" callee)
  | code -> invalid "unexpected allocation operation %s" code

let catalog_pair ~root name (launch : Race_benchmarks.launch) (ast : Module_ast.t) =
  let origin = match ast.catalog_origin with Some o when o.benchmark=name -> o
    | _ -> invalid "%s: AST benchmark differs" name in
  let manifest = Yojson.Safe.from_file (Filename.concat root "catalog.json") in
  if J.member name manifest <> `String ast.digest then invalid "%s: unrecognized HIVM module" name;
  let generated = launch.fixture=`Null in
  let pipes,entry,model = if generated then
    Fixture_source.pipes,Fixture_source.entry,Digest.to_hex (Digest.string (Fixture_source.source name launch))
  else
    let launch_names = J.member "streams" (J.member "launch" launch.fixture) |> J.to_list in
    [0,V;1,MTE2;2,MTE3;3,FIX;4,MTE1;5,M],(fun id -> "@" ^ J.to_string (List.nth launch_names id)),
    J.to_string (J.member "program_digest" launch.fixture) in
  if model<>origin.model_digest then invalid "%s: Core model differs from the module" name;
  let sites = Hashtbl.create 32 in
  let entries = List.map (fun (s : C.stream) ->
    let entry = entry s.id in
    let bindings=List.assoc (String.sub entry 1 (String.length entry-1)) origin.sites in
    unique "Core site" (List.map fst bindings); unique "HIVM path" (List.map snd bindings);
    let seen=ref 0 in
    let bind site project =
      let path=List.assoc site bindings in
      let op=Module_ast.resolve ast ~entry path in
      incr seen; Hashtbl.add sites (s.id,site) (project {path;opcode=op.opcode;part=None} op) in
    let direct site check = bind site (fun origin op ->
      let attr key = List.assoc_opt key (op.attributes @ op.properties) in
      if not (check op.opcode attr) then
        invalid "%s: incompatible HIVM operation at %s %s" name entry (path_name origin.path);
      Direct origin) in
    let pip p = "#hivm.pipe<" ^ pipe_name (pipe_of pipes p) ^ ">" in
    let rec walk site cmd =
      let child i cmd = walk (site @ [i]) cmd in
      match cmd with
      | C.End | Return _ | Yield _ -> ()
      | Scalar (_,_,_,rest) | Block_counter (_,rest) | Peer_sync (_,_,_,_,_,rest) | Core_barrier rest -> child 0 rest
      | For (_,_,_,_,body,rest) | For_values (_,_,_,_,_,_,body,rest) -> child 0 body; child 1 rest
      | Branch (_,a,b,rest) | Branch_values (_,_,a,b,rest) -> child 0 a; child 1 b; child 2 rest
      | While_values (_,_,_,a,b,rest) -> child 0 a; child 1 b; child 2 rest
      | Call_values (_,_,_,a,rest) -> child 0 a; child 1 rest
      | Alloc (_,_,_,rest) ->
          bind site (allocation_site ast);
          child 0 rest
      | Issue (p,f,_,rest) ->
          let fn=launch.op_name f in
          direct site (fun code attr ->
            if generated then code="func.call" && attr "hivm.pipe"=Some (pip p) &&
              List.mem (attr "callee") [Some ("@"^fn);Some ("@"^fn^"_shared")]
            else match fn with
              | "indirect_atomic_add" -> code="hivm.hir.custom" && attr "symbol"=Some "\"__builtin_indirect_atomic\""
              | "scalarstore" -> code="memref.store" && p=C.scalar_pipe
              | _ -> code="hivm.hir."^fn);
          child 0 rest
      | Barrier (b,rest) ->
          direct site (fun code attr -> code="hivm.hir.pipe_barrier" &&
            attr "pipe"=Some (match b with All -> "#hivm.pipe<PIPE_ALL>" | Pipe p -> pip p)); child 0 rest
      | Sync (mode,p,q,_,rest) ->
          let short,src,dst = match mode with
            | LocalSet -> "set_flag","set_pipe","wait_pipe" | LocalWait -> "wait_flag","set_pipe","wait_pipe"
            | BlockSet -> "sync_block_set","tpipe","pipe" | BlockWait -> "sync_block_wait","tpipe","pipe" in
          direct site (fun code attr -> code="hivm.hir."^short && attr src=Some (pip p) &&
            attr dst=Some (match q with ScalarEnd -> "#hivm.pipe<PIPE_S>" | Data q -> pip q)); child 0 rest in
    walk [] s.body;
    if !seen<>List.length bindings then invalid "%s: unmatched Core sites in %s" name entry;
    s.id,entry) launch.family.streams in
  Core {name;launch;pipes;entries;sites;inputs=Catalog_inputs.make name launch ast entries}

let registered_module ?(root="benchmarks/hivm") catalog name ast =
  match Benchmark_traces.find catalog name with
  | Race_benchmarks.Device variant -> Vectorlayout_hivm.check variant ast; Layout (variant,ast)
  | Core _ when legacy name -> invalid "%s expects a single-function AST" name
  | Core launch -> catalog_pair ~root name launch ast

let registered_file ?(root="benchmarks/hivm") catalog name file =
  match Benchmark_traces.find catalog name with
  | Race_benchmarks.Core _ when legacy name -> core_file ~root catalog name file
  | _ -> registered_module ~root catalog name (Module_ast.read file)

let fixture_source catalog name = match Benchmark_traces.find catalog name with
  | Race_benchmarks.Core launch when (String.starts_with ~prefix:"regression/" name ||
      String.starts_with ~prefix:"fixture/" name && name <> "fixture/hivm-two-loads") ->
      Fixture_source.source name launch
  | _ -> invalid "%s has an archived source" name

let benchmark_arguments ?n name (launch : Race_benchmarks.launch) =
  let n = if launch.family.parameter=[] then None else Some (Z.of_int (Option.value n ~default:launch.default_n)) in
  let config = if launch.fixture=`Null then `Null else J.member "launch" launch.fixture in
  let entry id = match name,config with
    | "fixture/hivm-two-loads",_ -> "@two_loads"
    | ("issue316/ordered" | "issue316/missing-ready"),_ -> "@issue316_vexp"
    | _,`Null -> Fixture_source.entry id
    | _ -> "@" ^ J.to_string (List.nth (J.to_list (J.member "streams" config)) id) in
  let entries = List.map (fun (s : C.stream) -> s.id,entry s.id) launch.family.streams in
  let inputs = if legacy name then []
    else if config<>`Null then Catalog_inputs.litao launch entries config n
    else Catalog_inputs.fixture name launch (Race_report.schedule launch (Option.value n ~default:Z.zero)) n in
  entries,n,`Assoc inputs

let generate_core ?n ~timeout_ms method_ pairing =
  let launch = pairing.launch in
  let report ?schedule n status races = {benchmark=pairing.name;streams=pairing.entries;n;
                                inputs=pairing.inputs schedule n;status;races} in
  let parameter = launch.family.parameter <> [] in
  let export = export_races ~pipes:pairing.pipes ~entries:pairing.entries
    ~source:(fun stream site -> Hashtbl.find pairing.sites (stream,site)) in
  match method_ with
  | Benchmark_traces.Concrete backend ->
      if n <> None && not parameter then invalid "fixed entry parameters";
      let n = Z.of_int (Option.value n ~default:launch.default_n) in
      let schedule,coverage,races=Historical_schedule.family ~timeout_ms ~input:n ~capacity:launch.capacity backend launch.family in
      report ~schedule (if parameter then Some n else None) (coverage_status coverage)
        (export ~full:(Concrete_schedule.full coverage) schedule races)
  | Symbolic ->
      if n <> None || not parameter then invalid "symbolic analysis requires a free N";
      if launch.capacity <> 1 then report None (Unknown "symbolic analysis requires capacity 1") []
      else match Bug_traces.find_symbolic_race ~timeout_ms launch.family with
        | No_race -> report None No_race []
        | Unknown why -> report None (Unknown why) []
        | Race {n;witness} ->
            let schedule,coverage,races=Historical_schedule.symbolic_witness ~timeout_ms ~capacity:launch.capacity
              launch.family n witness in
            let status=match coverage with All_pairs -> Race_found | result -> coverage_status result in
            report ~schedule (Some n) status (export ~full:(Concrete_schedule.full coverage) schedule races)

let generate ?n ?(kv_heads=1) ?(timeout_ms=5000) method_ = function
  | Core p -> generate_core ?n ~timeout_ms method_ p
  | Layout (variant,ast) -> Vectorlayout_hivm.generate ?n ~kv_heads ~timeout_ms method_ variant ast

let core_inputs ?n = function
  | Core p ->
      let count = Z.of_int (Option.value ~default:p.launch.default_n n) in
      let schedule = Race_report.schedule p.launch count in
      let parameter = if p.launch.family.parameter=[] then None else Some count in
      p.entries,parameter,p.inputs (Some schedule) parameter
  | Layout _ -> invalid "expected a Core launch"
