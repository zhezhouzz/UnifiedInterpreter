open Z3
open Historical_lang
open Formula
open Historical_events

let ordered_queue first last =
  first.stream = last.stream &&
  (first.pipe = None || (first.pipe = last.pipe &&
    match first.kind,last.kind with
    | (Consume _ | Barrier),_ | _,(Send _ | Barrier) -> true | _ -> false))

let touches sites = List.concat_map (fun site -> match site.kind with
  | Send keys -> List.map (fun k -> site,k,true) keys
  | Consume k -> [site,k,false] | _ -> []) sites

let same_key x y = x.block = y.block && x.receiver = y.receiver &&
                   x.source = y.source && x.target = y.target

(* 每个实际发生的动态事件都有非负时钟，因而同步约束也覆盖竞争端点之后的事件。 *)
let execution ctx solver ~visible sites =
  let sort = Arithmetic.Integer.mk_sort ctx in
  let clocks = List.map (fun site ->
    site, FuncDecl.mk_fresh_func_decl ctx "completion" (List.map (fun _ -> sort) site.indices) sort
  ) sites in
  let clock i =
    let _,f = List.find (fun (s,_) -> s == i.site) clocks in
    Expr.mk_app ctx f i.args in
  let occurs i = and_ ctx [valid i; le ctx (int ctx 0) (clock i)] in
  let precedes a b = lt ctx (clock a) (clock b) in
  let rule vars guard consequence =
    Solver.add solver [forall ctx vars (Boolean.mk_implies ctx (and_ ctx guard) consequence)] in
  let required first last extra =
    rule (first.args @ last.args) [valid first; occurs last; extra]
      (and_ ctx [occurs first; precedes first last]) in
  List.iter (fun last_site ->
    let last = instance ctx last_site in
    rule last.args [valid last] (le ctx (int ctx 0) (clock last));
    List.iter (fun first_site ->
      if ordered_queue first_site last_site then (
        let first = instance ctx first_site in
        required first last (earlier ctx first last))
    ) sites;
    match last_site.kind with
    | Blocked_control -> rule last.args [valid last] (bool ctx false)
    | Access (reads,writes) ->
        List.iter (fun slice -> match slice.storage with
          | External _ -> ()
          | Local (stream,path,indices) ->
              let in_bounds = List.filter_map (fun source ->
                match source.kind with
                | Reserve size when source.stream = stream && source.path = path
                                    && List.length source.indices = List.length indices ->
                    let first = {site = source; args = List.map (at last) indices} in
                    let offset = at last slice.offset and length = at last slice.length in
                    Some (and_ ctx [occurs first; precedes first last; le ctx (int ctx 0) offset;
                                    le ctx (add ctx offset length) (at first size)])
                | _ -> None) sites in
              rule last.args [occurs last; at last slice.guard; lt ctx (int ctx 0) (at last slice.length)]
                (or_ ctx in_bounds)
        ) (reads @ writes)
    | _ -> ()
  ) sites;
  let touches = touches sites in
  let intervening wanted i key after before =
    or_ ctx (List.filter_map (fun (s,k,sends) ->
      if sends <> wanted || not (same_key key k) then None else
      let m = instance ctx s in
      Some (exists ctx m.args (and_ ctx
        ([occurs m; eq ctx (at i key.flag) (at m k.flag); precedes m before] @
         Option.to_list (Option.map (fun a -> precedes a m) after))))
    ) touches) in
  (* 初始令牌为空。对同一 key 的事件严格排序，首次消费之前必须置位，
     两次置位之间必须消费，两次消费之间必须置位。广播共享一个完成时钟。 *)
  List.iter (fun (site,key,sends) ->
    let i = instance ctx site in
    if not sends then rule i.args [occurs i] (intervening true i key None i);
    List.iter (fun (other,k,sets) -> if same_key key k then (
      let j = instance ctx other in
      let guards = [occurs i; occurs j; eq ctx (at i key.flag) (at j k.flag)] in
      let different = if site == other then Boolean.mk_not ctx (same_indices ctx i.args j.args)
                      else bool ctx true in
      rule (i.args @ j.args) (different :: guards) (Boolean.mk_not ctx (eq ctx (clock i) (clock j)));
      if sends = sets then
        rule (i.args @ j.args) (precedes i j :: guards) (intervening (not sends) i key (Some i) j))
    ) touches
  ) touches;
  let paired=List.combine visible sites in
  let actual i={i with site=snd (List.find (fun (s,_) -> s==i.site) paired)} in
  fun a b ->
    let a=actual a and b=actual b in
    let suffix=if visible==sites then [] else List.map (fun (bounded,site) ->
      let i=instance ctx site in
      forall ctx i.args (Boolean.mk_implies ctx
        (and_ ctx [valid i;Boolean.mk_not ctx (valid {i with site=bounded})]) (precedes b i))) paired in
    and_ ctx (occurs a :: occurs b :: precedes a b :: suffix)
