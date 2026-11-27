open Device_ast
open Z3

(* 从设备 AST 的入口沿首轮控制流构造存在性查询。连续发射的计算提供两个
   独立完成时钟。模型必须在完整设备程序中通过两个方向的前缀重放。 *)
exception Outside_projection
type segment = {path : int list; guard : Expr.expr; reads : (space * Expr.expr * int) list;
                writes : (space * Expr.expr * int) list}

let find_model ~timeout_ms variant config =
  let ctx = mk_context [] in
  let open Historical_lang.Formula in
  let n = fresh ctx "tokens" and zero = int ctx 0 and one = int ctx 1 in
  let add = add ctx and mul = mul ctx and lt = lt ctx in
  let sub a b = Arithmetic.mk_sub ctx [a;b] and div = Arithmetic.mk_div ctx in
  let ite = Boolean.mk_ite ctx in
  let pages = div (add n (int ctx 127)) (int ctx 128) in
  let first = Vectorlayout_input.make {config with Vectorlayout_input.length=1} in
  let program = Vectorlayout.make variant first.blocks in
  let stream = List.find (fun s -> s.location.core=Vector 0) program.streams in
  let params = List.filter_map (fun (x,v) -> match v with
    | Device_value.Reg r when not (Device_value.is_float r.layout.element) ->
        Some (x,(match x with "arg22" | "arg23" -> pages | "arg24" -> mul pages (int ctx (Vectorlayout_input.heads config))
          | _ -> int ctx (Device_value.integer v)))
    | _ -> None) first.bindings in
  let rec value env = function
    | Int (_,i) -> num ctx (Z.of_int64 i)
    | Block -> int ctx stream.location.block | Subblock -> zero
    | Var x -> (match List.assoc_opt x env with Some v -> v | None -> raise Outside_projection)
    | Cast (_,x) -> value env x
    | Read (Var arg,[ix],1) when Boolean.is_true (simplify (eq ctx (value env ix) zero)) ->
        (match arg with "arg7" | "arg8" -> n | "arg5" -> zero
         | "arg6" -> div (sub n one) (int ctx 32) | _ -> raise Outside_projection)
    | Binary (op,a,b) ->
        let a = value env a and b = value env b in
        (match op with Add -> add a b | Sub -> sub a b | Mul -> mul a b | Div -> div a b
         | Rem -> Arithmetic.Integer.mk_mod ctx a b | Min -> ite (lt a b) a b
         | Max -> ite (lt a b) b a | _ -> raise Outside_projection)
    | Compare (Lt,a,b) -> lt (value env a) (value env b)
    | _ -> raise Outside_projection in
  let address env buffer indices = match buffer with
    | Buffer (space,ty,base,shape,[]) when List.length indices=List.length shape ->
        let index = List.fold_left2 (fun pos ix dim -> add (mul pos (value env dim)) (value env ix)) zero indices shape in
        space,add (mul (int ctx 8) (value env base)) (mul (int ctx (bits ty)) index),bits ty
    | _ -> raise Outside_projection in
  let accesses env body =
    let reads = ref [] and writes = ref [] in
    let rec expr env = function
      | Read (buf,ix,_) -> reads := address env buf ix :: !reads
      | Binary (_,a,b) | Compare (_,a,b) -> expr env a;expr env b
      | Cast (_,a) | Broadcast (a,_) -> expr env a
      | Select (_,_,_) -> ()
      | _ -> () in
    let rec visit env = List.iter (function
      | Store (buf,ix,x) -> writes := address env buf ix :: !writes;expr env x
      | For l -> let lo = value env l.lo in
          if Boolean.is_true (simplify (lt lo (value env l.hi))) then visit ((l.index,lo)::env) l.body
      | Let (_,x) -> expr env x | _ -> ()) in
    visit env body; !reads,!writes in
  let segments = ref [] and consecutive = ref [] in
  let rec walk env guard path commands =
    List.fold_left (fun (i,env) cmd ->
      let pc = path @ [i] in
      let env = match cmd with
        | Issue (V,_,body) ->
            let reads,writes = accesses env body in
            let site = {path=pc;guard;reads;writes} in
            List.iter (fun a -> segments := (a,site)::!segments) !consecutive;
            consecutive := site :: !consecutive;env
        | _ -> consecutive := [];
            (match cmd with
             | Let (x,e) -> (x,value env e)::env
             | For l ->
                 let lo = value env l.lo in walk ((l.index,lo)::env)
                   (and_ ctx [guard;lt lo (value env l.hi)]) pc l.body;env
             | If (g,yes,_) -> walk env (and_ ctx [guard;value env g]) (pc@[0]) yes;env
             | _ -> env) in i+1,env) (0,env) commands |> ignore in
  (try walk params (lt zero n) [] stream.body with Outside_projection -> ());
  let solver = Race_solve.new_solver ~timeout_ms ctx in
  let overlap (s,x,w) (t,y,v) = if s<>t then bool ctx false else
    and_ ctx [lt x (add y (int ctx v));lt y (add x (int ctx w))] in
  let cross xs ys = List.concat_map (fun x -> List.map (overlap x) ys) xs in
  let rec query = function
    | [] -> Result.Error "no verified witness in symbolic entry paths"
    | (a,b)::tail ->
        let conflicts = or_ ctx (cross a.writes (b.reads @ b.writes) @ cross a.reads b.writes) in
        match Solver.check solver [a.guard;b.guard;conflicts] with
        | Solver.UNKNOWN -> Result.Error (Solver.get_reason_unknown solver)
        | Solver.UNSATISFIABLE -> query tail
        | Solver.SATISFIABLE ->
            let model = Option.get (Solver.get_model solver) in
            let length = Z.to_int (Historical_lang.numeral (Option.get (Model.eval model n true))) in
            let input = Vectorlayout_input.make {config with length} in
            let schedule = Device_races.compile ~backend:Solve variant input in
            let find path = List.find_opt (fun (s : Device_races.access_site) ->
              s.id.stream=1 && s.id.path=path) schedule.sites in
            (match find a.path,find b.path with Some x,Some y when Precedence.unordered schedule.graph x.node y.node ->
               (match Device_races.minimum schedule x y with
                | Some w ->
                    Device_races.replay_witness schedule w;
                    Ok (input,schedule,w)
                | None -> query tail)
             | _ -> query tail) in
  query (List.rev !segments)

let find ~timeout_ms variant config =
  Result.map (fun ((input : Vectorlayout_input.input),model,w) -> input.config,w,Device_races.events model)
    (find_model ~timeout_ms variant config)
