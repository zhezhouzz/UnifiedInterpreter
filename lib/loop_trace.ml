open Z3

let threshold = 64
let rounds iterations = List.fold_left (fun n i -> max n (i+1)) 0 iterations

type 'bank access = {node:int; reads:('bank * int * int) list; writes:('bank * int * int) list}
type 'a result = Found of int * 'a | No_race | Incomplete of string

(* 固定入口输入。两个被选中的访问可以在同一个合法前缀后同时就绪，
   因而交换它们并按拓扑顺序执行剩余事件，都会得到完整执行。 *)
let choose ?(timeout_ms=5000) ?(partial=false) ~parents ~iterations accesses validate =
  let graph = Precedence.build parents in
  if not partial && Array.length graph.order <> Array.length parents then
    Incomplete "the launch has pending events that cannot complete"
  else
  let ctx = mk_context [] in
  let solver = Race_solve.new_solver ~timeout_ms ctx in
  let int = Arithmetic.Integer.mk_numeral_i ctx in
  let var = Arithmetic.Integer.mk_const_s ctx in
  let eq = Boolean.mk_eq ctx and le = Arithmetic.mk_le ctx and lt = Arithmetic.mk_lt ctx in
  let both xs = Boolean.mk_and ctx xs and either xs = Boolean.mk_or ctx xs in
  let assert_ x = Solver.add solver [x] in
  let n=var "prefix_rounds" and a=var "left_access" and b=var "right_access" in
  let address=var "address" and bank=var "storage" in
  let before = Array.mapi (fun i _ -> Boolean.mk_const_s ctx ("prior" ^ string_of_int i)) parents in
  let ready = Array.mapi (fun i ps -> if graph.reachable.(i) then both (List.map (Array.get before) ps)
    else Boolean.mk_false ctx) parents in
  Array.iteri (fun i prior -> assert_ (Boolean.mk_implies ctx prior
    (both [ready.(i);le (int iterations.(i)) n]))) before;
  let banks = Hashtbl.create 16 in
  let range (storage,lo,hi) =
    let id = match Hashtbl.find_opt banks storage with Some id -> id | None ->
      let id=Hashtbl.length banks in Hashtbl.add banks storage id; id in
    both [eq bank (int id);le (int lo) address;lt address (int hi)] in
  let accesses=Array.of_list accesses in
  let choices select write =
    Array.to_list (Array.mapi (fun index site ->
      let spans=if write then site.writes else site.reads @ site.writes in
      both [eq select (int index);ready.(site.node);Boolean.mk_not ctx before.(site.node);
        le (int iterations.(site.node)) n;either (List.map range spans)]) accesses) in
  assert_ (both [le (int 0) n;le n (int (Array.fold_left max 0 iterations));
                 either (choices a true);either (choices b false);Boolean.mk_not ctx (eq a b)]);
  let rec search () = match Solver.check solver [] with
    | Solver.UNSATISFIABLE -> No_race
    | Solver.UNKNOWN -> Incomplete (Solver.get_reason_unknown solver)
    | Solver.SATISFIABLE ->
        let value model v=Z.to_int (Arithmetic.Integer.get_big_int (Option.get (Model.eval model v true))) in
        let rec shrink lower model =
          let upper=value model n in
          if lower>=upper then model else
          let mid=lower+(upper-lower)/2 in
          match Solver.check solver [le n (int mid)] with
          | Solver.SATISFIABLE -> shrink lower (Option.get (Solver.get_model solver))
          | Solver.UNSATISFIABLE -> shrink (mid+1) model
            | Solver.UNKNOWN -> raise (Race_solve.Inconclusive (Solver.get_reason_unknown solver)) in
        let model=shrink 0 (Option.get (Solver.get_model solver)) in
        let i=value model a and j=value model b in
        let x=accesses.(i).node and y=accesses.(j).node in
        let result=if x=y then None else validate graph i j in
        match result with
        | Some (prefix,data) ->
            let actual=List.fold_left (fun k event -> max k iterations.(event)) 0 prefix in
            Found (actual,data)
        | None ->
            assert_ (Boolean.mk_not ctx (both [eq a (int i);eq b (int j)]));search () in
  try search () with Race_solve.Inconclusive reason -> Incomplete reason

let complete order prefix =
  let selected=Array.make (Array.length order) false in
  List.iter (fun n->selected.(n)<-true) prefix;
  prefix @ Array.fold_right (fun n rest -> if selected.(n) then rest else n::rest) order []
