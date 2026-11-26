open Device_run
open Device_eval

type footprint = {reads : access list;writes : access list}
type identity = {stream : int; path : int list; loops : int list; label : string; pipe : Device_ast.pipe}
type source_step = {host : identity list; issued : (identity * submission) option}
let identity (e : event) = {stream=e.stream;path=e.path;loops=e.iterations;label=e.site;pipe=e.pipe}
type access_site = {id : identity; node : int; observed : footprint; possible : footprint;
                    conditional_writes : access list}
type cached = {env : (string * Device_value.value) list; inputs : (access * string) list;
               outputs : (access * string) list; access : observation}
type model = {program : Device_ast.program; memory : Device_value.memory;
              bindings : (string * Device_value.value) list; iteration_ordinals : bool; steps : choice array;
              source_steps : source_step array;
              parents : int list array; graph : Precedence.t; sites : access_site list;
              banks : (choice,Device_value.bank list) Hashtbl.t; cache : (choice,cached list) Hashtbl.t;
              selectors : (int,access list * access list) Hashtbl.t;
              indexed : (int,access list) Hashtbl.t;
              transfers : (int,(access list * access list option) list) Hashtbl.t;
              blocks : int array; independent : bool;
              descriptors : Yojson.Safe.t array;
              verified : ((bool * int list * identity),footprint) Hashtbl.t;
              by_node : access_site list array; mutable_banks : (Device_value.bank,unit) Hashtbl.t;
              writers_by_bank : (Device_value.bank,access_site list) Hashtbl.t;
              host_accesses : (int,access_site list) Hashtbl.t;
              read_write : (choice,Device_value.bank list) Hashtbl.t}

let intersect xs ys =
  let rec loop result xs ys = match xs,ys with
    | [],_ | _,[] -> List.rev result
    | x::xt,y::yt ->
        let c = compare x.bank y.bank in
        if c<0 || (c=0 && x.limit<=y.first) then loop result xt ys
        else if c>0 || y.limit<=x.first then loop result xs yt
        else
          let result = {x with first=max x.first y.first;limit=min x.limit y.limit}::result in
          if x.limit<y.limit then loop result xt ys else loop result xs yt in
  loop [] xs ys
let conflict x y =
  ranges (intersect x.writes y.reads @ intersect x.writes y.writes @ intersect x.reads y.writes)

let sites node (t : transition) =
  let whole = match t.choice with Host _ -> None | Finish _ ->
    Some (identity (List.find (fun e -> e.phase="done") t.observations)) in
  let table = Hashtbl.create 2 in
  List.iter (fun e -> Option.iter (fun (o : observation) ->
    let id = Option.value ~default:(identity e) whole in
    let r,w,pr,pw = Option.value ~default:([],[],[],[]) (Hashtbl.find_opt table id) in
    Hashtbl.replace table id (List.rev_append o.reads r,List.rev_append o.writes w,
      List.rev_append o.possible_reads pr,List.rev_append o.possible_writes pw)
  ) e.observation) t.observations;
  Hashtbl.to_seq table |> List.of_seq |> List.sort compare |> List.filter_map (fun (id,(r,w,pr,pw)) ->
    match r,w,pr,pw with [],[],[],[] -> None | _ ->
      Some {node;id;observed={reads=ranges r;writes=ranges w};conditional_writes=ranges pw;
            possible={reads=ranges (List.rev_append r pr);writes=ranges (List.rev_append w pw)}})

let compile_memory ?(backend=Bug_traces.Search) ?(readonly=[]) ?(immutable_views=[])
    ?(iteration_ordinals=false) ?describe program memory bindings =
  let direct = Device_dependencies.direct_stores ?describe ~immutable_views program in
  let selectors = Hashtbl.create 16 and transfers = Hashtbl.create 64 and indexed=Hashtbl.create 16 in
  let previous = Hashtbl.create 16 and blocked = Hashtbl.create 8 and queues = Hashtbl.create 16
  and pending = Hashtbl.create 128 and flags = Hashtbl.create 32 in
  let rows = ref [] and actions = ref [] and access = ref [] and count = ref 0 and descriptors = ref [] in
  let source_steps = ref [] in
  let on_step t =
    let n = !count in incr count;
    let info = List.find_opt (fun e -> e.phase="issued" || e.phase="done") t.observations in
    let host = match t.choice with Finish _ -> [] | Host _ ->
      List.filter_map (fun e -> Option.map (fun _ -> identity e) e.observation) t.observations in
    let issued = Option.map (fun sub -> identity (Option.get info),sub) t.submission in
    source_steps := {host;issued} :: !source_steps;
    let fields = match info with None -> ["phase",`String "host"] | Some e ->
      ["phase",`String e.phase;"pipe",`String (Device_ast.pipe_name e.pipe);"label",`String e.site;
       "path",Race_report.ints e.path;"iterations",Race_report.ints e.iterations] in
    descriptors := `Assoc (("choice",Device_trace.choice t.choice)::fields) :: !descriptors;
    let earlier_writes=Hashtbl.create 4 and source_reads=Hashtbl.create 16 and internal_selector=ref false in
    let previously_written r=match Hashtbl.find_opt earlier_writes r.bank with
      | None -> false | Some spans -> intersect [r] spans<>[] in
    List.iter (fun (e : event) -> Option.iter (fun (o:observation) ->
      if o.reads<>[] then (
        let reads=if List.exists previously_written o.reads then None else Some o.reads in
        let reads=match Hashtbl.find_opt source_reads e.path with
          | Some (loops,prior) when loops=e.iterations ->
              Option.bind prior (fun xs -> Option.map (fun ys -> ranges (xs@ys)) reads)
          | _ -> reads in
        Hashtbl.replace source_reads e.path (e.iterations,reads));
      if o.masks<>[] then (
        if List.exists previously_written (o.masks@o.offsets) then internal_selector:=true;
        Hashtbl.replace indexed n (ranges (o.indexed@Option.value ~default:[] (Hashtbl.find_opt indexed n)));
        let m,x=Option.value ~default:([],[]) (Hashtbl.find_opt selectors n) in
        Hashtbl.replace selectors n (ranges (o.masks@m),ranges (o.offsets@x)));
      if o.writes<>[] then (
        let reads = Option.bind (Hashtbl.find_opt direct (e.stream,e.path)) (fun paths ->
          List.fold_left (fun acc path ->
            Option.bind acc (fun rs -> Option.bind (Hashtbl.find_opt source_reads path) (fun (_,src) ->
              Option.map (List.rev_append rs) src))) (Some []) paths |> Option.map ranges) in
        let prev = Option.value ~default:[] (Hashtbl.find_opt transfers n) in
        Hashtbl.replace transfers n ((o.writes,reads)::prev));
      List.iter (fun r -> Hashtbl.replace earlier_writes r.bank
        (ranges (r::Option.value ~default:[] (Hashtbl.find_opt earlier_writes r.bank)))) (o.writes@o.possible_writes)
    ) e.observation) t.observations;
    let parents = ref [] in
    let require a = parents := a :: !parents in
    let require_previous table key = Option.iter require (Hashtbl.find_opt table key) in
    (match t.choice with
     | Host stream ->
         require_previous previous stream;
         require_previous blocked stream;
         Hashtbl.remove blocked stream;
         Hashtbl.replace previous stream n;
         Option.iter (fun task -> Hashtbl.add pending (stream,task.serial) (n,task)) t.submission
     | Finish (s,i) ->
         let issue,task = Hashtbl.find pending (s,i) in
         require issue;
         if task.synchronous then Hashtbl.replace blocked s n;
         let q = s,task.queue in
         let completed = Option.value ~default:[] (Hashtbl.find_opt queues q) in
         let touch key send =
           let sends,waits = Option.value ~default:([],[]) (Hashtbl.find_opt flags key) in
           Hashtbl.replace flags key (if send then n::sends,waits else sends,n::waits) in
         List.iter (fun (serial,earlier,op) -> if serial<i then match task.operation,op with
           | (Signal _ | Barrier_step),_ | _,(Await _ | Barrier_step) -> require earlier | _ -> ()) completed;
         Hashtbl.replace queues q ((i,n,task.operation)::completed);
         (match task.operation with Signal ks -> List.iter (fun k -> touch k true) ks
           | Await ks -> List.iter (fun k -> touch k false) ks | _ -> ()));
    let touched=sites n t in
    if !internal_selector then (
      let reads=List.concat_map (fun s -> s.possible.reads) touched in
      Hashtbl.replace selectors n (ranges reads,[]));
    access := List.rev_append touched !access;
    rows := !parents :: !rows; actions := t.choice :: !actions in
  ignore (run ~on_step ~record_events:false ~iteration_ordinals program memory bindings);
  let parents = Array.of_list (List.rev !rows) in
  Hashtbl.iter (fun _ (s,w) ->
    let sends = Array.of_list (List.rev s) and waits = Array.of_list (List.rev w) in
    Array.iteri (fun i n -> parents.(n) <- sends.(i) :: parents.(n)) waits;
    Array.iteri (fun i n -> if i>0 then parents.(n) <- waits.(i-1) :: parents.(n)) sends) flags;
  let steps = Array.of_list (List.rev !actions) and sites = List.rev !access in
  let banks = Hashtbl.create 64 in
  let read_write = Hashtbl.create 64 and by_node=Array.make (Array.length steps) []
  and mutable_banks = Hashtbl.create 64 in
  let writers_by_bank=Hashtbl.create 32 and host_accesses=Hashtbl.create 16 in
  let append table key site = Hashtbl.replace table key
    (site::Option.value ~default:[] (Hashtbl.find_opt table key)) in
  List.iter (fun a ->
    let writes=List.map (fun r -> r.bank) a.possible.writes |> List.sort_uniq compare in
    let prior=Option.value ~default:[] (Hashtbl.find_opt banks steps.(a.node)) in
    Hashtbl.replace banks steps.(a.node) (List.sort_uniq compare (writes@prior));
    by_node.(a.node) <- a::by_node.(a.node);
    (match steps.(a.node) with Host s -> append host_accesses s a | Finish _ -> ());
    List.iter (fun bank -> Hashtbl.replace mutable_banks bank ();append writers_by_bank bank a)
      writes;
    Hashtbl.replace read_write steps.(a.node) (List.filter (fun bank ->
      List.exists (fun r -> r.bank=bank) a.possible.reads) (Hashtbl.find banks steps.(a.node)))) sites;
  List.iter (fun bank -> if Hashtbl.mem mutable_banks bank then
    invalid_arg "device launch metadata is writable") readonly;
  let graph = Precedence.compile (match backend with Bug_traces.Search -> Bfs | Solve -> Smt) parents in
  let locations = Array.of_list program.streams in
  let blocks = Array.map (function Host s | Finish (s,_) -> locations.(s).location.block) steps in
  let readers = Hashtbl.create 32 and writers = Hashtbl.create 32 in
  List.iter (fun a ->
    let mark table r = Hashtbl.replace table (r.bank,blocks.(a.node)) () in
    List.iter (mark readers) a.possible.reads; List.iter (mark writers) a.possible.writes) sites;
  let independent = Hashtbl.fold (fun (bank,block) () ok -> ok &&
    not (Hashtbl.fold (fun (b,k) () found -> found || (b=bank && k<>block)) readers false)) writers true &&
    Array.for_all (fun n -> List.for_all (fun p -> blocks.(p)=blocks.(n)) parents.(n)) graph.order in
  {program;memory;bindings;iteration_ordinals;parents;steps;source_steps=Array.of_list (List.rev !source_steps);
   banks;cache=Hashtbl.create 128;graph;sites;selectors;transfers;indexed;
   blocks;independent;descriptors=Array.of_list (List.rev !descriptors);
   verified=Hashtbl.create 128;by_node;mutable_banks;read_write;writers_by_bank;host_accesses}

let compile_program ?backend program (input : Vectorlayout_input.input) =
  let readonly = List.map (fun i -> Device_value.Global i) [4;5;6;7;8] in
  let immutable_views = List.filter_map (function
    | name,Device_value.View v when List.mem v.bank readonly -> Some name | _ -> None) input.bindings in
  compile_memory ?backend ~readonly ~immutable_views program input.memory input.bindings

let compile ?backend variant input =
  compile_program ?backend (Vectorlayout.make variant input.Vectorlayout_input.blocks) input

let byte_span r = r.first/8,(r.limit+7)/8 - r.first/8
let capture bank r = let at,len = byte_span r in r,Bytes.sub_string (bank r.bank) at len
let matches bank (r,data) =
  let at,len = byte_span r and bytes = bank r.bank in
  let rec loop i = if i+8<=len then
    Bytes.get_int64_ne bytes (at+i)=String.get_int64_ne data i && loop (i+8)
    else i=len || (String.get data i=Bytes.get bytes (at+i) && loop (i+1)) in loop 0
let restore bank (r,data) =
  let at,len = byte_span r and bytes = bank r.bank in
  let boundary i =
    let mask = (255 lsl (max 0 (r.first-8*(at+i)))) land
      (255 lsr (max 0 (8*(at+i+1)-r.limit))) in
    Bytes.set_uint8 bytes (at+i) ((Bytes.get_uint8 bytes (at+i) land (lnot mask)) lor
      (Char.code data.[i] land mask)) in
  if len=1 then boundary 0 else (
    boundary 0;Bytes.blit_string data 1 bytes (at+1) (len-2);boundary (len-1))

(* 每条已提交的 vectorlayout 计算只修改内存。缓存键包含发射时捕获的
   寄存器和实际读取的字节。部分字节写入仅恢复命中的位。 *)
let execute model stream serial env (c : Device_eval.context) work =
  let key = Finish (stream,serial) and bank = Hashtbl.find c.memory in
  let entries = Option.value ~default:[] (Hashtbl.find_opt model.cache key) in
  match List.find_opt (fun e -> e.env=env && List.for_all (matches bank) e.inputs) entries with
  | Some entry -> List.iter (restore bank) entry.outputs; c.observe entry.access
  | None ->
      let banks = Option.value ~default:[] (Hashtbl.find_opt model.banks key) in
      let before = List.map (fun b -> b,Bytes.copy (bank b))
        (Option.value ~default:[] (Hashtbl.find_opt model.read_write key)) in
      let initial b = match List.assoc_opt b before with Some bytes -> bytes | None -> bank b in
      let observed = ref [] and observe = c.observe in
      c.observe <- (fun o -> observed := o :: !observed);
      Fun.protect work ~finally:(fun () -> c.observe <- observe);
      let combine f = ranges (List.concat_map f !observed) in
      let access = {operation="completion";reads=combine (fun o -> o.reads);
        writes=combine (fun o -> o.writes);possible_reads=combine (fun o -> o.possible_reads);
        possible_writes=combine (fun o -> o.possible_writes);detail="";evidence=None;
        masks=combine (fun o -> o.masks);offsets=combine (fun o -> o.offsets);indexed=combine (fun o -> o.indexed)} in
      if List.exists (fun r -> not (List.mem r.bank banks)) access.writes then invalid_arg "unexpected write bank";
      let entry = {env;inputs=List.map (capture initial) access.reads;
        outputs=List.map (capture bank) access.writes;access} in
      Hashtbl.replace model.cache key (entry::entries);observe access

exception Invalid_prefix of int

let difference xs ys =
  let rec split acc xs ys = match xs,ys with
    | [],_ -> List.rev acc | _,[] -> List.rev_append acc xs
    | x::xt,y::yt ->
        if x.bank<y.bank || (x.bank=y.bank && x.limit<=y.first) then split (x::acc) xt ys
        else if y.bank<x.bank || y.limit<=x.first then split acc xs yt
        else
          let acc = if x.first<y.first then {x with limit=y.first}::acc else acc in
          if x.limit<=y.limit then split acc xt ys else split acc ({x with first=y.limit}::xt) yt in
  split [] xs ys

let write_inputs model site span =
  let transfers = Option.value ~default:[] (Hashtbl.find_opt model.transfers site.node) in
  if difference span site.observed.writes<>[] then site.possible.reads else
    List.concat_map (fun (out,inputs) -> if intersect span out=[] then [] else
      Option.value ~default:site.possible.reads inputs) transfers

let definite site = difference site.observed.writes site.conditional_writes

(* 反向计算决定目标足迹及每次间接寻址合法性的输入。发射与同步仍按原调度执行。 *)
let slice model nodes wanted =
  let active = Hashtbl.create 32 and live = ref [] in
  let add rs = live := ranges (List.rev_append
    (List.filter (fun r -> Hashtbl.mem model.mutable_banks r.bank) rs) !live) in
  List.iter (fun n ->
    List.iter (fun site -> match model.steps.(n) with
      | Host _ -> add site.possible.reads
      | Finish _ as key ->
          let span = intersect !live site.possible.writes in
          let selector = Hashtbl.find_opt model.selectors n in
          if span<>[] || Option.is_some selector || List.exists (fun s -> s.node=n) wanted then (
            Hashtbl.replace active key ();
            live := difference !live (definite site);
            if span<>[] then add (write_inputs model site span);
            Option.iter (fun (m,o) -> add m;add o) selector)) model.by_node.(n)) (List.rev nodes);
  active

let footprints ?(sliced=true) model nodes wanted =
  let order = ref nodes and hits = ref [] in
  let on_step t = match !order with [] -> assert false | n::ns -> order := ns;
    if List.exists (fun site -> site.node=n) wanted then
      hits := List.rev_append (sites n t) !hits in
  let prefix = List.map (Array.get model.steps) nodes in
  let banks = Hashtbl.create 16 in
  List.iter (fun choice -> Option.iter (List.iter (fun bank -> Hashtbl.replace banks bank ()))
    (Hashtbl.find_opt model.banks choice)) prefix;
  let active = if sliced then Some (slice model nodes wanted) else None in
  let work s i env c f = if Option.fold ~none:true ~some:(fun a -> Hashtbl.mem a (Finish (s,i))) active
    then execute model s i env c f in
  (try ignore (run ~prefix ~on_step ~execute:work ~copy_bank:(Hashtbl.mem banks) ~record_events:false
     ~iteration_ordinals:model.iteration_ordinals model.program model.memory model.bindings)
   with Invalid_indirect_address _ -> raise (Invalid_prefix (List.hd !order)));
  let find site = (List.find (fun x -> x.node=site.node && x.id=site.id) !hits).observed in
  List.map find wanted

let local_footprint ?(sliced=true) model nodes site =
  let key = sliced,nodes,site.id in match Hashtbl.find_opt model.verified key with
  | Some fp -> fp | None ->
      let fp = List.hd (footprints ~sliced model nodes [site]) in Hashtbl.add model.verified key fp;fp

let replay ?(sliced=true) model nodes wanted =
  let fps = match wanted with [a;b] when model.independent && model.blocks.(a.node)<>model.blocks.(b.node) ->
    List.map (fun site ->
      let prefix = List.filter (fun n -> model.blocks.(n)=model.blocks.(site.node)) nodes in
      local_footprint ~sliced model prefix site) wanted
  | _ -> footprints ~sliced model nodes wanted in match fps with
  | [a;b] -> conflict a b | _ -> invalid_arg "expected two target sites"

let candidates model =
  let rec pairs result = function [] -> List.rev result | a::tail ->
    let result = List.fold_left (fun result b ->
      if a.node<>b.node && Precedence.unordered model.graph a.node b.node &&
         conflict a.possible b.possible <> [] then (a,b)::result else result) result tail in
    pairs result tail in
  pairs [] model.sites

let identity_json site =
  let id = site.id in
  `Assoc ["stream",`Int id.stream;"path",Race_report.ints id.path;"iterations",Race_report.ints id.loops;
    "label",`String id.label;"pipe",`String (Device_ast.pipe_name id.pipe)]

let events model =
  let ids = Array.make (Array.length model.steps) [] in
  List.iter (fun site -> ids.(site.node) <- identity_json site :: ids.(site.node)) model.sites;
  `List (Array.to_list (Array.mapi (fun n descriptor ->
    `Assoc (("accesses",`List ids.(n))::Yojson.Safe.Util.to_assoc descriptor)) model.descriptors))

let witness a b conflicts f r =
  `Assoc ["nodes",Race_report.ints [a.node;b.node];"first",identity_json a;"second",identity_json b;
          "conflicts",`List (List.map Device_trace.range conflicts);
          "forward",Race_report.ints f;"reverse",Race_report.ints r]

let replay_witness model j =
  let open Yojson.Safe.Util in
  let f = Race_report.numbers (member "forward" j) and r = Race_report.numbers (member "reverse" j) in
  let site n key = List.find (fun s -> s.node=n && identity_json s=member key j) model.sites in
  match Race_report.numbers (member "nodes" j) with
  | [x;y] ->
      let check a b trace =
        if List.filter (fun n -> n=x || n=y) trace<>[a;b] || List.hd (List.rev trace)<>b then
          invalid_arg "incorrect device witness order";
        let seen = Array.make (Array.length model.steps) false in
        List.iter (fun n ->
          if seen.(n) || not (List.for_all (Array.get seen) model.parents.(n))
            || (model.independent && model.blocks.(n)<>model.blocks.(a) && model.blocks.(n)<>model.blocks.(b))
            then invalid_arg "illegal device prefix";
          seen.(n) <- true) trace in
      check x y f;check y x r;
      let a = site x "first" and b = site y "second" in
      let conflicts = intersect (replay ~sliced:false model f [a;b]) (replay ~sliced:false model r [a;b]) in
      if conflicts=[] || witness a b conflicts f r <> j then invalid_arg "device witness differs"
  | _ -> invalid_arg "expected two device operations"

let minimum model a b =
  let required = Z.logor model.graph.ancestors.(a.node) model.graph.ancestors.(b.node) in
  (* 初始合法执行提供统一的拓扑顺序。两个目标均可移到闭包末尾。 *)
  let order = Array.fold_right (fun n xs -> if Z.testbit required n then n::xs else xs)
    (Array.init (Array.length model.steps) Fun.id) [] in
  let f = order @ [a.node;b.node] and r = order @ [b.node;a.node] in
  try let conflicts = intersect (replay model f [a;b]) (replay model r [a;b]) in
    if conflicts=[] then None else Some (witness a b conflicts f r)
  with Invalid_prefix _ -> None

(* 寻找尚可改变相关读取值的一对事件。每次分支确定这两个事件的
   相对顺序。必定被后续写入覆盖的位不参与读取来源的选择。 *)
let dependency model graph roots =
  let exception Choice of int * int in
  let before = Precedence.before graph and visited = Hashtbl.create 32 in
  let rec read reader needed =
    let needed=List.filter (fun r -> Hashtbl.mem model.mutable_banks r.bank) needed in
    if needed<>[] && not (Hashtbl.mem visited (reader,needed)) then (
      Hashtbl.add visited (reader,needed) ();
      let banks=List.map (fun r -> r.bank) needed |> List.sort_uniq compare in
      let sites=List.concat_map (Hashtbl.find model.writers_by_bank) banks |>
        List.sort_uniq (fun a b -> compare (a.node,a.id) (b.node,b.id)) in
      let writers = List.filter_map (fun site ->
        if site.node=reader || before reader site.node then None else
        let overlap = intersect needed site.possible.writes in
        if overlap=[] then None else Some (site,overlap)) sites in
      let live = List.filter_map (fun (w,span) ->
        let span = List.fold_left (fun span (later,_) ->
          if span<>[] && before w.node later.node && before later.node reader then
            (* 间接写入的 GM 位依赖偏移和谓词。 *)
            difference span (definite later) else span) span writers in
        if span=[] then None else (
          if not (before w.node reader) then raise (Choice (w.node,reader)); Some (w,span))) writers in
      let rec visit = function [] -> () | (w,span)::tail ->
        List.iter (fun (v,other) -> if Precedence.unordered graph w.node v.node && intersect span other<>[]
          then raise (Choice (w.node,v.node))) tail;
        let transfers = Option.value ~default:[] (Hashtbl.find_opt model.transfers w.node) in
        if List.exists (fun (out,inputs) -> inputs=None && intersect out span<>[]) transfers then
          List.iter (fun h -> if before h.node w.node then read h.node h.possible.reads)
            (Option.value ~default:[] (Hashtbl.find_opt model.host_accesses w.id.stream));
        read w.node (ranges (write_inputs model w span));visit tail in visit live) in
  try List.iter (fun (n,rs) -> read n rs) roots;None with Choice (p,q) -> Some (p,q)

let last_prefix g a b =
  let prefix = Array.to_list g.Precedence.order |> List.filter (fun n -> n<>a && Precedence.before g n b) in
  let early,late = List.partition (fun n -> not (Precedence.before g a n)) prefix in
  early @ (a::late) @ [b]

let refine model a b =
  let possible = conflict a.possible b.possible in
  let roots = List.filter_map (fun site ->
    Option.map (fun (masks,offsets) ->
      let indexed=Hashtbl.find model.indexed site.node in
      site.node,(if intersect possible indexed=[] then masks else ranges (masks@offsets)))
      (Hashtbl.find_opt model.selectors site.node)) [a;b] in
  let base = {model.graph with order=Array.init (Array.length model.steps) Fun.id} in
  let queue = ref [] in
  let enqueue f r =
    let size = Z.popcount f.Precedence.ancestors.(b.node) + Z.popcount r.Precedence.ancestors.(a.node) in
    let rec insert = function x::xs when fst x<size -> x::insert xs | xs -> (size,(f,r))::xs in
    queue := insert !queue in
  enqueue (Precedence.constrain base a.node b.node) (Precedence.constrain base b.node a.node);
  let rec search () = match !queue with
    | [] -> None
    | (_,(gf,gr))::tail ->
        queue := tail;
        let f = last_prefix gf a.node b.node and r = last_prefix gr b.node a.node in
        let evaluate trace = try replay model trace [a;b],roots with Invalid_prefix n ->
          let masks,offsets = Hashtbl.find model.selectors n in [],[n,ranges (masks@offsets)] in
        let cf,rf = evaluate f and cr,rr = evaluate r in
        let shared = intersect cf cr in
        if shared<>[] then Some (witness a b shared f r) else (
          let branch g roots one = match dependency model g roots with
            | None -> false | Some (x,y) -> one (Precedence.constrain g x y);
                one (Precedence.constrain g y x);true in
          if cf=[] then ignore (branch gf rf (fun g -> enqueue g gr))
          else if cr=[] then ignore (branch gr rr (enqueue gf))
          else if not (branch gf rf (fun g -> enqueue g gr)) then ignore (branch gr rr (enqueue gf));
          search ()) in
  search ()

let detached_profiles model site =
  let masks,offsets = Hashtbl.find model.selectors site.node in
  let roots = [site.node,ranges (masks@offsets)] and best = Hashtbl.create 8 in
  let rec walk graph = match dependency model graph roots with
    | Some (x,y) -> walk (Precedence.constrain graph x y);walk (Precedence.constrain graph y x)
    | None ->
        let prefix = Array.fold_right (fun n xs ->
          if Precedence.before graph n site.node then n::xs else xs) graph.order [site.node] in
        (match local_footprint model prefix site with
        | exception Invalid_prefix n ->
            let masks,offsets = Hashtbl.find model.selectors n in
            Option.iter (fun (x,y) ->
              walk (Precedence.constrain graph x y);walk (Precedence.constrain graph y x))
              (dependency model graph [n,ranges (masks@offsets)])
        | fp ->
        let writes = fp.writes in
        let len = List.length prefix in
        if writes<>[] && Option.fold ~none:true ~some:(fun (n,_) -> len<n) (Hashtbl.find_opt best writes)
        then Hashtbl.replace best writes (len,prefix)) in
  walk {model.graph with order=Array.init (Array.length model.steps) Fun.id};
  Hashtbl.to_seq best |> List.of_seq |> List.sort compare

let independent_pair profiles a b =
  let best = ref None in
  List.iter (fun (xs,(n,p)) -> List.iter (fun (ys,(m,q)) ->
    if Option.fold ~none:true ~some:(fun (len,_,_,_) -> n+m<len) !best then
      let overlap = intersect xs ys in
      if overlap<>[] then best := Some (n+m,overlap,p,q)) (profiles b)) (profiles a);
  Option.map (fun (_,overlap,p,q) ->
    let prior = List.rev_append (List.tl (List.rev p)) (List.rev (List.tl (List.rev q))) in
    witness a b overlap (prior@[a.node;b.node]) (prior@[b.node;a.node])) !best

let generate model =
  let table = Hashtbl.create 32 in
  let profiles site = match Hashtbl.find_opt table site.node with Some xs -> xs | None ->
    let xs = detached_profiles model site in Hashtbl.add table site.node xs;xs in
  let races = List.filter_map (fun (a,b) ->
    if model.independent && model.blocks.(a.node)<>model.blocks.(b.node) &&
       Hashtbl.mem model.selectors a.node && Hashtbl.mem model.selectors b.node &&
       a.conditional_writes<>[] && b.conditional_writes<>[]
    then independent_pair profiles a b
    else match minimum model a b with Some _ as w -> w | None -> refine model a b) (candidates model) in
  List.iter (replay_witness model) races;
  races
