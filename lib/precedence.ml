(** 单一发送序列和消费序列使每个事件具有确定的直接前驱。
    同一层的就绪事件可以交换。按层展开前驱闭包即可得到最短前缀。 *)
type t = { ancestors : Z.t array; order : int array; reachable : bool array }

let build predecessors =
  let size = Array.length predecessors in
  let pending = Array.map List.length predecessors and successors = Array.make size [] in
  let queue = Queue.create () and visited = ref [] in
  let ancestors = Array.make size Z.zero and reachable = Array.make size false in
  Array.iteri (fun i parents ->
    List.iter (fun p -> if p >= 0 then successors.(p) <- i :: successors.(p)) parents;
    if parents=[] then Queue.add i queue) predecessors;
  while not (Queue.is_empty queue) do
    let i = Queue.take queue in
    visited := i :: !visited;
    reachable.(i) <- true;
    let closure = Z.logor ancestors.(i) (Z.shift_left Z.one i) in
    List.iter (fun j ->
      ancestors.(j) <- Z.logor ancestors.(j) closure;
      pending.(j) <- pending.(j)-1;
      if pending.(j)=0 then Queue.add j queue) successors.(i)
  done;
  {ancestors;reachable;order=Array.of_list (List.rev !visited)}

let unordered graph a b = graph.reachable.(a) && graph.reachable.(b) &&
  not (Z.testbit graph.ancestors.(a) b || Z.testbit graph.ancestors.(b) a)

let before g a b = Z.testbit g.ancestors.(b) a

let constrain g a b =
  if before g b a || a=b then invalid_arg "cyclic precedence constraint";
  if before g a b then g else
  let prior = Z.logor g.ancestors.(a) (Z.shift_left Z.one a) in
  let ancestors = Array.mapi (fun n old -> if n=b || Z.testbit old b then Z.logor old prior else old)
    g.ancestors in
  let left,right = List.partition (Z.testbit prior) (Array.to_list g.order) in
  {g with ancestors;order=Array.of_list (left@right)}

let prefix graph a b =
  let required = Z.logor graph.ancestors.(a) graph.ancestors.(b) in
  Array.fold_right (fun n tail -> if Z.testbit required n then n::tail else tail) graph.order [a;b]

(* 此处节点按一条完整执行排列。Z3 直接求解每个事件的传递前驱集合。 *)
let solve_component parents =
  let open Z3 in
  let size = Array.length parents and ctx = mk_context [] in
  let zero = BitVector.mk_numeral ctx "0" size in
  let tactic = Tactic.and_then ctx (Tactic.mk_tactic ctx "simplify") (Tactic.mk_tactic ctx "solve-eqs") [] in
  let solver = Solver.mk_solver_t ctx tactic in
  let variables = Array.init size (fun n -> BitVector.mk_const_s ctx ("before" ^ string_of_int n) size) in
  let closures = Array.mapi (fun n x ->
    let bit = BitVector.mk_numeral ctx (Z.to_string (Z.shift_left Z.one n)) size in
    BitVector.mk_or ctx x bit) variables in
  let ancestors = Array.make size Z.zero in
  (* 每组只引用已求解的前组常量。方程有唯一解，可以逐组消元。 *)
  let batch_size=32 in
  for batch=0 to (size-1)/batch_size do
    let first=batch*batch_size and last=min size ((batch+1)*batch_size) in
    Solver.reset solver;
    for n=first to last-1 do
      let prior = List.fold_left (fun acc p ->
        if p<0 || p>=n then invalid_arg "non-topological device execution";
        BitVector.mk_or ctx acc closures.(p)) zero parents.(n) in
      Solver.add solver [Boolean.mk_eq ctx variables.(n) (Expr.simplify prior None)]
    done;
    let model = match Solver.check solver [] with
      | Solver.SATISFIABLE -> Option.get (Solver.get_model solver)
      | Solver.UNKNOWN -> failwith (Solver.get_reason_unknown solver)
      | Solver.UNSATISFIABLE -> invalid_arg "inconsistent event dependencies" in
    for n=first to last-1 do
      let value=Option.get (Model.eval model variables.(n) true) in
      ancestors.(n)<-Z.of_string (BitVector.numeral_to_string value);
      closures.(n)<-Option.get (Model.eval model closures.(n) true)
    done
  done;
  {ancestors;order=Array.init size Fun.id;reachable=Array.make size true}


let solve parents =
  let size = Array.length parents in
  let components = Array.init size Fun.id in
  let rec representative n =
    let p=components.(n) in if p=n then n else (
      let root=representative p in components.(n)<-root;root) in
  Array.iteri (fun n ps -> List.iter (fun p -> components.(representative n)<-representative p) ps) parents;
  let groups=Hashtbl.create 8 in
  Array.iteri (fun n _ -> let root=representative n in
    Hashtbl.replace groups root (n::Option.value ~default:[] (Hashtbl.find_opt groups root))) parents;
  let ancestors=Array.make size Z.zero and local=Array.make size 0 in
  Hashtbl.iter (fun _ ns ->
    let ids=Array.of_list (List.rev ns) in
    Array.iteri (fun i n -> local.(n)<-i) ids;
    let group=solve_component (Array.map (fun n -> List.map (Array.get local) parents.(n)) ids) in
    let shift=ids.(0) and contiguous=ids.(Array.length ids-1)-ids.(0)+1=Array.length ids in
    Array.iteri (fun i n ->
      let bits=group.ancestors.(i) in
      ancestors.(n)<-(if contiguous then Z.shift_left bits shift else
        let rec expand value acc = if Z.equal value Z.zero then acc else
          let bit=Z.trailing_zeros value in expand (Z.logand value (Z.pred value))
            (Z.logor acc (Z.shift_left Z.one ids.(bit))) in expand bits Z.zero)) ids) groups;
  {ancestors;order=Array.init size Fun.id;reachable=Array.make size true}

type backend = Bfs | Smt

let compile backend parents =
  match backend with
  | Bfs -> build parents
  | Smt when Array.for_all Fun.id
      (Array.mapi (fun i -> List.for_all (fun p -> p >= 0 && p < i)) parents) -> solve parents
  | Smt ->
      (* 不可达节点可能等待未发送的信号，或位于依赖环中。只给就绪节点编号。 *)
      let topology = build parents in
      let ids = topology.order in
      let number = Array.make (Array.length parents) (-1) in
      Array.iteri (fun i n -> number.(n) <- i) ids;
      let solved = solve (Array.map (fun n -> List.map (Array.get number) parents.(n)) ids) in
      let ancestors = Array.make (Array.length parents) Z.zero in
      Array.iteri (fun i n ->
        let bits = ref solved.ancestors.(i) in
        while not (Z.equal !bits Z.zero) do
          let p = Z.trailing_zeros !bits in
          ancestors.(n) <- Z.logor ancestors.(n) (Z.shift_left Z.one ids.(p));
          bits := Z.logand !bits (Z.pred !bits)
        done) ids;
      {topology with ancestors}
