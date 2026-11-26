open Stdlib
open Unified_interpreter
module Ast = Attention_runtime.Parser
module C = Core_lang
module Device_ast = C.Device
module J = Yojson.Safe.Util
module Module_ast = Hivm_module
module Mlir = Mlir_lowering
module Mlir_device = Mlir_device
include Hivm_event

let invalid fmt = Printf.ksprintf (fun s -> invalid_arg ("Hivm_trace: " ^ s)) fmt
let path_name path = "[" ^ String.concat "," (List.map string_of_int path) ^ "]"

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
  entries : (int * string) list; sites : (int * int list, origin) Hashtbl.t;
  inputs : Race_report.Schedule.t option -> Z.t option -> Yojson.Safe.t;
}
type pairing = Core of core_pairing | Layout of Vectorlayout.variant * Module_ast.t

let pipe_name pipe = "PIPE_" ^ Device_ast.pipe_name pipe
let pipe_of pipes p =
  if p = C.scalar_pipe then S else
    match List.assoc_opt p pipes with Some pipe -> pipe | None -> invalid "unmapped Core pipe %d" p

(* 只省略在单条流中求值的纯控制和标量指令。每个其余位置都必须有来源。 *)
let core_sites body =
  let rec walk site loops cmd rest =
    let next cmd = walk (0 :: site) loops cmd rest in
    match cmd with
    | C.Return _ | End | Yield _ -> rest
    | Scalar (_, _, _, cmd) -> next cmd
    | Branch _ | Branch_values _ -> invalid "paired conditional needs an explicit HIVM branch region mapping at %s"
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
  | "memref.alloc" -> [None, Allocation]
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
      Hashtbl.add sites (s.id,site) actual) static target;
    s.id, where.program.name) launch.family.streams in
  if List.length streams <> List.length entries then invalid "%s: extra stream mapping" name;
  Core {name;launch;pipes;entries;sites;inputs=(fun _ _ -> launch.fixture)}

let strings xs = `List (List.map (fun x -> `String x) xs)
let ints xs = `List (List.map (fun x -> `Int x) xs)
let optional f = function Some x -> f x | None -> `Null

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
    let bind site check =
      let path=List.assoc site bindings in
      let op=Module_ast.resolve ast ~entry path in
      let attr key = List.assoc_opt key (op.attributes @ op.properties) in
      if not (check op.opcode attr) then invalid "%s: incompatible HIVM operation at %s %s" name entry (path_name path);
      incr seen; Hashtbl.add sites (s.id,site) {path;opcode=op.opcode;part=None} in
    let pip p = "#hivm.pipe<" ^ pipe_name (pipe_of pipes p) ^ ">" in
    let rec walk site cmd =
      let child i cmd = walk (site @ [i]) cmd in
      match cmd with
      | C.End | Return _ | Yield _ -> ()
      | Scalar (_,_,_,rest) -> child 0 rest
      | For (_,_,_,_,body,rest) | For_values (_,_,_,_,_,_,body,rest) -> child 0 body; child 1 rest
      | Branch (_,a,b,rest) | Branch_values (_,_,a,b,rest) -> child 0 a; child 1 b; child 2 rest
      | Alloc (_,_,_,rest) ->
          bind site (fun code attr -> code="memref.alloc" || code="func.call" && attr "callee"=Some "@reserve");
          child 0 rest
      | Issue (p,f,_,rest) ->
          let fn=launch.op_name f in
          bind site (fun code attr ->
            if generated then code="func.call" && attr "hivm.pipe"=Some (pip p) &&
              List.mem (attr "callee") [Some ("@"^fn);Some ("@"^fn^"_shared")]
            else match fn with
              | "indirect_atomic_add" -> code="hivm.hir.custom" && attr "symbol"=Some "\"__builtin_indirect_atomic\""
              | "scalarstore" -> code="memref.store" && p=C.scalar_pipe
              | _ -> code="hivm.hir."^fn);
          child 0 rest
      | Barrier (b,rest) ->
          bind site (fun code attr -> code="hivm.hir.pipe_barrier" &&
            attr "pipe"=Some (match b with All -> "#hivm.pipe<PIPE_ALL>" | Pipe p -> pip p)); child 0 rest
      | Sync (mode,p,q,_,rest) ->
          let short,src,dst = match mode with
            | LocalSet -> "set_flag","set_pipe","wait_pipe" | LocalWait -> "wait_flag","set_pipe","wait_pipe"
            | BlockSet -> "sync_block_set","tpipe","pipe" | BlockWait -> "sync_block_wait","tpipe","pipe" in
          bind site (fun code attr -> code="hivm.hir."^short && attr src=Some (pip p) &&
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

let export_races ~pipes ~entries ~source schedule witnesses =
  let open Race_report.Schedule in
  let index = Race_report.index schedule in
  let conflicts = Hashtbl.create (List.length schedule.pairs) in
  List.iter (fun p -> Hashtbl.add conflicts (p.a,p.b) p.addresses) schedule.pairs;
  let finish = Hashtbl.create 32 in
  Array.iteri (fun i node -> match node.phase with
    | Finish f -> Hashtbl.add finish (node.id,f.pipe) i
    | Emit _ -> ()) schedule.nodes;
  let pipe = pipe_of pipes in
  let task id p = {id=Hashtbl.find finish (id,p);pipe=pipe p} in
  let signal (k : C.key) = {receiver=k.receiver; source=pipe k.source;
    target=(match k.target with ScalarEnd -> S | Data p -> pipe p);flag=k.flag;cross=k.block} in
  let action = function
    | C.Operation _ -> Compute | Bar -> Barrier
    | Set keys -> Set (List.map signal keys) | Wait k -> Wait (signal k) in
  let at (id : C.occurrence) phase action =
    Option.map (fun origin ->
      {location={stream=id.stream;entry=List.assoc id.stream entries;
                 origin;iterations=id.iterations};action;phase}) (source id.stream id.site) in
  let convert = function
    | C.Issued (_, Control) -> None
    | Issued (id, Reserve _) -> at id (Execute None) Allocate
    | Issued (id, Immediate item) -> at id (Execute (Some S)) (action item)
    | Issued (id, Scalar_wait key) -> at id (Execute (Some S)) (Wait (signal key))
    | Issued (id, Submit (p,item)) -> at id (Submit [task id p]) (action item)
    | Issued (id, Fence ps) -> at id (Submit (List.map (task id) ps)) Barrier
    | Done {id;pipe=p;item;_} -> at id (Complete (task id p)) (action item) in
  let export (w : Bug_traces.race_witness) =
    let rec last = function [x] -> x | _ :: xs -> last xs | [] -> invalid "empty race prefix" in
    let forward = w.first_then_second and reverse = w.second_then_first in
    let a = index (last reverse) and b = index (last forward) in
    if Hashtbl.find_opt conflicts (a,b) <> Some w.conflicts ||
       schedule.nodes.(a).id <> w.first || schedule.nodes.(b).id <> w.second then
      invalid "target operations differ from the paired program";
    let checked x y events =
      let ids = List.map index events in
      if replay_indices schedule ids <> events || List.filter (fun n -> n=a || n=b) ids <> [x;y]
      then invalid "invalid race prefix";
      List.filter_map convert events in
    let forward = checked a b forward and reverse = checked b a reverse in
    {first=last reverse;second=last forward;forward;reverse} in
  List.map export witnesses

let generate_core ?n ~timeout_ms method_ pairing =
  let launch = pairing.launch in
  let report ?schedule n status races = {benchmark=pairing.name;streams=pairing.entries;n;
                                inputs=pairing.inputs schedule n;status;races} in
  let parameter = launch.family.parameter <> [] in
  let export = export_races ~pipes:pairing.pipes ~entries:pairing.entries
    ~source:(fun stream site -> Some (Hashtbl.find pairing.sites (stream,site))) in
  match method_ with
  | Benchmark_traces.Concrete backend ->
      if n <> None && not parameter then invalid "fixed entry parameters";
      let n = Z.of_int (Option.value n ~default:launch.default_n) in
      let schedule = Race_report.schedule launch n in
      let result = Race_report.witnesses backend schedule in
      report ~schedule (if parameter then Some n else None) Complete_search (export schedule result.races)
  | Symbolic ->
      if n <> None || not parameter then invalid "symbolic analysis requires a free N";
      if launch.capacity <> 1 then report None (Unknown "symbolic analysis requires capacity 1") []
      else match Bug_traces.find_symbolic_race ~timeout_ms launch.family with
        | No_race -> report None No_race []
        | Unknown why -> report None (Unknown why) []
        | Race {n;witness} ->
            let schedule=Race_report.schedule launch n in
            report ~schedule (Some n) Race_found (export schedule [witness])

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

let to_json report =
  let task (t : task) = `Assoc ["id",`Int t.id;"pipe",`String (pipe_name t.pipe)] in
  let signal s = `Assoc ["receiver",`Int s.receiver;"source",`String (pipe_name s.source);
    "target",`String (pipe_name s.target);"flag",`Int s.flag;"cross",`Bool s.cross] in
  let encode_event e =
    let l = e.location in
    let action, signals = match e.action with
      | Compute -> "compute",[] | Allocate -> "allocate",[] | Barrier -> "barrier",[]
      | Set ks -> "set",ks | Wait k | Wait_all (_,k) -> "wait",[k] in
    let phase, tasks, synchronous_pipe = match e.phase with
      | Submit ts -> "submit",ts,None | Complete t -> "complete",[t],None
      | Execute p -> "execute",[],p in
    let senders = match e.action with Wait_all (ss,_) -> ["senders",ints ss] | _ -> [] in
    `Assoc (["entry",`String l.entry;"stream",`Int l.stream;"path",ints l.origin.path;
            "opcode",`String l.origin.opcode;"part",optional (fun x -> `String x) l.origin.part;
            "iterations",ints l.iterations;"action",`String action;"phase",`String phase;
            "tasks",`List (List.map task tasks);"signals",`List (List.map signal signals);
            "synchronous_pipe",optional (fun p -> `String (pipe_name p)) synchronous_pipe] @ senders) in
  let encoded = Hashtbl.create 256 in
  let event e = match Hashtbl.find_opt encoded e with
    | Some json -> json
    | None -> let json = encode_event e in Hashtbl.add encoded e json; json in
  let race r = `Assoc ["first",event r.first;"second",event r.second;
    "forward",`List (List.map event r.forward);"reverse",`List (List.map event r.reverse)] in
  let status,details = match report.status with Complete_search -> "complete",[] | Race_found -> "race",[]
    | No_race -> "no-race",[] | Unknown why -> "unknown",["reason",`String why] in
  `Assoc (["format",`String "hivm-race-1";"benchmark",`String report.benchmark;
    "streams",`List (List.map (fun (id,entry) -> `Assoc ["stream",`Int id;"entry",`String entry]) report.streams);
    "n",optional (fun n -> if Z.fits_int n then `Int (Z.to_int n) else `Intlit (Z.to_string n)) report.n;
    "inputs",report.inputs;
    "status",`String status;"races",`List (List.map race report.races)] @ details)

let mlir_schedule (lowered : Mlir.t) =
  Race_report.Schedule.compile ~capacity:lowered.launch.capacity lowered.program

let mlir_inputs (ast : Module_ast.t) launch =
  `Assoc (["ast_format",`String "mlir-module-1";"ast_digest",`String ast.digest] @
          J.to_assoc (Mlir.Launch.inputs launch))

let mlir_source (p : Mlir.source) =
  let span = match p.span with
    | None -> `Null
    | Some s -> `Assoc ["file",`String s.file;"line",`Int s.start.line;"column",`Int s.start.column] in
  `Assoc ["path",ints p.origin.path;"opcode",`String p.origin.opcode;
          "part",optional (fun part -> `String part) p.origin.part;
          "span",span;"synthetic",`Bool p.synthetic]

let mlir_events (lowered : Mlir.t) (schedule : Race_report.Schedule.t) =
  let points = List.to_seq lowered.sources |> Hashtbl.of_seq in
  let events = Race_report.events_of (Array.get lowered.operation_names) schedule |> J.to_list in
  let annotate event (node : Race_report.Schedule.node) =
    match Hashtbl.find_opt points (node.id.stream,node.id.site) with
    | None -> event
    | Some (p : Mlir.source) ->
        `Assoc (J.to_assoc event @ ["origin",mlir_source p]) in
  `List (List.map2 annotate events (Array.to_list schedule.nodes))

let analyze_core_mlir ~backend ~hivm (lowered : Mlir.t) =
  let schedule = mlir_schedule lowered in
  let witnesses = Race_report.witnesses backend schedule in
  let entries = List.map (fun (s : Mlir.Launch.stream) -> s.id,s.entry) lowered.launch.streams in
  let name = String.concat "," (List.map snd entries) and inputs = mlir_inputs lowered.ast lowered.launch in
  if hivm then (
    let points = List.to_seq lowered.sources |> Hashtbl.of_seq in
    let source stream site = match Hashtbl.find_opt points (stream,site) with
      | Some p when p.synthetic -> None
      | Some p -> Some p.origin
      | None -> invalid "missing source in lowered stream %d at %s" stream (path_name site) in
    let pipes = List.map (fun p -> Mlir.pipe_id p,p) [S;V;M;MTE1;MTE2;MTE3;FIX] in
    let races = export_races ~pipes ~entries ~source schedule witnesses.races in
    to_json {benchmark=name;streams=entries;n=None;inputs;status=Complete_search;races})
  else
    let index = Race_report.index schedule in
    `Assoc ["format",`String "core-race-1";"benchmark",`String name;
            "backend",`String (match backend with Search -> "bfs" | Solve -> "smt");
            "status",`String "complete";"capacity",`Int lowered.launch.capacity;
            "inputs",inputs;"address_unit",`String "byte";"events",mlir_events lowered schedule;
            "races",`List (List.map (Race_report.core_race schedule index) witnesses.races)]

let verify_mlir_report report inputs capacity unit events =
  if J.member "format" report <> `String "core-race-1" || J.member "inputs" report <> inputs ||
     J.member "capacity" report <> `Int capacity || J.member "address_unit" report <> `String unit ||
     J.member "events" report <> events
  then invalid "MLIR report does not match this source module and launch";
  J.to_list (J.member "races" report)

let replay_core_mlir (lowered : Mlir.t) report =
  let schedule = mlir_schedule lowered in
  let races = verify_mlir_report report (mlir_inputs lowered.ast lowered.launch) lowered.launch.capacity
      "byte" (mlir_events lowered schedule) in
  List.iter (Race_report.replay_core schedule) races;
  2 * List.length races

type lowered_mlir = Core_mlir of Mlir.t | Device_mlir of Mlir_device.t

let lower_mlir ?entry ?configuration ast =
  let launch = Mlir.Launch.bind ?entry ?configuration ast in
  if Mlir_device.required launch then Device_mlir (Mlir_device.lower_with_launch ast launch)
  else Core_mlir (Mlir.lower_with_launch ast launch)

let mlir_device_model ~backend (lowered : Mlir_device.t) =
  let points = List.to_seq lowered.sources |> Hashtbl.of_seq in
  let rec describe stream path message = match Hashtbl.find_opt points (stream,path) with
    | Some (p : Mlir.source) ->
        let location = Option.fold p.span ~none:"" ~some:(fun span ->
          Attention_runtime.Source.describe span ^ ": ") in
        location ^ p.origin.opcode ^ ": " ^ message
    | None -> (match List.rev path with
        | _::parent -> describe stream (List.rev parent) message | [] -> message) in
  Device_races.compile_memory ~backend ~iteration_ordinals:true ~describe
    lowered.program lowered.memory lowered.bindings

let analyze_device_mlir ~backend ~hivm (lowered : Mlir_device.t) =
  let model = mlir_device_model ~backend lowered in
  let races = Device_races.generate model in
  let inputs = mlir_inputs lowered.ast lowered.launch and name = lowered.program.name in
  if hivm then (
    let entries = Array.of_list (List.map (fun (s : Mlir.Launch.stream) -> s.entry) lowered.launch.streams) in
    let points = List.to_seq lowered.sources |> Hashtbl.of_seq in
    let location (id : Device_races.identity) =
      let origin = (Hashtbl.find points (id.stream,id.path) : Mlir.source).origin in
      {stream=id.stream;entry=entries.(id.stream);origin;iterations=id.loops} in
    let streams,races = Vectorlayout_hivm.export_events ~entries ~location model races in
    to_json {benchmark=name;streams;n=None;inputs;status=Complete_search;races})
  else
    let sources = List.map (fun ((stream,path),source) ->
        `Assoc ["stream",`Int stream;"path",ints path;"origin",mlir_source source]) lowered.sources in
    `Assoc ["format",`String "core-race-1";"benchmark",`String name;
            "backend",`String (match backend with Search -> "bfs" | Solve -> "smt");
            "status",`String "complete";"capacity",`Int lowered.launch.capacity;
            "inputs",inputs;"address_unit",`String "bit";"events",Device_races.events model;
            "sources",`List sources;"races",`List races]

let analyze_mlir ~backend ?(hivm=false) = function
  | Core_mlir p -> analyze_core_mlir ~backend ~hivm p
  | Device_mlir p -> analyze_device_mlir ~backend ~hivm p

let replay_mlir lowered report = match lowered with
  | Core_mlir p -> replay_core_mlir p report
  | Device_mlir p ->
      let model = mlir_device_model ~backend:Bug_traces.Search p in
      let races = verify_mlir_report report (mlir_inputs p.ast p.launch) p.launch.capacity
          "bit" (Device_races.events model) in
      List.iter (Device_races.replay_witness model) races;
      2 * List.length races
