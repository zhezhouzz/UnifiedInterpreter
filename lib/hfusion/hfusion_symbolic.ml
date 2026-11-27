open Hfusion_model
module S = Hfusion_schedule
open Z3

(* 每个访问位置有独立的循环变量。约束描述循环范围内所有可达的
   归纳变量值；两个位置共享同一个启动参数 N。 *)
let query ?(timeout_ms=5000) model maximum =
  let ctx=mk_context [] in
  let solver=S.solver ctx (Some timeout_ms) in
  let int z=Arithmetic.Integer.mk_numeral_s ctx (Z.to_string z) in
  let zero=int Z.zero and n=Arithmetic.Integer.mk_const_s ctx "N" in
  let add a b=Arithmetic.mk_add ctx [a;b] and sub a b=Arithmetic.mk_sub ctx [a;b] in
  let lt=Arithmetic.mk_lt ctx and le=Arithmetic.mk_le ctx and eq=Boolean.mk_eq ctx in
  let modulo=Arithmetic.Integer.mk_mod ctx in
  let and_=Boolean.mk_and ctx and or_=Boolean.mk_or ctx in
  let wrap ty x=
    let w=width ty in
    let modulus=int (Z.shift_left Z.one w) in
    if w=1 then modulo x modulus else
    let half=int (Z.shift_left Z.one (w-1)) in sub (modulo (add x half) modulus) half in
  let rec value vars = function
    | Lit z -> int z | N -> n | Iv i -> List.nth vars i
    | Binary (op,ty,x,y) ->
        let a=value vars x and b=value vars y in
        (match op with
         | E.ArithAddI -> wrap ty (add a b)
         | E.ArithMulI -> wrap ty (Arithmetic.mk_mul ctx [a;b])
         | E.ArithDivSI | E.ArithRemSI ->
             let abs x=Boolean.mk_ite ctx (lt x zero) (sub zero x) x in
             let magnitude=Arithmetic.mk_div ctx (abs a) (abs b) in
             let q=Boolean.mk_ite ctx (eq (lt a zero) (lt b zero)) magnitude (sub zero magnitude) in
             if op=E.ArithDivSI then q else sub a (Arithmetic.mk_mul ctx [q;b])
         | _ -> invalid_arg "unsupported symbolic integer operation") in
  let instance site =
    let vars,guards=List.fold_left (fun (vars,guards) loop ->
      let iv=Expr.mk_fresh_const ctx "iv" (Arithmetic.Integer.mk_sort ctx) in
      let lo=value vars loop.lo and hi=value vars loop.hi and step=value vars loop.step in
      vars@[iv], and_ [lt zero step;le lo iv;lt iv hi;eq (modulo (sub iv lo) step) zero]::guards
    ) ([],[]) site.loops in
    let bounds view=match view.cells with
      | [] -> []
      | (low,high)::rest ->
          let high=List.fold_left (fun _ (_,last) -> last) high rest in
          let base=value vars view.base in
          [le zero (add base (int low));lt (add base (int high)) (int view.capacity)] in
    vars,List.concat_map bounds (site.reads@site.writes@site.claims)@guards in
  let witnesses left lv right rv =
    List.concat_map (fun a -> List.concat_map (fun b ->
      match a.storage,b.storage with
      | External x,External y when x=y ->
          let start=value lv a.base and other=value rv b.base in
          List.concat_map (fun (lo,hi) -> List.map (fun (l,h) ->
            and_ [le (add start (int lo)) (add other (int h));
                  le (add other (int l)) (add start (int hi))]) b.cells) a.cells
      | _ -> []) right) left in
  let rec candidates = function [] -> [] | a::rest ->
    let pairs=List.filter_map (fun b ->
      if a.stream=b.stream then None else
      let lv,lg=instance a and rv,rg=instance b in
      let overlap=witnesses a.writes lv (b.writes@b.reads) rv @ witnesses a.reads lv b.writes rv in
      if overlap=[] then None else Some (and_ (or_ overlap::lg@rg),(a,lv),(b,rv))) rest in
    List.rev_append pairs (candidates rest) in
  let pairs=candidates model.sites in
  Solver.add solver [le zero n;le n (int maximum);or_ (List.map (fun (test,_,_) -> test) pairs)];
  (* 取最小的可行参数，避免按求解器任意选择的大数展开具体执行。 *)
  let rec smallest low m =
    let high=S.number m n in
    if Z.equal low high then m else
    let mid=Z.div (Z.add low high) (Z.of_int 2) in
    match S.check solver [le n (int mid)] with
    | None -> smallest (Z.succ mid) m
    | Some m -> smallest low m in
  let deadline=Unix.gettimeofday () +. float timeout_ms /. 1000. in
  let rec search low =
    if Unix.gettimeofday ()>=deadline then raise (S.Inconclusive "symbolic query timeout");
    match S.check solver [] with
    | None -> None
    | Some m ->
        let m=smallest low m in
        let count=S.number m n in
        let _,left,right=List.find (fun (test,_,_) ->
          Boolean.is_true (Option.get (Model.eval m test true))) pairs in
        let event (site,vars) =
          let ivs=List.map (S.number m) vars in
          let iterations=List.map2 (fun iv loop ->
            let term e=S.number m (value vars e) in
            Z.div (Z.sub iv (term loop.lo)) (term loop.step)) ivs site.loops in
          if List.exists (fun i -> not (Z.fits_int i)) iterations then None else
          let iterations=List.map Z.to_int iterations in
          Some {stream=site.stream;entry=model.program.name;path=site.path;opcode=site.opcode;iterations} in
        let concrete=lazy (S.build model count) in
        let targeted=match event left,event right with
          | Some a,Some b ->
              let schedule=Lazy.force concrete in
              (match Hashtbl.find_opt schedule.by_event a,Hashtbl.find_opt schedule.by_event b with
               | Some i,Some j when S.conflict schedule.nodes.(i) schedule.nodes.(j) ->
                   S.smt ~first_only:true ~timeout_ms schedule [i,j]
               | _ -> [])
          | _ -> [] in
        let races=match targeted with
          | [] ->
              let full=Lazy.force concrete in
              S.smt ~first_only:true ~timeout_ms full (S.candidates full)
          | found -> found in
        match races with
        | r::_ -> Some (count,r)
        | [] ->
            (* 内存初始化和 restrict 可能排除同一输入上的某个完成顺序。 *)
            let next=Z.succ count in
            Solver.add solver [le (int next) n];search next in
  search Z.zero
