open Stdlib
open Execution_value
module T = Execution_tensor
let lane v i=match v with Lanes xs->Scalar xs.(i) | Scalar _->v | Buffer _->invalid_arg "expected register"
let active mask i=Mlir_scalar.boolean (scalar (lane mask i))
let round elem x=from_bits elem (bits elem x)
let compute op ~count ~element ~input_type args =
  let code=op.M.opcode and enum=T.enum op in
  let zero=from_bits element 0L in
  let result f=[Lanes (Array.init count (fun i->round element (scalar (f i))))] in
  let masked mask f=result (fun i->if active mask i then f i else Scalar zero) in
  match code,args with
  | "ave.hir.pge",[] ->
      let p=enum "pattern" in
      let n=if p="ALL" then count else int_of_string (String.sub p 2 (String.length p-2)) in
      result (fun i->Scalar (C.VBool (i<n)))
  | ("ave.hir.broadcast"|"ave.hir.scalar_broadcast"),[a;mask] -> masked mask (fun _->a)
  | ("ave.hir.broadcast"|"ave.hir.scalar_broadcast"),[a] -> result (fun _->a)
  | "ave.hir.vci",[a] -> result (fun i->int (number a+(if enum "increase_p"="INCREASE" then i else -i)))
  | "vector.bitcast",[a] -> result (fun i->Scalar (from_bits element (bits input_type (scalar (lane a i)))))
  | "builtin.unrealized_conversion_cast",[Lanes xs] ->
      if count<=Array.length xs then [Lanes (Array.sub xs 0 count)]
      else if count=2*Array.length xs && input_type=BF16 then
        [Lanes (Array.init count (fun i->if i mod 2=0 then xs.(i/2) else zero))]
      else invalid_arg "unsupported register layout conversion"
  | "llvm.bitcast",[Lanes xs] when width element=2*width input_type && Array.length xs=2*count ->
      let shift=8*width input_type in
      result (fun i -> let part j=Int64.logand (Int64.pred (Int64.shift_left 1L shift)) (bits input_type xs.(j)) in
        Scalar (from_bits element (Int64.logor (part (2*i)) (Int64.shift_left (part (2*i+1)) shift))))
  | "ave.hir.vsel",[mask;a;b] -> result (fun i->lane (if active mask i then a else b) i)
  | "ave.hir.vcmp",[a;b;mask] ->
      let cmp=match enum "cmp" with "NE"->(<>) | "GE"->(>=) | "EQ"->(=) | x->invalid_arg x in
      masked mask (fun i->Scalar (C.VBool (cmp (real (scalar (lane a i))) (real (scalar (lane b i))))))
  | "ave.hir.vtruncf",[a;mask] ->
      let src=match a with Lanes xs->Array.length xs | _->invalid_arg "expected vector" in
      let odd=enum "part"="part_odd" in
      result (fun i->let k=if count=src then i else i/2 in
        if active mask k && (count=src || (i mod 2=1)=odd) then lane a k else Scalar zero)
  | "ave.hir.reduction",[a;mask] ->
      let kind=enum "kind" in
      let sum=ref (if kind="max" then neg_infinity else 0.) in
      for i=0 to count-1 do if active mask i then
        let v=real (scalar (lane a i)) in sum:=(match kind with "add"-> !sum+.v | "max"->Float.max !sum v
          | _->invalid_arg "unknown reduction kind") done;
      result (fun i->if i=0 then T.float !sum else Scalar zero)
  | ("ave.hir.vexp"|"ave.hir.vln"),[a;mask] -> masked mask (fun i->T.float
        ((if code="ave.hir.vexp" then exp else log) (real (scalar (lane a i)))))
  | "ave.hir.vor",[a;b;mask] -> masked mask (fun i->Scalar (from_bits element
        (Int64.logor (bits element (scalar (lane a i))) (bits element (scalar (lane b i))))))
  | _,[a;b;mask] ->
      let kind=match code with "ave.hir.vsmaxs"|"ave.hir.vmax"->"max_signed"
        | "ave.hir.vsmins"->"min_signed" | "ave.hir.vadd"|"ave.hir.vadds"->"add"
        | "ave.hir.vmul"|"ave.hir.vmuls"->"mul" | "ave.hir.vand"->"vand"
        | "ave.hir.vsub"->"sub" | "ave.hir.vdiv"->"div" | _->invalid_arg code in
      masked mask (fun i->T.binary kind (lane a i) (lane b i))
  | _->invalid_arg ("unsupported vector arithmetic "^code)

let transfer op args counts =
  match args with Buffer b::rest ->
    let rank=Array.length b.shape in
    let start=position b (List.map number (List.take rank rest)) and args=List.drop rank rest in
    let enum=T.enum op in
    (match op.M.opcode,args with
     | "ave.hir.vload",[] ->
         let mode=enum "pattern" in
         List.mapi (fun j count->Lanes (Array.init count (fun i->scalar (read b (start+
           (match mode with "BRC_B32"->0|"DINTLV_B32"->2*i+j|"NORM"->i|_->invalid_arg mode)))))) counts
     | ("ave.hir.masked_store"|"ave.hir.store_with_stride"),_ ->
         let stride,mask,values=match args with [m;v]->None,m,v | [s;m;v]->Some (number s),m,v
           | _->invalid_arg "invalid vector store" in
         let lanes=match values with Lanes xs->Array.length xs|_->invalid_arg "expected data lanes" in
         let limit=if op.opcode="ave.hir.masked_store" && enum "pattern"="ONEPT_B32" then 1 else lanes in
         for i=0 to limit-1 do if active mask i then
           let block=32/width b.element in
           let index=match stride with None->i | Some s->(i/block)*s+i mod block in
           let v=lane values i in
           let v=if op.opcode="ave.hir.masked_store" && enum "pattern"="PK_B32" then
               Scalar (from_bits b.element (Int64.logand 0xffffL (bits F32 (scalar v)))) else v in
           write b (start+index) v done;[]
     | _->invalid_arg "invalid vector memory operation")
  | _->invalid_arg "expected device buffer"
