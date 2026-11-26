open Device_ast
module Names = Set.Make(String)

(* 每个可直接追踪的 store 的寄存器操作数仅依赖入口值或只读 GM。
   因此它执行期间观察到的读集合足以确定相应写入的内容。 *)
let direct_stores ?(describe=fun _ _ message -> message) program =
  let sites = Hashtbl.create 128 in
  let rec pure env memory = function
    | Var x -> not (Names.mem x env)
    | Int _ | Float _ | Block | Subblock | Counter _ | Pge _ -> true
    | Read (Var ("arg4"|"arg5"|"arg6"|"arg7"|"arg8"),ix,_) -> List.for_all (pure env memory) ix
    | Read (x,ix,_) -> memory && List.for_all (pure env memory) (x::ix)
    | Range (x,_) | Broadcast (x,_) | Cast (_,x) | Bitcast (_,x) | Layout_cast (_,x)
    | Register_group (_,x) | Plt (_,x) | Splat_lane (x,_,_) | Reduce_max x -> pure env memory x
    | Binary (_,a,b) | Compare (_,a,b) -> pure env memory a && pure env memory b
    | Select (a,b,c) -> List.for_all (pure env memory) [a;b;c]
    | Buffer (_,_,a,ds,ss) -> List.for_all (pure env memory) (a::ds@ss)
    | Slice (x,a,b,c) -> List.for_all (pure env memory) (x::a@b@c)
    | Strided_view (x,a,b,c) | Reinterpret_view (x,a,b,c) -> List.for_all (pure env memory) (x::a::b@c)
    | Reshape (x,ds) | Tensor_get (x,ds) -> List.for_all (pure env memory) (x::ds)
    | Empty_tensor (_,ds) -> List.for_all (pure env memory) ds
    | Tensor_fill (a,b) -> List.for_all (pure env memory) [a;b]
    | Tensor_range (x,ds,t) | Tensor_insert (x,ds,t) -> List.for_all (pure env memory) (x::t::ds)
    | Tensor_compare (_,a,b,t) -> List.for_all (pure env memory) [a;b;t]
    | Gather_tensor _ -> false in
  let rec walk stream nested env path body =
    let bind env x clean = if clean then Names.remove x env else Names.add x env in
    List.fold_left (fun (i,env) cmd ->
      let pc=path@[i] in
      let reject message = invalid_arg (describe stream pc message) in
      let fixed exprs =
        if not (List.for_all (pure env false) exprs) then
          reject "device instruction geometry depends on mutable memory" in
      let rec addresses = function
        | Counter _ when nested -> reject "queued counter read"
        | Read (base,ix,_) -> fixed (base::ix)
        | Range (x,_) | Broadcast (x,_) | Cast (_,x) | Bitcast (_,x) | Layout_cast (_,x)
        | Register_group (_,x) | Plt (_,x) | Splat_lane (x,_,_) | Reduce_max x -> addresses x
        | Binary ((Div|Rem),a,b) -> fixed [b];addresses a;addresses b
        | Binary (_,a,b) | Compare (_,a,b) -> addresses a;addresses b
        | Select (a,b,c) -> List.iter addresses [a;b;c]
        | Buffer (_,_,a,ds,ss) -> fixed (a::ds@ss)
        | Strided_view (x,a,b,c) | Reinterpret_view (x,a,b,c) -> fixed (x::a::b@c)
        | Slice (x,a,b,c) -> fixed (x::a@b@c)
        | Reshape (x,ds) -> fixed (x::ds)
        | Empty_tensor (_,ds) -> fixed ds
        | Tensor_get (x,ds) -> fixed ds; addresses x
        | Tensor_fill (a,b) -> List.iter addresses [a;b]
        | Tensor_range (x,ds,t) -> List.iter addresses (x::t::ds)
        | Tensor_insert (x,ds,t) -> fixed ds; List.iter addresses [x;t]
        | Tensor_compare (_,a,b,t) -> List.iter addresses [a;b;t]
        | Gather_tensor (s,o,m,f,d) -> fixed [s;o;m;f;d]
        | _ -> () in
      (match cmd with
       | For l -> fixed [l.lo;l.hi;l.step];List.iter addresses (List.map snd l.carried @ l.yield)
       | If (e,_,_) | Set (_,_,_,e) | Wait (_,_,_,e) -> fixed [e]
       | Store (d,ix,x) -> fixed (d::ix);addresses x
       | Masked_store (d,ix,p,x,_) -> fixed (d::p::ix);addresses x
       | Mmad (a,b,d,i,_,_,_,_) -> fixed [a;b;d;i]
       | Indirect_store (s,o,m,d) -> fixed [s;o;m;d]
       | Scatter_tensor (s,o,m,d) -> fixed [o;m;d]; addresses s
       | Indirect_load (s,o,m,f,d) -> fixed [s;o;m;f;d]
       | Fill (d,x) -> fixed [d];addresses x
       | Copy (s,d) | Nd2nz (s,d) -> fixed [s;d]
       | Copy_tensor (s,d) -> fixed [d]; addresses s
       | Fixpipe_row_split (s,a,b) -> fixed [s;a;b]
       | Debug (_,x) | Let (_,x) | Let_plt (_,_,_,x) -> addresses x
       | Interleave (_,_,x,y) -> addresses x;addresses y
       | (Control _ | Advance_counter _) when nested -> reject "queued mutable scalar state"
       | _ -> ());
      let env = match cmd with
      | Let (x,e) -> bind env x (pure env false e)
      | Let_plt (a,b,_,e) -> let clean=pure env false e in bind (bind env a clean) b clean
      | Interleave (a,b,x,y) -> let clean=pure env false x && pure env false y in bind (bind env a clean) b clean
      | For l ->
          let inner = List.fold_left (fun e (x,_) -> Names.add x e) env l.carried in
          walk stream nested inner pc l.body;inner
      | If (_,yes,no) -> walk stream nested env (pc@[0]) yes;walk stream nested env (pc@[1]) no;env
      | Issue (_,_,body) -> walk stream true env pc body;env
      | Store (d,ix,x) when List.for_all (pure env true) (d::x::ix) ->
          Hashtbl.replace sites (stream,pc) ();env
      | _ -> env in i+1,env) (0,env) body |> ignore in
  List.iteri (fun i s -> walk i false Names.empty [] s.body) program.streams;sites
