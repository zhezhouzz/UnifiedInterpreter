open Device_ast
module Names = Set.Make(String)
module Values = Map.Make(String)
module Paths = Set.Make(struct type t = int list let compare = compare end)

let combine a b = Option.bind a (fun a -> Option.map (Paths.union a) b)

(* 数据寄存器可以在任务内部多次变换。记录影响最终写入的读取指令，
   由执行该任务时实际观察到的地址决定每次写入依赖的输入。 *)
let rec input_paths env pc expr =
  let inputs xs = List.fold_left (fun acc e -> combine acc (input_paths env pc e)) (Some Paths.empty) xs in
  match expr with
  | Var x -> Option.value (Values.find_opt x env) ~default:(Some Paths.empty)
  | Read (x,ix,_) -> Option.map (Paths.add pc) (inputs (x::ix))
  | Range (x,_) | Broadcast (x,_) | Cast (_,x) | Bitcast (_,x) | Layout_cast (_,x)
  | Register_group (_,x) | Plt (_,x) | Splat_lane (x,_,_) | Reduce_max x -> inputs [x]
  | Binary (_,a,b) | Compare (_,a,b) -> inputs [a;b]
  | Select (a,b,c) -> inputs [a;b;c]
  | Buffer (_,_,x,ds,ss) -> inputs (x::ds@ss)
  | Strided_view (x,a,b,c) | Reinterpret_view (x,a,b,c) -> inputs (x::a::b@c)
  | Slice (x,a,b,c) -> inputs (x::a@b@c)
  | Reshape (x,ds) -> inputs (x::ds)
  | Empty_tensor (_,ds) -> inputs ds
  | Tensor_range (x,ds,t) | Tensor_insert (x,ds,t) -> inputs (x::t::ds)
  | Tensor_get _ | Tensor_fill _ | Tensor_compare _ | Gather_tensor _ -> None
  | Int _ | Float _ | Block | Subblock | Counter _ | Pge _ -> Some Paths.empty

(* 每个可直接追踪的 store 的寄存器操作数仅依赖入口值或只读 GM。
   因此它执行期间观察到的读集合足以确定相应写入的内容。 *)
let direct_stores ?(describe=fun _ _ message -> message) ?(immutable_views=[]) program =
  let immutable_views = Names.of_list immutable_views in
  let sites = Hashtbl.create 128 in
  let rec pure env memory = function
    | Var x -> not (Names.mem x env)
    | Int _ | Float _ | Block | Subblock | Counter _ | Pge _ -> true
    | Read (Var x,ix,_) when Names.mem x immutable_views -> List.for_all (pure env memory) ix
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
  let rec walk stream nested env sources path body =
    let bind env x clean = if clean then Names.remove x env else Names.add x env in
    let sources = ref sources in
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
      let data e = input_paths !sources pc e in
      let put x deps = sources := Values.add x deps !sources in
      (match cmd with
       | Let (x,e) -> put x (data e)
       | Let_plt (a,b,_,e) -> let deps=data e in put a deps;put b deps
       | Interleave (a,b,x,y) -> let deps=combine (data x) (data y) in put a deps;put b deps
       | (Store (_,_,x) | Masked_store (_,_,_,x,_) | Fill (_,x)) ->
           Option.iter (fun paths -> Hashtbl.replace sites (stream,pc) (Paths.elements paths)) (data x)
       | _ -> ());
      let env = match cmd with
      | Let (x,e) -> bind env x (pure env false e)
      | Let_plt (a,b,_,e) -> let clean=pure env false e in bind (bind env a clean) b clean
      | Interleave (a,b,x,y) -> let clean=pure env false x && pure env false y in bind (bind env a clean) b clean
      | For l ->
          let inner = List.fold_left (fun e (x,_) -> Names.add x e) env l.carried in
          List.iter (fun (x,_) -> put x None) l.carried;
          walk stream nested inner !sources pc l.body;inner
      | If (_,yes,no) -> walk stream nested env !sources (pc@[0]) yes;walk stream nested env !sources (pc@[1]) no;env
      | Issue (_,_,body) ->
          let captured = Names.fold (fun x vars -> Values.add x None vars) env Values.empty in
          walk stream true env captured pc body;env
      | _ -> env in i+1,env) (0,env) body |> ignore in
  List.iteri (fun i s -> walk i false Names.empty Values.empty [] s.body) program.streams;sites
