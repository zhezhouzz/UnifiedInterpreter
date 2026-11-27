open Stdlib
open Unified_interpreter
module M = Hivm_module
module L = Mlir_lowering
module E = Hivm_event
module D = Dispatch
module A = Z3.Arithmetic
module B = Z3.Boolean

exception Unsupported
exception Unresolved of string
type number = {term:Z3.Expr.expr; lo:Z.t; hi:Z.t}
type view = {bank:Z3.Expr.expr; base:Z3.Expr.expr; count:int; width:int}
type value = Num of number | Buf of view | Test of Z3.Expr.expr
type access = {read:view; write:view; epoch:int; path:int list}
type plan = {rounds:int; paths:(int list * string) list; minimum:int option}

let require ok = if not ok then raise Unsupported
let summarize ~timeout_ms ~hfusion ast (stream:Mlir_launch.stream) =
  let rec split acc = function
    | (op:M.operation)::[{opcode="func.return";operands=[];_}] when op.opcode="scf.for" ->
        List.rev acc,op
    | op::rest -> split (op::acc) rest
    | [] -> raise Unsupported in
  let pre,loop=split [] stream.ast.body in
  let lower,upper,step,iv,body=match loop.operands,loop.regions,loop.results with
    | [lo;hi;s],[[{arguments=[iv,"index"];body}]],[] -> lo,hi,s,iv,body
    | _ -> raise Unsupported in
  let launch_bound id=match List.assoc_opt id stream.arguments with
    | Some (Core_lang.VInt n)->n
    | _->match List.find_opt (fun (op:M.operation)->op.results=[id,"index"]) pre with
      | Some op when op.opcode="arith.constant" -> Mlir_launch.z_of_json (L.attribute op "value")
      | _->raise Unsupported in
  let lo=launch_bound lower and hi=launch_bound upper and stride=launch_bound step in
  require (Z.sign stride>0 && Z.fits_int lo && Z.fits_int hi && Z.fits_int stride);
  let trips=Z.max Z.zero (Z.cdiv (Z.sub hi lo) stride) in
  require (Z.fits_int trips);
  let rounds=Z.to_int trips in
  let ctx=Z3.mk_context [] in
  let z n=A.Integer.mk_numeral_s ctx (Z.to_string n) and int=A.Integer.mk_numeral_i ctx in
  let number n=Num {lo=n;hi=n;term=z n} in
  let env=Hashtbl.create 32 in
  List.iter (fun (id,v)->Hashtbl.add env id (match v with
    | Core_lang.VInt n -> number n
    | VBuffer {storage=Some (Input bank);shape=[count];strides=[stride];offset;base_bytes;element_bytes;bytes}
      when Z.equal stride Z.one ->
        let first=Z.(add (of_int base_bytes) (mul offset (of_int element_bytes))) in
        let limit=Z.(add first (mul (of_int count) (of_int element_bytes))) in
        require (Z.sign first>=0 && Z.leq limit (Z.of_int bytes));
        Buf {bank=int bank;count;width=element_bytes;base=z first}
    | _ -> raise Unsupported)) stream.arguments;
  let constant op = match L.attribute op "value" with
    | (`Int _ | `Intlit _) as v -> number (Mlir_launch.z_of_json v) | _ -> raise Unsupported in
  List.iter (fun (op:M.operation)->match op.opcode,op.results,op.operands with
    | "arith.constant",[id,"index"],[] -> Hashtbl.add env id (constant op)
    | ("memref.alloc"|"memref.alloca"),[id,ty],[] ->
        let shaped=Mlir_memory.shaped ast ty in
        (match shaped.kind,shaped.layout,shaped.shape with
         | Memref,Identity,[Some count] -> Hashtbl.add env id (Buf {bank=int (-1-id);base=int 0;count;
             width=Mlir_memory.element_bytes ast shaped})
         | _ -> raise Unsupported)
    | _ -> raise Unsupported) pre;
  let instantiate iteration =
    let env=Hashtbl.copy env and epoch=ref 0 and accesses=ref [] and paths=ref [] in
    Hashtbl.add env iv (Num {term=A.mk_add ctx [z lo;A.mk_mul ctx [z stride;iteration]];
                            lo;hi=Z.add lo (Z.mul stride (Z.pred trips))});
    let num term lo hi=require (Z.sign lo>=0 && Z.fits_int hi);Num {term;lo;hi} in
    List.iteri (fun index (op:M.operation)->
      let path=[List.length pre;0;0;index] in
      let bind value=match op.results with [id,_]->Hashtbl.add env id value | _->raise Unsupported in
      match op.opcode,List.map (Hashtbl.find env) op.operands with
      | "arith.constant",[] when List.map snd op.results=["index"] -> bind (constant op)
      | ("arith.addi"|"arith.muli" as code),[Num a;Num b] ->
          require (List.map snd op.results=["index"] && Z.sign a.lo>=0 && Z.sign b.lo>=0);
          let f,g=if code="arith.addi" then A.mk_add,Z.add else A.mk_mul,Z.mul in
          bind (num (f ctx [a.term;b.term]) (g a.lo b.lo) (g a.hi b.hi))
      | "arith.remui",[Num a;Num b] ->
          require (List.map snd op.results=["index"] && Z.sign a.lo>=0 && Z.sign b.lo>0);
          bind (num (A.Integer.mk_mod ctx a.term b.term) Z.zero (Z.pred b.hi))
      | "arith.cmpi",[Num a;Num b] when L.attribute op "predicate"=`Int 0 ->
          bind (Test (B.mk_eq ctx a.term b.term))
      | "arith.select",[Test test;Buf a;Buf b] ->
          require (a.count=b.count && a.width=b.width);
          bind (Buf {a with bank=B.mk_ite ctx test a.bank b.bank;base=B.mk_ite ctx test a.base b.base})
      | "memref.subview",Buf v::dynamic ->
          (match op.results with
           | [_,ty] ->
               let shaped=Mlir_memory.shaped ast ty in
               require (List.length shaped.shape=1 && Mlir_memory.element_bytes ast shaped=v.width)
           | _ -> raise Unsupported);
          let offsets,sizes,strides=L.slice_attributes op in
          (match offsets,sizes,strides,dynamic with
           | [off],[size],[stride],args when Z.equal stride Z.one && Z.fits_int size && Z.sign size>=0 ->
               let n=match args with [Num n] when Z.equal off (Z.of_int64 Int64.min_int)->n
                 | [] when Z.sign off>=0->{term=z off;lo=off;hi=off} | _->raise Unsupported in
               require (Z.sign n.lo>=0 && Z.leq (Z.add n.hi size) (Z.of_int v.count));
               bind (Buf {v with count=Z.to_int size;base=A.mk_add ctx [v.base;A.mk_mul ctx [int v.width;n.term]]})
           | _->raise Unsupported)
      | ("memref.copy"|"linalg.copy"|"linalg.elemwise_unary"|"hivm.hir.load"|"hivm.hir.store"|"hivm.hir.vabs"),[Buf read;Buf write]
        when op.results=[] && (String.starts_with ~prefix:"hivm." op.opcode)<>hfusion ->
          require (read.count=write.count && (op.regions=[] ||
            (match op.opcode,op.regions with
             | "linalg.copy",[[{arguments=(src,_)::_;body=[{opcode="linalg.yield";operands=[v];_}]}]] -> src=v
             | _ -> false)));
          accesses:={read;write;epoch= !epoch;path}::!accesses;paths:=(path,op.opcode)::!paths
      | "hfusion.barrier",[] when hfusion -> incr epoch;paths:=(path,op.opcode)::!paths
      | "scf.yield",[] -> ()
      | _->raise Unsupported) body;
    !accesses,!epoch,List.rev !paths in
  let i=A.Integer.mk_const_s ctx "i" and j=A.Integer.mk_const_s ctx "j" in
  let left,barriers,paths=instantiate i and right,_,_=instantiate j in
  let overlap a b =
    let stop v=A.mk_add ctx [v.base;z Z.(mul (of_int v.count) (of_int v.width))] in
    B.mk_and ctx [B.mk_val ctx (a.count>0 && b.count>0);B.mk_eq ctx a.bank b.bank;
                  A.mk_lt ctx a.base (stop b);A.mk_lt ctx b.base (stop a)] in
  let epoch iter site=A.mk_add ctx [A.mk_mul ctx [int barriers;iter];int site.epoch] in
  let pairs=List.concat_map (fun a->List.map (fun b->
    B.mk_and ctx [B.mk_eq ctx (epoch i a) (epoch j b);
      (if a.path=b.path then B.mk_not ctx (B.mk_eq ctx i j) else B.mk_true ctx);
      B.mk_or ctx [overlap a.write b.read;overlap a.write b.write;overlap a.read b.write]]) right) left in
  let solver=Race_solve.new_solver ~timeout_ms ctx in
  Z3.Solver.add solver [A.mk_le ctx (int 0) i;A.mk_le ctx (int 0) j;B.mk_or ctx pairs];
  let sat k=match Z3.Solver.check solver [A.mk_lt ctx i (int k);A.mk_lt ctx j (int k)] with
    | SATISFIABLE->true | UNSATISFIABLE->false | UNKNOWN->raise (Unresolved (Z3.Solver.get_reason_unknown solver)) in
  let rec minimum lo hi=if lo=hi then lo else let mid=lo+(hi-lo)/2 in
    if sat mid then minimum lo mid else minimum (mid+1) hi in
  {rounds;paths;minimum=(if sat rounds then Some (minimum 1 rounds) else None)}
