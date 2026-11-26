open Core_lang
open Parametric_lang
open Formula
open Z3

type channel = { block : bool; receiver : int; source : int; target : endpoint; flag : Expr.expr }
type kind =
  | Access of slice list * slice list
  | Reserve of Expr.expr
  | Send of channel list
  | Consume of channel
  | Barrier

(* 每个模板代表一个源位置的所有动态实例。order 交替记录 AST 子节点和
   循环序号，它的字典序就是同一流中的发射顺序。 *)
type site = {
  stream : int; path : int list; indices : Expr.expr list; order : Expr.expr list;
  pipe : int option; kind : kind; domain : Expr.expr; flat_loop : (int list * Expr.expr) option;
}

let compile ctx family n =
  if family.parameter=[] then invalid_arg "symbolic N needs an entry parameter";
  validate family;
  let yes = bool ctx true and zero = int ctx 0 in
  let restrict condition = List.map (fun site ->
    {site with domain = simplify (and_ ctx [condition; site.domain])}) in
  let stream_sites stream =
    let rec walk env path loops order command =
      let indices = List.map (fun (i,_,_) -> i) loops in
      let operand = function Literal v -> lift ctx v | Var x -> List.assoc x env in
      let args = List.map operand in
      let child i env = walk env (i :: path) loops (int ctx i :: order) in
      let event pipe kind =
        Option.iter (fun p -> if not (List.mem p stream.pipes) then invalid_arg "undeclared pipe") pipe;
        {stream = stream.id; path = List.rev path; indices = List.rev indices;
         order = List.rev order; pipe; kind; domain = yes;
         flat_loop = (match loops with [_,p,count] -> Some (p,count) | _ -> None)} in
      let then_do events env next =
        let rest, falls = child 0 env next in events @ rest, falls in
      match command with
      | End -> [], yes
      | Return _ -> [], bool ctx false
      | Yield _ | Branch_values _ | For_values _ ->
          raise (Unsupported "SSA region results require a concrete launch")
      | Scalar (x,op,vs,next) ->
          let v = eval ctx (args vs) (family.scalar stream.id op) in
          child 0 ((x,v) :: env) next
      | Alloc (x,_,dims,next) ->
          let dims = List.map (fun d -> Parametric_lang.integer (operand d)) dims in
          let size = List.fold_left (mul ctx) (int ctx 1) dims in
          let storage = Local (stream.id, List.rev path, List.rev indices) in
          let ok = and_ ctx (List.map (le ctx zero) dims) in
          let sites, falls = then_do [event None (Reserve size)]
            ((x, View [slice ctx storage zero size]) :: env) next in
          restrict ok sites, and_ ctx [ok; falls]
      | Issue (pipe,op,vs,next) ->
          let reads,writes = eval_access ctx family stream.id pipe op (args vs) in
          then_do [event (if scalar_endpoint stream pipe then None else Some pipe) (Access (reads,writes))] env next
      | Barrier (b,next) ->
          let pipes = match b with Pipe p -> [p] | All -> stream.pipes in
          then_do (List.map (fun p -> event (Some p) Barrier) pipes) env next
      | Sync (mode,source,target,e,next) ->
          let flag = flag (operand e) in
          let channel receiver = {block = (mode = BlockSet || mode = BlockWait); receiver; source; target; flag} in
          let op = match mode,target with
            | LocalSet,_ -> event (if scalar_endpoint stream source then None else Some source) (Send [channel stream.id])
            | BlockSet,_ ->
                let keys = List.filter_map (fun s ->
                  if family.block_edge stream.id source s.id target then Some (channel s.id) else None
                ) family.streams in
                event (if scalar_endpoint stream source then None else Some source) (Send keys)
            | (LocalWait | BlockWait),Data p -> event (Some p) (Consume (channel stream.id))
            | (LocalWait | BlockWait),ScalarEnd -> event None (Consume (channel stream.id)) in
          then_do [op] env next
      | Branch (test,a,b,next) ->
          let guard = boolean (operand test) in
          let left,fa = child 0 env a and right,fb = child 1 env b in
          let falls = simplify (Boolean.mk_ite ctx guard fa fb) in
          let rest,finish = child 2 env next in
          restrict guard left @ restrict (Boolean.mk_not ctx guard) right @ restrict falls rest,
          and_ ctx [falls; finish]
      | For (x,lo,hi,step,body,next) ->
          let number v = Parametric_lang.integer (operand v) in
          let lo,hi,step = number lo, number hi, number step in
          let i = fresh ctx "iteration" in
          let index = add ctx lo (mul ctx i step) in
          let inside = and_ ctx [le ctx zero i; or_ ctx [
            and_ ctx [lt ctx zero step; lt ctx index hi];
            and_ ctx [lt ctx step zero; lt ctx hi index]]] in
          let positive = lt ctx zero step in
          let sub a b = Arithmetic.mk_sub ctx [a;b] in
          let width = Boolean.mk_ite ctx positive step (sub zero step) in
          let distance = Boolean.mk_ite ctx positive (sub hi lo) (sub lo hi) in
          let extent = simplify (Boolean.mk_ite ctx (and_ ctx [lt ctx zero width; lt ctx zero distance])
            (Arithmetic.mk_div ctx (add ctx distance (sub width (int ctx 1))) width) zero) in
          let sites,falls = walk ((x,Integer index) :: env) (0 :: path) ((i,List.rev path,extent) :: loops)
            (i :: int ctx 0 :: order) body in
          let all_before = if Boolean.is_true (simplify falls) then yes else
            let j = fresh ctx "earlier_iteration" in
            let at_j e = Expr.substitute_one e i j in
            forall ctx [j] (Boolean.mk_implies ctx (and_ ctx [at_j inside; lt ctx j i]) (at_j falls)) in
          let completes = and_ ctx [Boolean.mk_not ctx (eq ctx step zero);
            forall ctx [i] (Boolean.mk_implies ctx inside falls)] in
          let rest,finish = child 1 env next in
          restrict (and_ ctx [inside; all_before]) sites @ restrict completes rest,
          and_ ctx [completes; finish] in
    let env = List.map (fun (x,v) -> x,lift ctx v) stream.params in
    let env = List.fold_left (fun env (s,x) -> if s = stream.id then (x,Integer n) :: env else env)
      env family.parameter in
    fst (walk env [] [] [] stream.body) in
  List.concat_map stream_sites family.streams

type instance = { site : site; args : Expr.expr list }
let instance ctx site = {site; args = List.map (fun _ -> fresh ctx "ordinal") site.indices}
let at i e = if i.args = [] then e else Expr.substitute e i.site.indices i.args
let valid i = at i i.site.domain

let rec lex ctx xs ys = match xs,ys with
  | [], [] | _, [] -> bool ctx false
  | [], _ -> bool ctx true
  | x :: xs,y :: ys -> or_ ctx [lt ctx x y; and_ ctx [eq ctx x y; lex ctx xs ys]]

let earlier ctx a b =
  lex ctx (List.map (at a) a.site.order) (List.map (at b) b.site.order)

let same_indices ctx xs ys =
  if List.length xs <> List.length ys then bool ctx false else and_ ctx (List.map2 (eq ctx) xs ys)

let overlaps ctx a b x y =
  let alias = match x.storage,y.storage with
    | External s,External u -> bool ctx (s = u)
    | Local (s,p,is),Local (u,q,js) when s = u && p = q ->
        same_indices ctx (List.map (at a) is) (List.map (at b) js)
    | _ -> bool ctx false in
  let x0,xn = at a x.offset,at a x.length and y0,yn = at b y.offset,at b y.length in
  and_ ctx [alias; at a x.guard; at b y.guard; lt ctx (int ctx 0) xn; lt ctx (int ctx 0) yn;
            lt ctx x0 (add ctx y0 yn); lt ctx y0 (add ctx x0 xn)]

let conflicts ctx a b = match a.site.kind,b.site.kind with
  | Access (r,w),Access (s,v) ->
      let cross xs ys = List.concat_map (fun x -> List.map (overlaps ctx a b x) ys) xs in
      or_ ctx (cross w (s @ v) @ cross r v)
  | _ -> invalid_arg "expected two memory operations"
