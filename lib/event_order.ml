type rule = { requires:int list list; excludes:int list }

let enabled rules seen i =
  let present = Z.testbit seen in
  not (present i) && List.for_all (List.exists present) rules.(i).requires &&
  not (List.exists present rules.(i).excludes)

let replay rules events =
  ignore (List.fold_left (fun seen i ->
    if not (enabled rules seen i) then invalid_arg "event is disabled";
    Z.logor seen (Z.shift_left Z.one i)) Z.zero events)

(* 全部事件必须执行，所以 i 排斥先执行的 j 等价于 i 必须先于 j。
   转换后调度动作只增加已满足的前提，任一合法前缀均可接上同一完整顺序的剩余事件。 *)
let completion_rules rules =
  let result=Array.map (fun rule -> {rule with excludes=[]}) rules in
  Array.iteri (fun i rule -> List.iter (fun j ->
    result.(j)<-{requires=[i]::result.(j).requires;excludes=[]}) rule.excludes) rules;
  result

let all_reachable rules =
  let seen=ref Z.zero and count=ref 0 in
  let rec advance () =
    let previous= !count in
    Array.iteri (fun i _ -> if enabled rules !seen i then (
      seen:=Z.logor !seen (Z.shift_left Z.one i);incr count)) rules;
    !count=Array.length rules || (!count>previous && advance ()) in
  advance ()

let can_extend rules =
  let rules=completion_rules rules in
  let complete=lazy (all_reachable rules) in
  fun events ->
    let seen=ref Z.zero in
    Lazy.force complete && List.for_all (fun i -> enabled rules !seen i &&
      (seen:=Z.logor !seen (Z.shift_left Z.one i);true)) events

let search rules pairs =
  let relevant = Hashtbl.create 32 in
  let rec include_node i = if not (Hashtbl.mem relevant i) then begin
    Hashtbl.add relevant i (); List.iter (List.iter include_node) rules.(i).requires
  end in
  List.iter (fun (a,b) -> include_node a; include_node b) pairs;
  let actions = Hashtbl.to_seq_keys relevant |> List.of_seq |> List.sort compare in
  let partners = Array.make (Array.length rules) [] in
  List.iter (fun (a,b) -> partners.(a) <- b::partners.(a); partners.(b) <- a::partners.(b)) pairs;
  let prefixes = Hashtbl.create 16 and visited = Hashtbl.create 32 and queue = Queue.create () in
  Queue.add (Z.zero,[]) queue; Hashtbl.add visited Z.zero ();
  while not (Queue.is_empty queue) && Hashtbl.length prefixes < 2 * List.length pairs do
    let seen,prefix = Queue.take queue in
    List.iter (fun i -> if enabled rules seen i then begin
      let rev = i::prefix and next=Z.logor seen (Z.shift_left Z.one i) in
      List.iter (fun j -> if Z.testbit seen j && not (Hashtbl.mem prefixes (j,i)) then
        Hashtbl.add prefixes (j,i) (List.rev rev)) partners.(i);
      if not (Hashtbl.mem visited next) then begin
        Hashtbl.add visited next (); Queue.add (next,rev) queue
      end
    end) actions
  done;
  fun a b -> Hashtbl.find_opt prefixes (a,b)

exception Inconclusive of string

let solve ?timeout_ms rules =
  let open Z3 in
  let ctx = mk_context [] in
  let solver = Solver.mk_solver ctx None in
  Option.iter (fun ms -> let p = Params.mk_params ctx in
    Params.add_int p (Symbol.mk_string ctx "timeout") ms; Solver.set_parameters solver p) timeout_ms;
  let zero = Arithmetic.Integer.mk_numeral_i ctx 0 in
  let times = Array.mapi (fun i _ -> Arithmetic.Integer.mk_const_s ctx ("time" ^ string_of_int i)) rules in
  let present i = Arithmetic.mk_ge ctx times.(i) zero in
  let before a b = Boolean.mk_and ctx [present a; Arithmetic.mk_lt ctx times.(a) times.(b)] in
  Array.iteri (fun i rule ->
    let require term = Solver.add solver [term] in
    require (present i);
    List.iter (fun xs -> require (Boolean.mk_or ctx (List.map (fun j -> before j i) xs))) rule.requires;
    List.iter (fun j -> require (before i j)) rule.excludes) rules;
  fun a b -> match Solver.check solver [before a b; present b] with
    | UNSATISFIABLE -> None
    | UNKNOWN -> raise (Inconclusive (Solver.get_reason_unknown solver))
    | SATISFIABLE ->
        let model = Option.get (Solver.get_model solver) in
        let rank t = Arithmetic.Integer.get_big_int (Option.get (Model.eval model t true)) in
        let last = rank times.(b) in
        let prefix = Array.to_list (Array.mapi (fun i t ->
          let r = rank t in if Z.sign r >= 0 && Z.lt r last then Some (r,i) else None) times)
          |> List.filter_map Fun.id |> List.sort compare |> List.map snd in
        Some (prefix @ [b])

let generate ?timeout_ms ?(first_only=false) backend rules pairs =
  if pairs=[] then [] else
  let rules=completion_rules rules in
  if not (all_reachable rules) then [] else
  let deterministic = Array.for_all (fun r -> r.excludes=[] &&
    List.for_all (function [] | [_] -> true | _ -> false) r.requires) rules in
  let prefix = if deterministic then
      let graph = Precedence.compile backend (Array.map (fun r ->
        List.map (function [i] -> i | [] -> -1 | _ -> assert false) r.requires) rules) in
      let complete=Array.length graph.order=Array.length rules in
      fun a b -> if complete && Precedence.unordered graph a b then Some (Precedence.prefix graph a b) else None
    else match backend with Precedence.Bfs -> search rules pairs | Smt -> solve ?timeout_ms rules in
  let witness (a,b) = Option.bind (prefix a b) (fun f ->
    Option.map (fun r -> replay rules f; replay rules r; a,b,f,r) (prefix b a)) in
  if first_only then Option.to_list (List.find_map witness pairs) else List.filter_map witness pairs
