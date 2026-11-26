open Stdlib
open Unified_interpreter
module D = Core_lang.Device
module V = Device_value
module M = Hivm_module
module L = Mlir_lowering
module Mem = Mlir_memory
module Launch = Mlir_launch
module J = Yojson.Safe.Util

type view = { base:D.expr; offset:D.expr; dims:D.expr list; strides:D.expr list;
              local:(D.space * D.expr) option; banks:V.bank list; element:D.dtype }
type operand = {expr:D.expr; view:view option; active:int option}
type code = {body:D.instruction list; points:(int list * L.source) list}
let empty={body=[];points=[]}
let one ?point cmd={body=[cmd];points=Option.to_list (Option.map (fun p -> [0],p) point)}
let join parts =
  let _,body,points=List.fold_left (fun (at,body,points) part ->
    let shift=function (x::xs,p) -> (at+x)::xs,p | _ -> assert false in
    at+List.length part.body,List.rev_append part.body body,List.rev_append (List.map shift part.points) points)
    (0,[],[]) parts in {body=List.rev body;points=List.rev points}
let below prefix code=List.map (fun (p,src) -> prefix@p,src) code.points
let num n=D.Int (I64,Int64.of_int n)
let zero=num 0 and one_i=num 1
let arithmetic op a b=match a,b with
  | D.Int (I64,i),D.Int (I64,j) -> (match op with
    | D.Add -> D.Int(I64,Int64.add i j) | Sub -> Int(I64,Int64.sub i j)
    | Mul -> Int(I64,Int64.mul i j) | _ -> D.Binary(op,a,b))
  | _ -> D.Binary(op,a,b)
let add=arithmetic D.Add and mul=arithmetic D.Mul
let strides dims=snd (List.fold_right (fun dim (n,ss) -> mul n dim,n::ss) dims (one_i,[]))
let dot offsets steps=List.fold_left2 (fun a b c -> add a (mul b c)) zero offsets steps
let operand ?view ?active expr={expr;view;active}
let descriptor v=D.Strided_view(v.base,v.offset,v.dims,v.strides)
let constant = function D.Int (_,n) -> Int64.to_int n | _ -> invalid_arg "expected a static dimension"
let ty = function
  | "i1" -> D.I1 | "i8" -> I8 | "i16" -> I16 | "i32" -> I32 | "i64" | "index" -> I64
  | "f16" -> F16 | "f32" -> F32 | n -> invalid_arg ("unsupported device register type "^n)
let cast ty e=D.Cast (ty,e)
let boolean = function `Bool b -> b | `Int 0 -> false | `Int (1 | -1) -> true
  | _ -> invalid_arg "expected a boolean attribute"
let mixed static dynamic =
  let rest=ref dynamic in
  let part n=if n<>Z.of_int64 Int64.min_int then num (Z.to_int n) else
    match !rest with x::xs -> rest:=xs;x | [] -> invalid_arg "missing dynamic view operand" in
  let a,b,c=static in
  let a=List.map part a in let b=List.map part b in let c=List.map part c in
  if !rest<>[] then invalid_arg "extra dynamic view operands"; a,b,c
let dimensions shape args =
  let rest=ref args in
  let dims=List.map (function Some n->num n | None->match !rest with
    | x::xs -> rest:=xs;x | [] -> invalid_arg "missing dynamic size") shape in
  if !rest<>[] then invalid_arg "extra dynamic sizes"; dims
let bank loc = function
  | D.UB -> V.Unified loc | Vector_ub i -> Unified {loc with core=Vector i}
  | L1 -> Cbuf loc.block | L0A -> Matrix_a loc.block | L0B -> Matrix_b loc.block
  | L0C -> Acc loc.block | GM i -> Global i
let aff op args =
  let map=L.attribute op "map" in
  let dims=J.to_int (J.member "dimensions" map) in
  let rec expr=function
    | `Int n -> num n | `List [`String "d";`Int i] -> List.nth args i
    | `List [`String "s";`Int i] -> List.nth args (dims+i)
    | `List [`String op;a;b] ->
        let a=expr a and b=expr b in
        (match op with "+" -> add a b | "*" -> mul a b
         | "mod"|"ceildiv"|"floordiv" ->
           let r=D.Binary(Rem,a,b) and q=D.Binary(Div,a,b) in
           let negative=D.Compare(Lt,r,zero) in
           (match op with "mod" -> D.Select(negative,add r b,r)
            | "floordiv" -> D.Select(negative,arithmetic Sub q one_i,q)
            | _ -> D.Select(D.Compare(Gt,r,zero),add q one_i,q))
         | _ -> invalid_arg "unknown affine operation")
    | _ -> invalid_arg "malformed affine operand" in
  match J.to_list (J.member "results" map) with [x] -> expr x | _ -> invalid_arg "expected a single affine result"

type compiled = { streams:D.stream list; sources:((int * int list) * L.source) list;
                  constants:(string * V.value) list; readonly:V.bank list; immutable_views:string list }

let compile ast (launch:Launch.t) memory bindings =
  let serial=ref 0 and constants=ref [] and writes=Hashtbl.create 16 and views=ref [] in
  let fresh ()=incr serial;"kernel.ssa"^string_of_int !serial in
  let register_constant value=let name=fresh () in constants:=(name,value)::!constants;D.Var name in
  let lower_stream (stream:Launch.stream) =
    let loc=stream.location and pipes=ref [] in
    let use p=if not (List.mem p !pipes) then pipes:=p::!pipes;p in
    let note_write v=List.iter (fun k->Hashtbl.replace writes k ()) v.banks in
    let rec function_body parents entry args =
      if List.mem entry parents then invalid_arg "recursive device function";
      let body=M.entry ast entry in
      let types,_=L.function_types body and env=Hashtbl.create 64 and register_groups=Hashtbl.create 8 in
      let counter_bases=ref [] in
      List.iter2 (fun (id,_) value->Hashtbl.add env id value) body.arguments args;
      let get=Hashtbl.find env and type_of id=Mem.type_of ast (Hashtbl.find types id) in
      let shaped id=Mem.shaped ast (Hashtbl.find types id) in
      let expr id=(get id).expr and view id=Option.get (get id).view in
      let element id=match type_of id with M.Shaped t -> ty t.element | _ -> ty (Hashtbl.find types id) in
      let width id=match type_of id with M.Shaped {kind=Vector;shape;_} ->
          List.fold_left (fun n d->n*Option.get d) 1 shape | _ -> 1 in
      let bind ?active ?view ?point id e =
        let x=fresh () in Hashtbl.replace env id (operand ?active ?view (D.Var x));
        Option.iter (fun v->views:=(x,v.banks)::!views) view;one ?point (D.Let(x,e)) in
      let alias id x=Hashtbl.replace env id x;empty in
      let rec rotates (op:M.operation) =
        (op.opcode="hivm.hir.pointer_cast" && (match L.attribute op "operandSegmentSizes" with
          | `List [`Int count;_] -> count>1 | _ -> false)) ||
        (op.opcode<>"scf.for" && List.exists (List.exists (fun (b:M.block)->List.exists rotates b.body)) op.regions) in
      let rec block ?(loop=false) path counter (b:M.block) =
        let anchor=List.exists (fun (op:M.operation)->op.opcode="hivm.hir.multi_buffer_counter") b.body in
        let prefix,counter=if anchor || (loop && List.exists rotates b.body) then (
          let key=fresh () and base=fresh () and at=fresh () in
          counter_bases:=one (D.Let(base,D.Counter key))::!counter_bases;
          join [one (D.Let(at,arithmetic D.Sub (D.Counter key) (D.Var base)));one(D.Advance_counter key)],Some (D.Var at))
          else empty,counter in
        join (prefix::List.mapi (fun i op->L.checked op (fun ()->lower (path@[i]) counter op)) b.body)
      and lower path counter (op:M.operation) =
        let attr=L.attribute op and point=L.point path op in
        let args=List.map expr op.operands in
        let id ()=L.result op in
        let result ?active e=bind ?active (id ()) e in
        let ret_view v=bind ~view:v (id ()) (descriptor v) in
        let work p ops=one ~point (D.Issue(use p,op.opcode,ops)) in
        let write id=let v=view id in note_write v;expr id in
        let ids=List.map fst op.results in
        let layout t bits e=D.Layout_cast({element=t;lane_bits=bits},e) in
        let splat e n=if n=1 then e else D.Broadcast(e,n) in
        match op.opcode,op.operands,op.regions with
        | ("func.return"|"scf.yield"|"annotation.mark"),_,_ -> empty
        | "arith.constant",[],_ ->
            let t=element (id ()) in
            let literal=function
              | `Bool b -> if b then 1L else 0L
              | `String n when V.is_float t -> V.encode t (float_of_string n)
              | v -> Z.to_int64 (Mlir_scalar.signed 64 (Launch.z_of_json v)) in
            (match attr "value" with
             | `List xs -> alias (id ()) (operand (register_constant (V.vec t (Array.of_list (List.map literal xs)))))
             | `String n when V.is_float t -> alias (id ()) (operand (D.Float(t,float_of_string n)))
             | v -> alias (id ()) (operand (D.Int(t,literal v))))
        | "scf.if",[cond],[yes;no] when ids=[] ->
            let arm n=function []->empty | [b]->block (path@[n;0]) counter b | _->invalid_arg "multiple blocks" in
            let yes=arm 0 yes and no=arm 1 no in
            {body=[D.If(expr cond,yes.body,no.body)];points=below [0;0] yes @ below [0;1] no}
        | "scf.for",lo::hi::step::initial,[[b]] ->
            let iv,_=List.hd b.arguments and acc=List.tl b.arguments in
            let iterator=fresh () in
            Hashtbl.add env iv (operand (D.Var iterator));
            let carried=List.map2 (fun (id,_) init->
              let x=fresh () in Hashtbl.add env id {(get init) with expr=D.Var x};x,expr init) acc initial in
            let body=block ~loop:true (path@[0;0]) counter b in
            let yield=match List.rev b.body with {opcode="scf.yield";operands;_}::_ -> List.map expr operands
              | _ -> invalid_arg "loop requires yield" in
            List.iter2 (fun id (arg,_)->ignore(alias id (get arg))) ids acc;
            {body=[D.For {index=iterator;index_type=element iv;lo=expr lo;hi=expr hi;step=expr step;carried;
                          body=body.body;yield}];points=below [0] body}
        | "func.call",_,_ when ids=[] && attr "hivm.vector_function"<>`Null ->
            let callee=J.to_string (attr "callee") in
            let code=function_body (entry::parents) callee (List.map get op.operands) in
            work V code.body
        | "affine.apply",_,_ -> result (aff op args)
        | "arith.select",[p;a;b],_ -> (match (get a).view,(get b).view with
            | None,None -> result (D.Select(expr p,expr a,expr b))
            | Some va,Some vb ->
                let select a b=D.Select(expr p,a,b) in
                ret_view {va with base=select va.base vb.base;offset=select va.offset vb.offset;
                  dims=List.map2 select va.dims vb.dims;strides=List.map2 select va.strides vb.strides;
                  banks=List.sort_uniq compare (va.banks@vb.banks);local=None}
            | _ -> invalid_arg "incompatible select operands")
        | "arith.cmpi",[a;b],_ ->
            let pred=match J.to_int (attr "predicate") with 0->D.Eq|1->Ne|2->Lt|3->Le|4->Gt|5->Ge
              | _ ->invalid_arg "unsupported unsigned comparison" in result (D.Compare(pred,expr a,expr b))
        | "arith.cmpf",[a;b],_ when attr "predicate"=`Int 13 -> result (D.Compare(Ne,expr a,expr b))
        | ("arith.bitcast"|"vector.bitcast"),[a],_ -> result (D.Bitcast(element (id ()),expr a))
        | ("arith.index_cast"|"arith.extsi"|"arith.extui"|"arith.trunci"),[a],_ ->
            let t=element (id ()) in let v=cast t (expr a) in
            result (if op.opcode="arith.extui" && element a<>D.I1 then
              D.Binary(And,v,D.Int(t,Int64.pred (Int64.shift_left 1L (D.bits (element a))))) else
              if op.opcode="arith.extsi" && element a=D.I1 then D.Binary(Sub,D.Int(t,0L),v) else v)
        | ("arith.addi"|"arith.subi"|"arith.muli"|"arith.divsi"|"arith.remsi"|"arith.remui"|
           "arith.andi"|"arith.ori"|"arith.shrsi"|"arith.maxsi"|"arith.minsi"|"arith.mulf"|"arith.maximumf"),[a;b],_ ->
            let binary=match op.opcode with "arith.addi"->D.Add|"arith.subi"->Sub|"arith.muli"|"arith.mulf"->Mul
              | "arith.divsi"->Div|"arith.remui"|"arith.remsi"->Rem|"arith.andi"->And|"arith.ori"->Or
              | "arith.shrsi"->Shr|"arith.minsi"->Min|_->Max in
            let value= D.Binary(binary,expr a,expr b) in
            result (if op.opcode="arith.remui" then match expr b with
              | D.Int(t,n) when n>0L && Int64.logand n (Int64.pred n)=0L -> D.Binary(And,expr a,D.Int(t,Int64.pred n))
              | _->invalid_arg "unsigned remainder requires a power-of-two divisor" else value)
        | "hivm.hir.get_block_idx",[],_ -> result (cast (element (id ())) D.Block)
        | "hivm.hir.get_sub_block_idx",[],_ -> result (cast (element (id ())) D.Subblock)
        | "hivm.hir.multi_buffer_counter",[],_ -> alias (id ()) (operand (Option.get counter))
        | "hivm.hir.pointer_cast",_,_ ->
            let t=shaped (id ()) in
            let count=match attr "operandSegmentSizes" with `List [`Int n;_] -> n | _->invalid_arg "invalid pointer operands" in
            let addresses=List.take count args in
            let byte=match addresses with [a]->a | []-> invalid_arg "empty pointer address list" | a::xs ->
              let slot=D.Binary(Rem,Option.get counter,num count) in
              snd (List.fold_left (fun (i,chosen) addr->i+1,D.Select(D.Compare(Eq,slot,num i),addr,chosen)) (1,a) xs) in
            let s=match L.space t.space with 2->D.L1|3->L0A|4->L0B|5->L0C|6->UB|_->invalid_arg "non-local device pointer" in
            let dims=dimensions t.shape (List.drop count args) and element=element (id ()) in
            ret_view {base=D.Buffer(s,element,byte,[],[]);offset=zero;dims;strides=strides dims;local=Some(s,byte);
                      banks=[bank loc s];element}
        | "memref.cast",[a],_ -> alias (id ()) (get a)
        | "memref.extract_strided_metadata",[a],_ ->
            let v=view a in
            (match ids with base::offset::rest ->
               let root={v with offset=zero;dims=[];strides=[]} in
               join (bind ~view:root base (descriptor root)::bind offset v.offset::
                 List.map2 (fun id e->bind id e) rest (v.dims@v.strides))
             | _->invalid_arg "invalid metadata results")
        | ("memref.reinterpret_cast"|"memref.subview"),a::dynamic,_ ->
            let v=view a in let offs,dims,steps=mixed (L.slice_attributes op) (List.map expr dynamic) in
            if op.opcode="memref.reinterpret_cast" then ret_view {v with offset=List.hd offs;dims;strides=steps}
            else
              let offset=add v.offset (dot offs v.strides) in
              let rec reduce axes target=match axes,target with
                | [],[]->Some [] | (size,stride)::xs,k::ks when k=None || Some size=Option.map num k ->
                    (match reduce xs ks with Some rest->Some ((size,stride)::rest)
                     | None when size=one_i->reduce xs target | _->None)
                | (size,_)::xs,_ when size=one_i -> reduce xs target | _->None in
              let axes=List.combine dims (List.map2 mul v.strides steps) in
              let dims,strides=List.split (if List.length axes=List.length (shaped (id ())).shape then axes
                else Option.get (reduce axes (shaped (id ())).shape)) in
              ret_view {v with offset;dims;strides}
        | ("memref.expand_shape"|"memref.collapse_shape"),a::dynamic,_ ->
            let v=view a in let groups=J.to_list (attr "reassociation") |> List.map (fun j->List.map J.to_int (J.to_list j)) in
            let dims,steps=if op.opcode="memref.expand_shape" then
              let dims=dimensions (shaped (id ())).shape (List.map expr dynamic) in
              dims,List.concat (List.map2 (fun stride group->List.map (mul stride) (strides (List.map (List.nth dims) group))) v.strides groups)
            else List.map (List.fold_left (fun n i->mul n (List.nth v.dims i)) one_i) groups,
                 List.map (fun group->let active=List.filter (fun i->List.nth v.dims i<>one_i) group in
                   List.nth v.strides (List.hd (List.rev (if active=[] then group else active)))) groups in
            ret_view {v with dims;strides=steps}
        | "memref.load",a::ix,_ -> bind ~point (id ()) (D.Read(expr a,List.map expr ix,1))
        | "memref.store",x::a::ix,_ -> work S [D.Store(write a,List.map expr ix,expr x)]
        | ("vector.broadcast"|"ave.hir.scalar_broadcast"),[x],_ -> result (splat (expr x) (width (id ())))
        | "ave.hir.broadcast",[x;p],_ ->
            let n=width (id ()) and t=element x in
            result (D.Select(expr p,splat (expr x) n,(if V.is_float t then D.Float(t,0.) else D.Int(t,0L))))
        | "vector.shape_cast",[x],_ -> alias (id ()) (get x)
        | "vector.constant_mask",[],_ ->
            let limits=List.map J.to_int (J.to_list (attr "mask_dim_sizes")) and n=width (id ()) in
            let shape=List.map Option.get (shaped (id ())).shape in
            let data=Array.init n (fun i->if List.for_all2 (<) (Mlir_vector.coordinates shape i) limits then 1L else 0L) in
            let active=Array.fold_left (fun n x->n+Int64.to_int x) 0 data in
            if Array.exists Fun.id (Array.mapi (fun i x->(i<active)<>(x<>0L)) data) then
              invalid_arg "non-prefix transfer mask";
            alias (id ()) (operand ~active (register_constant (V.vec I1 data)))
        | "ave.hir.pge",[],_ when L.enum (attr "pattern")="ALL" ->
            let n=width (id ()) in result ~active:n (D.Pge n)
        | "ave.hir.plt",[n],_ ->
            (match ids with [a;b]->let p=fresh () and x=fresh () in
              ignore(alias a (operand (D.Var p)));ignore(alias b (operand (D.Var x)));
              one(D.Let_plt(p,x,width a,expr n)) | _->invalid_arg "invalid PLT")
        | "ave.hir.vintlv",[a;b],_ ->
            (match ids with [lo;hi]->let l=fresh () and h=fresh () in
              ignore(alias lo (operand (D.Var l)));ignore(alias hi (operand (D.Var h)));
              one(D.Interleave(l,h,expr a,expr b)) | _->invalid_arg "invalid interleave")
        | ("ave.hir.preg.xor"|"ave.hir.preg.and"|"ave.hir.vxor"|"ave.hir.vor"),[a;b;m],_ ->
            let kind=match op.opcode with "ave.hir.preg.and"->D.And|"ave.hir.vor"->Or|_->Xor in
            result (D.Select(expr m,D.Binary(kind,expr a,expr b),D.Int(element a,0L)))
        | "ave.hir.vsel",[m;a;b],_ -> result (D.Select(expr m,expr a,expr b))
        | "ave.hir.vextsi",[x;m],_ when L.enum (attr "part")="part_even" ->
            let t=element (id ()) in
            let registers=D.bits t / D.bits (element x) in
            Hashtbl.replace register_groups (id ()) registers;
            result (D.Register_group(registers,D.Select(expr m,cast t (expr x),D.Int(t,0L))))
        | "ave.hir.vcmp",[a;b;m],_ when L.enum (attr "cmp")="NE" ->
            result (D.Binary(And,expr m,D.Compare(Ne,expr a,expr b)))
        | "ave.hir.vector.layout_cast",[x],_ -> result (expr x)
        | "builtin.unrealized_conversion_cast",[x],_ -> alias (id ()) (get x)
        | "ave.hir.vector_broadcast",[x;p],_ when boolean (attr "low") ->
            let t=element x in result (D.Select(expr p,D.Splat_lane(expr x,0,width (id ())),
              (if V.is_float t then D.Float(t,0.) else D.Int(t,0L))))
        | "vector.multi_reduction",[a;b],_ when attr "kind"=`String "#vector.kind<maximumf>" ->
            result (D.Binary(Max,D.Reduce_max(expr a),expr b))
        | "ave.hir.vload",a::ix,_ ->
            let v=view a in let offset=dot (List.map expr ix) v.strides in
            let n=if List.mem_assoc "1xi1 processed" op.attributes then 256 else width (id ()) in
            let register=D.Strided_view(expr a,offset,[num n],[one_i]) in
            result (D.Read(register,[zero],n))
        | "ave.hir.masked_store",a::tail,_ ->
            let ix=List.take (List.length (view a).dims) tail in
            (match List.drop (List.length ix) tail with [p;x] ->
              let scale,packing=match L.enum (attr "functionType") with
                | "pk"->2,D.Pk|"pk4"->4,Pk4|"norm"->1,Norm|s->invalid_arg ("unknown store layout "^s) in
              let t=element a in let bits=D.bits t*scale in
              let registers=Option.value (Hashtbl.find_opt register_groups x) ~default:1 in
              one ~point (D.Masked_store(write a,List.map expr ix,layout I1 (bits/registers) (expr p),layout t bits (expr x),packing))
             | _->invalid_arg "invalid masked store")
        | ("vector.transfer_read"|"vector.transfer_write"),_,_ ->
            let reading=op.results<>[] in
            let vector,a,tail=match reading,op.operands with true,a::ix->id (),a,ix
              | false,x::a::ix->x,a,ix | _->invalid_arg "invalid vector transfer" in
            let v=view a and shape=List.map Option.get (shaped vector).shape in
            let rank=List.length v.dims and n=width vector in
            let ix=List.map expr (List.take rank tail) in
            let extras=List.drop rank tail in
            let mask=match reading,extras with true,[_]|false,[]->None|true,[_;m]|false,[m]->Some m
              | _->invalid_arg "invalid transfer operands" in
            let valid=Option.fold ~none:n ~some:(fun m->Option.get (get m).active) mask in
            let axes=J.to_list (J.member "results" (attr "permutation_map")) |> List.map (function
              | `List [`String "d";`Int i]->Some i | `Int 0->None | _->invalid_arg "invalid transfer map") in
            let steps=List.map (Option.fold ~none:zero ~some:(List.nth v.strides)) axes in
            let offset=dot ix v.strides in
            let contiguous=List.for_all2 (fun (d,a) b->d=1 || a=b) (List.combine shape steps) (strides (List.map num shape)) in
            let addr i=add offset (dot (List.map num (Mlir_vector.coordinates shape i)) steps) in
            let linear off count=D.Strided_view(expr a,off,[num count],[one_i]) in
            let extract x i=D.Splat_lane(x,i,1) in
            if reading then (
              let read i=D.Read(linear (addr i) 1,[zero],1) in
              if List.for_all2 (fun d s->d=1 || s=zero) shape steps && valid=n then result (splat (read 0) n)
              else if contiguous && valid=n then result (D.Read(linear offset n,[zero],n))
              else (
                let registers=List.init valid (fun i->let x=fresh () in x,one(D.Let(x,read i))) in
                let selection=List.mapi (fun i (x,_)->i,D.Var x) registers in
                let selector=D.Range(zero,n) in
                let rec choose lo hi = if lo=hi then snd (List.nth selection lo) else
                  let mid=(lo+hi)/2 in D.Select(D.Compare(Le,selector,num mid),choose lo mid,choose (mid+1) hi) in
                let padding=expr (List.hd extras) in
                let expression=if valid=0 then splat padding n else if valid=1 then
                  D.Select(D.Plt(n,one_i),snd (List.hd selection),padding) else
                  D.Select(D.Plt(n,num valid),choose 0 (valid-1),padding) in
                join (List.map snd registers@[result expression])))
            else (
              note_write v;
              if contiguous && valid=n then one ~point (D.Store(linear offset n,[zero],expr vector))
              else join (List.init valid (fun i->one ~point (D.Store(linear (addr i) 1,[zero],extract (expr vector) i)))))
        | "hivm.hir.debug",[v],_ when attr "debugtype"=`String "print" ->
            let prefix=match attr "prefix" with `String s->s | `Null->"" | _->invalid_arg "invalid debug prefix" in
            work S [D.Debug(prefix,expr v)]
        | "hivm.hir.load",[s;d],_ -> work MTE2 [D.Copy(expr s,write d)]
        | "hivm.hir.store",[s;d],_ -> work MTE3 [D.Copy(expr s,write d)]
        | "hivm.hir.vbrc",[x;d],_ -> work (if Option.map fst (view d).local=Some D.L1 then MTE2 else V) [D.Fill(write d,expr x)]
        | "hivm.hir.nd2nz",[s;d],_ -> work MTE2 [D.Nd2nz(expr s,write d)]
        | "hivm.hir.copy",[s;d],_ -> work (if Option.map fst (view d).local=Some D.L1 then MTE3 else V) [D.Copy(expr s,write d)]
        | "hivm.hir.indirect_load",[s;o;a;b;c],_ ->
            let m,f,d=if op.generic then b,c,a else a,b,c in
            work V [D.Indirect_load(expr s,expr o,expr m,expr f,write d)]
        | "hivm.hir.indirect_store",[a;o;b;c],_ ->
            let s,m,d=if op.generic then b,c,a else a,b,c in
            work V [D.Indirect_store(expr s,expr o,expr m,write d)]
        | "hivm.hir.set_ctrl",[],_ -> one ~point (D.Control(J.to_int (attr "idx"),boolean (attr "enable")))
        | "hivm.hir.pipe_barrier",[],_ ->
            let pipes=match L.enum (attr "pipe") with "PIPE_ALL"->[D.S;V;M;MTE1;MTE2;MTE3;FIX] | p->[Launch.pipe p] in
            one ~point (D.Barrier pipes)
        | ("hivm.hir.set_flag"|"hivm.hir.wait_flag"|"hivm.hir.sync_block_set"|"hivm.hir.sync_block_wait"),_,_ ->
            let local=List.mem op.opcode ["hivm.hir.set_flag";"hivm.hir.wait_flag"] in
            if not local then (
              let send=op.opcode="hivm.hir.sync_block_set" in
              let edges=Option.value launch.edges ~default:[] in
              List.iter (fun (s:Launch.stream) ->
                let physical=s.location.block=loc.block && (s.location.core=D.Cube)<>(loc.core=D.Cube) in
                if List.mem (if send then stream.id,s.id else s.id,stream.id) edges<>physical then
                  invalid_arg "cross-core edges must select the peer cores in this block") launch.streams);
            let p=use (Launch.pipe (L.enum (attr (if local then "set_pipe" else "tpipe"))))
            and q=use (Launch.pipe (L.enum (attr (if local then "wait_pipe" else "pipe")))) in
            let id=match args,attr (if local then "static_event_id" else "static_flag_id") with
              | [x],`Null->x | [],`Int n->num n | [],(`String _ as v)->let s=L.enum v in
                  let prefix="EVENT_ID" in
                  if not (String.starts_with ~prefix s) then invalid_arg "invalid static event id";
                  num (int_of_string (String.sub s (String.length prefix) (String.length s-String.length prefix)))
              | _->invalid_arg "invalid synchronization flag" in
            let channel=if local then D.Local else Cross in
            one ~point (if List.mem op.opcode ["hivm.hir.set_flag";"hivm.hir.sync_block_set"] then D.Set(channel,p,q,id)
                       else D.Wait(channel,p,q,id))
        | "hivm.hir.mmadL1",a::b::init::m::k::n::dst::sync,_ ->
            let m=constant (expr m) and k=constant (expr k) and n=constant (expr n) in
            let a_ty=element a and b_ty=element b in
            let block r c=[num ((c+15)/16);num ((r+15)/16);num 16;num 16] in
            let ta=attr "a_transpose"<>`Null and tb=attr "b_transpose"<>`Null in
            if ta then invalid_arg "unsupported transposed A matrix";
            let ma=D.Buffer(L0A,a_ty,zero,block m k,[]) and mb=D.Buffer(L0B,b_ty,zero,(if tb then block n k else block k n),[]) in
            let part name cmd=one ~point:(L.point ~part:name path op) cmd in
            let maybe name cmd id=match expr id with D.Int(_,-1L)->empty
              | D.Int(_,v) when v>=0L->part name (cmd (expr id))
              | v->let body=part name (cmd v) in {body=[D.If(D.Compare(Ge,v,zero),body.body,[])];points=below [0;0] body} in
            let waits,sets=match sync with [wa;wb;sa;sb;db;b0;b1] when List.for_all (fun id->constant(expr id)=(-1)) [db;b0;b1] ->
                [maybe "wait_a" (fun x->D.Wait(Local,MTE2,MTE1,x)) wa;maybe "wait_b" (fun x->D.Wait(Local,MTE2,MTE1,x)) wb],
                [maybe "release_a" (fun x->D.Set(Local,MTE1,MTE2,x)) sa;maybe "release_b" (fun x->D.Set(Local,MTE1,MTE2,x)) sb]
              | _->invalid_arg "unsupported matrix synchronization operands" in
            join (waits@[part "wait_matrix" (D.Wait(Local,M,MTE1,zero));
                         part "load" (D.Issue(use MTE1,"load",[D.Copy(expr a,ma);D.Copy(expr b,mb)]))]@sets@
                  [part "signal_loaded" (D.Set(Local,MTE1,M,zero));part "wait_loaded" (D.Wait(Local,MTE1,M,zero));
                   part "compute" (D.Issue(use M,"compute",[D.Mmad(ma,mb,write dst,expr init,m,k,n,tb)]));
                   part "release_matrix" (D.Set(Local,M,MTE1,zero))])
        | "hivm.hir.fixpipe",[s;d],_ when L.enum (attr "dual_dst_mode")="ROW_SPLIT" ->
            let v=view d in let ub=match v.local with Some(D.UB,byte)->byte | _->invalid_arg "expected UB destination" in
            let target i=let space=D.Vector_ub i in Hashtbl.replace writes (bank loc space) ();
              descriptor {v with base=D.Buffer(space,v.element,ub,[],[])} in
            work FIX [D.Fixpipe_row_split(expr s,target 0,target 1)]
        | _->invalid_arg ("unsupported indexed kernel instruction "^op.opcode) in
      let code=block [] None body in
      join (List.rev_append !counter_bases [code]) in
    let args=List.map (fun (id,v)->
      let name=Printf.sprintf "stream%d.ssa%d" stream.id id in
      match v,List.assoc name bindings with
      | Core_lang.VBuffer b,V.View initial ->
          let dims=List.map num b.shape and strides=List.map (fun v->num (Z.to_int v)) b.strides in
          let offset=num (Z.to_int b.offset) in
          let base=register_constant (V.View {initial with bit=8*b.base_bytes;shape=[||];strides=[||]}) in
          let v={base;offset;dims;strides;local=None;banks=[initial.bank];element=initial.ty} in
          views:=(name,v.banks)::!views;operand ~view:v (D.Var name)
      | _,_ -> operand (D.Var name)) stream.arguments in
    let code=function_body [] stream.entry args in
    Option.iter (fun declared -> if not (List.for_all (fun p -> List.mem p declared) !pipes) then
      invalid_arg (stream.entry^" uses a pipe missing from its launch configuration")) stream.pipes;
    D.{location=loc;body=code.body},List.map (fun (site,p)->(stream.id,site),p) code.points in
  let streams,sources=List.split (List.map lower_stream launch.streams) in
  let readonly=List.concat_map (fun (_,banks)->banks) !views |> List.sort_uniq compare |>
    List.filter (function V.Allocation _ as b->not (Hashtbl.mem writes b) | _->false) in
  let immutable_views=List.filter_map (fun (x,bs)->if bs<>[] && List.for_all (fun b->List.mem b readonly) bs then Some x else None) !views in
  List.iter (fun (s:Launch.stream)->let b=s.location.block in
    List.iter (fun (bank,bytes)->if not (Hashtbl.mem memory bank) then Hashtbl.add memory bank (Bytes.make bytes '\000'))
      [V.Cbuf b,512*1024;Matrix_a b,64*1024;Matrix_b b,64*1024;Acc b,256*1024;
       Unified s.location,248*1024]) launch.streams;
  {streams;sources=L.validate_sources ast launch (List.concat sources);constants= !constants;readonly;immutable_views}
