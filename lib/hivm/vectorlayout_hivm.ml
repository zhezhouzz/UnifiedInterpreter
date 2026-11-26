open Stdlib
open Unified_interpreter
open Hivm_event
module D = Core_lang.Device
module R = Device_races
module A = Hivm_module
module J = Yojson.Safe.Util

let check variant ast =
  let digest = match variant with Vectorlayout.Ok -> "5d40dbba7f011e6202b48e02c8aa13ef"
    | Fail -> "907ca8a1f7a93363dbbe50e0d7ad49cf" in
  if ast.A.digest <> digest then invalid_arg "vectorlayout: HIVM module differs from the paired program"

let prefix = "@_prefill_bnsd_score_kernel_mix_"
let entry = function D.Cube -> prefix ^ "aic" | Vector _ -> prefix ^ "aiv"
let pipe p = "#hivm.pipe<PIPE_" ^ D.pipe_name p ^ ">"
let each f xs = List.concat (List.mapi f xs)

(* 同一静态动作在两侧各出现一次。属性用于区分同名调用、管线和同步方向。 *)
type role = Op of string | Call of string | Ctrl of string * string | Fence of string
          | Flag of string * string * string * string option
let local send p q id =
  Flag ((if send then "hivm.hir.set_flag" else "hivm.hir.wait_flag"),pipe p,pipe q,
        Some (Printf.sprintf "#hivm.event<EVENT_ID%d>" id))

let matrix_parts = [
  "wait_input",local false MTE2 MTE1 0; "wait_matrix_buffer",local false M MTE1 0;
  "load",Op "mmadL1.load"; "release_input",local true MTE1 MTE2 1;
  "signal_loaded",local true MTE1 M 0; "wait_loaded",local false MTE1 M 0;
  "compute",Op "mmadL1"; "release_matrix_buffer",local true M MTE1 0]

let source_sites ast name =
  let rec block parent depth (b : A.block) = each (fun i (op : A.operation) ->
    let path = parent @ [i] in
    let prop k = List.assoc k op.properties in
    let single r = [None,r] in
    let roles = match op.opcode with
      | "func.call" -> let callee = prop "callee" in
          ignore (A.entry ast callee); single (Call callee)
      | "hivm.hir.mmadL1" -> List.map (fun (part,r) -> Some part,r) matrix_parts
      | "hivm.hir.set_flag" | "hivm.hir.wait_flag" ->
          single (Flag (op.opcode,prop "set_pipe",prop "wait_pipe",List.assoc_opt "static_event_id" op.properties))
      | "hivm.hir.sync_block_set" | "hivm.hir.sync_block_wait" ->
          single (Flag (op.opcode,prop "tpipe",prop "pipe",List.assoc_opt "static_flag_id" op.properties))
      | "hivm.hir.pipe_barrier" -> single (Fence (prop "pipe"))
      | "hivm.hir.set_ctrl" -> single (Ctrl (prop "idx",prop "enable"))
      | "memref.load" | "memref.store" | "hivm.hir.copy" | "hivm.hir.fixpipe" | "hivm.hir.nd2nz"
      | "hivm.hir.vbrc" | "hivm.hir.indirect_load" | "hivm.hir.indirect_store" | "hivm.hir.debug" ->
          single (Op op.opcode)
      | _ -> [] in
    let here = List.map (fun (part,r) -> {path;opcode=op.opcode;part},depth,r) roles in
    let depth = if op.opcode="scf.for" then depth+1 else depth in
    here @ each (fun region -> each (fun index -> block (path @ [region;index]) depth)) op.regions
  ) b.body in
  block [] 0 (A.entry ast name)

let work_role queue label = match queue,label with
  | D.MTE1,"mmadL1.load" | M,"mmadL1" -> Op label
  | MTE2,"vbrc.key" -> Op "hivm.hir.vbrc"
  | MTE3,"copy.ub_to_l1" -> Op "hivm.hir.copy"
  | S,"device_print" -> Op "hivm.hir.debug"
  | S,"memref.store.scale" -> Op "memref.store"
  | MTE2,"nd2nz" | FIX,"fixpipe" | V,("indirect_load"|"indirect_store") -> Op ("hivm.hir." ^ label)
  | V,name ->
      let suffix = match String.split_on_char '.' name with
        | [f;vf] -> f ^ "_outlined_" ^ vf | [f] -> f
        | _ -> invalid_arg ("unknown outlined function " ^ name) in
      Call (prefix ^ "aiv_" ^ suffix)
  | _ -> invalid_arg ("unknown vectorlayout task " ^ label)

let device_sites (s : D.stream) =
  let rec block parent depth = each (fun i cmd ->
    let path = parent @ [i] in
    let here r = [path,depth,r] in
    match cmd with
    | D.For l -> block path (depth+1) l.body
    | If (_,yes,no) -> block (path @ [0]) depth yes @ block (path @ [1]) depth no
    | Issue (q,label,_) -> here (work_role q label)
    | Let (_,Read _) -> here (Op "memref.load")
    | Control (bit,b) -> here (Ctrl (Printf.sprintf "%d : i64" bit,string_of_bool b))
    | Barrier [q] -> here (Fence (pipe q))
    | Barrier [S;V;M;MTE1;MTE2;MTE3;FIX] -> here (Fence "#hivm.pipe<PIPE_ALL>")
    | Set (channel,p,q,e) | Wait (channel,p,q,e) ->
        let send = match cmd with Set _ -> true | _ -> false in
        let fixed = match e with D.Int (_,i) -> Some (Int64.to_int i) | _ -> None in
        (match channel,fixed with
         | Local,Some k -> here (local send p q k)
         | Local,None -> invalid_arg "unexpected dynamic local flag in vectorlayout"
         | Cross,k -> here (Flag ((if send then "hivm.hir.sync_block_set" else "hivm.hir.sync_block_wait"),
                                 pipe p,pipe q,Option.map (Printf.sprintf "%d : i64") k)))
    | Let _ | Advance_counter _ -> []
    | _ -> invalid_arg "unknown vectorlayout host instruction") in
  block [] 0 s.body

let mappings ast stream =
  let name = entry stream.D.location.core in
  let sites = Hashtbl.create 64 in
  List.iter2 (fun (path,depth,r) (origin,n,expected) ->
    if depth<>n || r<>expected then invalid_arg (Printf.sprintf
      "vectorlayout: action at %s differs from %s %s" (String.concat "." (List.map string_of_int path))
      name origin.opcode);
    Hashtbl.add sites path origin) (device_sites stream) (source_sites ast name);
  sites

let export_events ~entries ~location (model : R.model) races =
  let streams = Array.of_list model.program.streams in
  let ids = Hashtbl.create (Array.length streams) in
  Array.iteri (fun i s -> Hashtbl.add ids s.D.location i) streams;
  let signal (src,dst,p,q,k) = {receiver=Hashtbl.find ids dst;source=p;target=q;flag=k;cross=src<>dst} in
  let action = function
    | Device_run.Compute -> Compute | Barrier_step -> Barrier
    | Signal keys -> Set (List.map signal keys)
    | Await (key::rest as keys) ->
        let k = signal key in
        if k.cross then (
          if not (List.for_all (fun other -> signal other=k) rest) then invalid_arg "inconsistent cross-core wait";
          Wait_all (List.map (fun (s,_,_,_,_) -> Hashtbl.find ids s) keys,k))
        else Wait k
    | Await [] -> invalid_arg "empty device wait" in
  let pending = Hashtbl.create 256 in
  let steps = Array.mapi (fun i choice ->
    let step = model.source_steps.(i) in
    match choice with
    | Device_run.Host stream ->
        let host = List.map (fun id -> id,{location=location id;phase=Execute (Some S);action=Compute}) step.host in
        (match step.issued with None -> host | Some (id,sub) ->
          let task = {id=i;pipe=sub.queue} in
          let issued = {location=location id;action=action sub.operation;phase=Submit [task]} in
          Hashtbl.add pending (stream,sub.serial) (id,{issued with phase=Complete task});
          host @ [id,issued])
    | Finish (stream,serial) ->
        let key = stream,serial in
        let completion = Hashtbl.find pending key in
        Hashtbl.remove pending key;
        [completion]) model.steps in
  let race json =
    let field k = J.member k json in
    let target node key =
      let site = List.find (fun site -> R.identity_json site=field key) model.by_node.(node) in
      snd (List.find (fun (id,e) -> id=site.id && match e.phase with Submit _ -> false | _ -> true) steps.(node)) in
    match Race_report.numbers (field "nodes") with
    | [a;b] ->
        let first = target a "first" and second = target b "second" in
        let prefix key x y =
          let rec until = function
            | [] -> invalid_arg "race target missing from HIVM prefix"
            | (_,e)::_ when e=y -> [e]
            | (_,e)::rest -> e::until rest in
          let rec convert acc = function
            | [] -> invalid_arg "empty device prefix"
            | [last] -> List.rev_append acc (until steps.(last))
            | n::rest -> convert (List.fold_left (fun acc (_,e) -> e::acc) acc steps.(n)) rest in
          let events = convert [] (Race_report.numbers (field key)) in
          if List.filter (fun e -> e=x || e=y) events <> [x;y] then invalid_arg "incorrect HIVM race order";
          events in
        {first;second;forward=prefix "forward" first second;reverse=prefix "reverse" second first}
    | _ -> invalid_arg "expected two conflicting accesses" in
  Array.to_list (Array.mapi (fun i name -> i,name) entries),List.map race races

let export ast (model : R.model) races =
  let streams = Array.of_list model.program.streams in
  let entries = Array.map (fun s -> entry s.D.location.core) streams in
  let maps = Array.map (mappings ast) streams in
  let location (id : R.identity) =
    let origin = Hashtbl.find maps.(id.stream) id.path and s = streams.(id.stream) in
    let iterations = match id.loops with [] -> [] | pid::rest ->
      let offset = pid-s.location.block in
      if offset<0 || offset mod 28<>0 then invalid_arg "invalid block loop induction value";
      offset/28::rest in
    {stream=id.stream;entry=entries.(id.stream);origin;iterations} in
  export_events ~entries ~location model races

let generate ?n ~kv_heads ~timeout_ms method_ variant ast =
  let config = {Vectorlayout_input.default with
    length=Option.value ~default:Vectorlayout_input.default.length n;kv_heads} in
  let name = "vectorlayout/" ^ Vectorlayout.variant_name variant in
  let report (input : Vectorlayout_input.input) (m : R.model) status witnesses =
    let streams,races = export ast m witnesses in
    let coordinates = List.mapi (fun id s -> `Assoc ["stream",`Int id;"block",`Int s.D.location.block;
      "core",`String (D.core_name s.location.core)]) m.program.streams in
    {benchmark=name;streams;n=Some (Z.of_int input.config.length);races;status;
     inputs=`Assoc ["ast_format",`String "hivm-module-1";"ast_digest",`String ast.A.digest;
                    "config",Device_trace.config input.config;
                    "bindings",Device_trace.bindings (Vectorlayout_input.hivm_arguments input);
                    "coordinates",`List coordinates]} in
  match method_ with
  | Benchmark_traces.Concrete backend ->
      let input = Vectorlayout_input.make config in
      let m = R.compile ~backend variant input in
      report input m Complete_search (R.generate m)
  | Symbolic ->
      if n<>None then invalid_arg "symbolic analysis requires a free N";
      match Device_symbolic.find_model ~timeout_ms variant config with
      | Ok (input,m,w) -> report input m Race_found [w]
      | Error reason -> {benchmark=name;streams=[];n=None;
                         inputs=`Assoc ["ast_format",`String "hivm-module-1";"ast_digest",`String ast.digest];
                         status=Unknown reason;races=[]}
