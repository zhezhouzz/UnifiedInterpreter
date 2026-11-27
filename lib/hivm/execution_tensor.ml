open Stdlib
open Unified_interpreter
open Execution_value
module M = Hivm_module
module J = Yojson.Safe.Util
let attr = Mlir_lowering.attribute
let enum op key = Mlir_lowering.enum (attr op key)
let dims op key = List.map J.to_int (J.to_list (attr op key))
let axes shape i = Array.to_list (Device_value.coords shape i)
let read_at b ix = read b (position b ix)
let float x = Scalar (C.VFloat x)
let cast element v = match element,scalar v with
  | Integer n,C.VFloat f -> Scalar (Mlir_scalar.int n (Z.of_float f))
  | Integer n,x -> Scalar (Mlir_scalar.int n (Mlir_memory.integer x))
  | (F16|BF16|F32|F64),x -> float (real x)
  | _ -> invalid_arg "non-numeric cast"
let binary kind a b =
  match scalar a,scalar b with
  | C.VFloat x,C.VFloat y -> float (match kind with
      | "add"->x+.y | "mul"->x*.y | "sub"->x-.y | "div"->x/.y
      | "maxf"|"max_signed"->Float.max x y | "minf"|"min_signed"->Float.min x y
      | _ -> invalid_arg ("unsupported floating binary "^kind))
  | _ -> let f=match kind with
      | "add"->Z.add | "mul"->Z.mul | "sub"->Z.sub | "vand"->Z.logand
      | "shrsi"->(fun n k -> Z.shift_right n (Z.to_int k))
      | "max_signed"->Z.max | "min_signed"->Z.min
      | _->invalid_arg ("unsupported integer binary "^kind) in
    Scalar (C.VInt (f (z a) (z b)))

let matmul a b dst ~transpose ~initialize =
  if Array.length a.shape<>2 || Array.length b.shape<>2 || Array.length dst.shape<>2 then
    invalid_arg "matrix operand rank";
  let m=a.shape.(0) and k=a.shape.(1) and n=dst.shape.(1) in
  if dst.shape.(0)<>m || b.shape<>(if transpose then [|n;k|] else [|k;n|]) then invalid_arg "matrix shape mismatch";
  let values view = Array.init (size view.shape) (fun i -> real (scalar (get view i))) in
  let left=values a and right=values b in
  let columns=if transpose then right else Array.init (n*k) (fun i->right.((i mod k)*n+i/k)) in
  let round=match dst.element with F32->(fun f->Int32.float_of_bits (Int32.bits_of_float f))
    | F64->Fun.id | elem->(fun f->real (from_bits elem (float_bits elem f))) in
  for row=0 to m-1 do for col=0 to n-1 do
    let idx=row*n+col in
    let sum=ref (if initialize then 0. else real (scalar (get dst idx))) in
    for j=0 to k-1 do
      sum:=round (!sum+.left.(row*k+j)*.columns.(col*k+j))
    done; put dst idx (float !sum)
  done done

let run op args ~combine =
  let inputs,dest=match List.rev args with d::xs->List.rev xs,buffer d | _->invalid_arg "missing destination" in
  let dst=if op.M.results=[] then dest else match op.opcode with
    | "linalg.matmul" | "linalg.reduce" | "hivm.hir.mmadL1" -> clone dest
    | _ -> create dest.element (Array.to_list dest.shape) in
  let unary f=for i=0 to size dst.shape-1 do put dst i (f i) done in
  let cell i = function Buffer b -> get b i | s -> s in
  let binary_map kind a b=unary (fun i -> binary kind (cell i a) (cell i b)) in
  (match op.opcode,inputs with
   | ("linalg.matmul"|"hivm.hir.matmul"|"hivm.hir.mmadL1"),Buffer a::Buffer b::controls ->
       let initialize=match controls with [] -> op.opcode="hivm.hir.matmul"
         | init::_->Mlir_scalar.boolean (scalar init) in
       matmul a b dst ~transpose:(attr op "b_transpose"<>`Null) ~initialize
   | ("linalg.fill"|"hivm.hir.vbrc"),[Scalar _ as v] -> unary (fun _->v)
   | ("linalg.broadcast"|"hivm.hir.vbrc"),[Buffer b] ->
       let removed=dims op (if op.opcode="linalg.broadcast" then "dimensions" else "broadcast_dims") in
       unary (fun i -> let pos=axes dst.shape i in read_at b
         (if Array.length b.shape=List.length pos then List.mapi (fun j x->if b.shape.(j)=1 then 0 else x) pos
          else List.filteri (fun j _->not(List.mem j removed)) pos))
   | ("linalg.transpose"|"hivm.hir.vtranspose"),[Buffer b] ->
       let permutation=dims op "permutation" in
       unary (fun i -> let coord=Device_value.coords dst.shape i and src=Array.make (Array.length b.shape) 0 in
         List.iteri (fun j axis->src.(axis)<-coord.(j)) permutation; read_at b (Array.to_list src))
   | ("linalg.reduce"|"hivm.hir.vreduce"),[Buffer src] ->
       let hivm=op.opcode="hivm.hir.vreduce" in
       let axes_=dims op (if hivm then "reduce_dims" else "dimensions") in
       let kind=if hivm then String.lowercase_ascii (enum op (if attr op "kind"=`Null then "arith" else "kind")) else "" in
       if hivm then unary (fun _->float (match kind with "sum"->0. | "max"->neg_infinity | _->invalid_arg "unknown reduction"));
       for i=0 to size src.shape-1 do
         let coord=axes src.shape i in
         let target=List.filter_map Fun.id (List.mapi (fun j x->if List.mem j axes_ then
           (if hivm then Some 0 else None) else Some x) coord) in
         let offset=position dst target in
         let v=get src i and old=read dst offset in
         write dst offset (if hivm then binary (if kind="sum" then "add" else "maxf") v old else combine v old)
       done
   | ("linalg.elemwise_binary"|"hfusion.elemwise_binary"),[a;b] -> binary_map (enum op "fun") a b
   | ("hivm.hir.vadd"|"hivm.hir.vsub"|"hivm.hir.vmul"|"hivm.hir.vdiv"|"hivm.hir.vand"
      |"hivm.hir.vshr"|"hivm.hir.vmin"|"hivm.hir.vmax" as code),[a;b] ->
       let kind=match code with "hivm.hir.vand"->"vand"|"hivm.hir.vshr"->"shrsi"
         |"hivm.hir.vmin"->"min_signed"|"hivm.hir.vmax"->"max_signed"
         |_->String.sub code 10 (String.length code-10) in binary_map kind a b
   | ("linalg.elemwise_unary"|"hivm.hir.vexp"|"hivm.hir.vln"|"hivm.hir.vabs"),[a] ->
       let kind=match op.opcode with "hivm.hir.vexp"->"exp"|"hivm.hir.vln"->"log"|"hivm.hir.vabs"->"abs"|_->enum op "fun" in
       unary (fun i->let x=cell i a in match kind,scalar x with
         | "abs",C.VInt v -> Scalar (C.VInt (Z.abs v))
         | _ -> float ((match kind with "abs"->abs_float | "exp"->exp | "log"->log | _->invalid_arg kind) (real (scalar x))))
   | ("hfusion.cast"|"hivm.hir.vcast"),[a] -> unary (fun i->cast dst.element (cell i a))
   | "hfusion.bitcast",[Buffer a] -> unary (fun i->Scalar (from_bits dst.element (bits a.element (scalar (get a i)))))
   | ("hfusion.select"|"hivm.hir.vsel"),[p;a;b] -> unary (fun i->cell i (if number (cell i p)<>0 then a else b))
   | ("hfusion.compare"|"hivm.hir.vcmp"),[a;b] ->
       let kind=enum op (if attr op "compare_fn"<>`Null then "compare_fn" else "cmp_mode") in
       unary (fun i->let x=real (scalar (cell i a)) and y=real (scalar (cell i b)) in
         Scalar (C.VBool ((match String.lowercase_ascii kind with
           | "vge"|"ge"->(>=) | "vne"|"ne"->(<>) | "vlt"|"lt"->(<) | "vle"|"le"->(<=)
           | "veq"|"eq"->(=) | "vgt"|"gt"->(>) | _->invalid_arg kind) x y)))
   | "hfusion.arange",[a;b] -> unary (fun i->int (number a+i*number b))
   | _ -> invalid_arg ("unsupported structured computation "^op.opcode));
  if op.results=[] then [] else [Buffer dst]
