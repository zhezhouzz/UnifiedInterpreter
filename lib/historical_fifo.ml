open Z3
open Historical_lang
open Formula
open Historical_events
open Historical_order

(* 在一条发送流和一条接收队列上，同一个 key 的第 r 次置位必须先于
   第 r 次消费，后者必须先于第 r+1 次置位。以下计算两种事件各自的序号。 *)
type pattern = Constant | Rotating of Expr.expr * int
type counter = Once | Loop of int list * Expr.expr * Expr.expr * Expr.expr * pattern

let counters ctx proof_solver n sites =
  let zero = int ctx 0 and one = int ctx 1 in
  let sub a b = Arithmetic.mk_sub ctx [a;b] in
  let modulo = Arithmetic.Integer.mk_mod ctx in
  let describe site key = match site.indices,site.flat_loop with
    | [],_ -> Some Once
    | [i],Some (path,extent) ->
        let at_zero e = simplify (Expr.substitute_one e i zero) in
        let guard = at_zero site.domain and flag = at_zero key.flag in
        let range = and_ ctx [le ctx zero n; le ctx zero i; lt ctx i extent] in
        let proves e =
          let e = simplify e in Boolean.is_true e ||
          Solver.check proof_solver [range; Boolean.mk_not ctx e] = Solver.UNSATISFIABLE in
        if not (proves (eq ctx guard site.domain)) then None else
        let loop pattern = Some (Loop (path,extent,guard,flag,pattern)) in
        if proves (eq ctx flag key.flag) then loop Constant else
        let rec moduli e = match Expr.get_args e with
          | [_;m] when Arithmetic.is_modulus e && Expr.is_numeral m && Z.sign (numeral m) > 0 -> [m]
          | xs -> List.concat_map moduli xs in
        List.find_map (fun m ->
          List.find_map (fun sign ->
            let expected = modulo (if sign = 1 then add ctx flag i else sub flag i) m in
            if proves (eq ctx expected key.flag) then loop (Rotating (m,sign)) else None
          ) [1;-1]) (moduli (simplify key.flag))
    | _ -> None in
  let counts = List.map (fun (s,k,sends) -> s,k,sends,describe s k) (touches sites) in
  fun target key sends ->
    let matched = List.filter (fun (_,k,role,_) -> same_key k key && role = sends) counts in
    let ordered = List.for_all (fun (s,_,_,_) -> s.stream = target.site.stream) matched in
    if not ordered || List.length target.args > 1 then None else
    let wanted = at target key.flag in
    let count (site,k,_,description) = match description with
      | None -> None
      | Some Once ->
          let source = {site; args = []} in
          Some (Boolean.mk_ite ctx (and_ ctx [valid source; eq ctx k.flag wanted;
                                             earlier ctx source target]) one zero)
      | Some (Loop (path,extent,guard,flag,pattern)) ->
          let before i = earlier ctx {site;args = [i]} target in
          let upper = match target.site.flat_loop,target.args with
            | Some (other,_),[j] when path = other ->
                let exclusive = add ctx j (Boolean.mk_ite ctx (before j) one zero) in
                Boolean.mk_ite ctx (lt ctx extent exclusive) extent exclusive
            | _ -> Boolean.mk_ite ctx (before zero) extent zero in
          let total = match pattern with
            | Constant -> Boolean.mk_ite ctx (eq ctx flag wanted) upper zero
            | Rotating (m,sign) ->
                let residue = modulo (if sign = 1 then sub wanted flag else sub flag wanted) m in
                Boolean.mk_ite ctx (and_ ctx [le ctx zero wanted; lt ctx wanted m])
                  (Arithmetic.mk_div ctx (sub (add ctx upper m) (add ctx one residue)) m) zero in
          Some (Boolean.mk_ite ctx guard total zero) in
    List.fold_left (fun total term -> Option.bind total (fun sum ->
      Option.map (add ctx sum) (count term))) (Some zero) matched

(* 只实例化目标的迭代坐标，检查两种顺序都必须满足的依赖。
   此查询的 UNSAT 对所有 N 成立，其他情况交由完整的轨迹约束处理。 *)
let orders ctx sites count a b =
  let instances site =
    let coords = List.fold_left (fun seen xs ->
      if List.length xs <> List.length site.indices || List.exists (List.equal Expr.equal xs) seen
      then seen else xs :: seen) [] [a.args;b.args;[]] in
    List.map (fun args -> {site;args}) coords in
  let events = List.concat_map instances sites in
  let signals = List.concat_map (fun (site,key,sends) ->
    List.filter_map (fun event -> Option.map (fun rank -> event,key,sends,simplify rank)
      (count event key sends)) (instances site)) (touches sites) in
  let edges = List.concat_map (fun first -> List.filter_map (fun last ->
    if ordered_queue first.site last.site then Some (first,last,earlier ctx first last) else None
  ) events) events in
  let sync = List.concat_map (fun (first,k,sends,r) ->
    List.filter_map (fun (last,h,sets,q) ->
      if sends = sets || not (same_key k h) then None else
      Some (first,last,and_ ctx [eq ctx (at first k.flag) (at last h.flag);
                                 (if sends then le ctx r q else lt ctx r q)])
    ) signals) signals in
  let edges = List.filter_map (fun (i,j,cond) ->
    let cond = simplify (and_ ctx [valid i;cond]) in
    if Boolean.is_false cond then None else Some (i,j,cond)) (edges @ sync) in
  let direction a b =
    let sort = Arithmetic.Integer.mk_sort ctx in
    let clocks = List.map (fun s ->
      s,FuncDecl.mk_fresh_func_decl ctx "required_order" (List.map (fun _ -> sort) s.indices) sort) sites in
    let clock i = Expr.mk_app ctx (snd (List.find (fun (s,_) -> s == i.site) clocks)) i.args in
    let selected i = le ctx (int ctx 0) (clock i) in
    let before i j = and_ ctx [selected i; lt ctx (clock i) (clock j)] in
    let constraints = List.map (fun (i,j,cond) ->
      Boolean.mk_implies ctx (and_ ctx [selected j;cond]) (before i j)) edges in
    and_ ctx (selected b :: before a b :: constraints) in
  and_ ctx [direction a b; direction b a]
