open Stdlib
open Unified_interpreter
module C = Core_lang
module M = Hivm_module
module Mem = Mlir_memory
module Scalar = Mlir_scalar
module J = Yojson.Safe.Util

let coordinates shape n =
  snd (List.fold_right (fun d (n,at) -> n/d,n mod d::at) shape (n,[]))

let lanes = function C.VLanes xs -> xs | _ -> invalid_arg "expected vector lanes"
let lane v i = match v with C.VLanes xs -> xs.(i) | value -> value
let dimensions ty = List.map Option.get ty.M.shape
let length shape = List.fold_left ( * ) 1 shape

let compute ~ast ~types ~op =
  let _,ty = List.hd op.M.results in
  let code=op.opcode and attrs=op.decoded in
  let attr key=List.assoc key attrs in
  let vector=Mem.shaped ast ty in
  let shape=dimensions vector in
  let count=length shape in
  let element id = match Mem.type_of ast (Hashtbl.find types id) with
    | M.Shaped t -> t.element | _ -> Hashtbl.find types id in
  let element_type=Mem.type_of ast vector.element in
  let integer_width = function M.Integer n -> n | _ -> invalid_arg "integer vector operation requires integer operands" in
  let input_type=Option.map (fun id -> Mem.type_of ast (element id)) (List.nth_opt op.operands 0) in
  let width ()=integer_width element_type and input_width ()=integer_width (Option.get input_type) in
  let enumerate f = C.VLanes (Array.init count f) in
  let delayed f = enumerate (fun i -> C.VDeferred (lazy (f i))) in
  let value (v : Yojson.Safe.t) = match element_type,v with
    | M.Integer 1,`Bool b -> C.VBool b
    | M.Integer bits,v -> Scalar.int bits (Mlir_launch.z_of_json v)
    | M.Float _,`String x -> C.VFloat (float_of_string x)
    | _ -> invalid_arg "invalid dense vector element" in
  fun args -> match code,args with
  | "arith.constant",[] ->
      let data=Array.of_list (List.map value (J.to_list (attr "value"))) in
      if Array.length data<>count then invalid_arg "dense vector shape differs";
      C.VLanes data
  | "vector.constant_mask",[] ->
      let limits=List.map J.to_int (J.to_list (attr "mask_dim_sizes")) in
      enumerate (fun i -> C.VBool (List.for_all2 (<) (coordinates shape i) limits))
  | "ave.hir.pge",[] ->
      let pat=J.to_string (attr "pattern") in
      let prefix="#ave.pge_pattern<" in
      let pat=String.sub pat (String.length prefix) (String.length pat-String.length prefix-1) in
      let n=if pat="ALL" then count else if String.starts_with ~prefix:"VL" pat then
          int_of_string (String.sub pat 2 (String.length pat-2)) else invalid_arg "unsupported PGE pattern" in
      enumerate (fun i -> C.VBool (i<n))
  | ("vector.broadcast"|"ave.hir.broadcast"|"ave.hir.scalar_broadcast"),[x] -> enumerate (fun _ -> x)
  | ("ave.hir.broadcast"|"ave.hir.scalar_broadcast"),[x;mask] ->
      delayed (fun i -> if Scalar.boolean (lane mask i) then x else value
        (match element_type with M.Float _ -> `String "0" | _ -> `Int 0))
  | "ave.hir.vci",[x] ->
      let step=match attr "increase_p" with `String "#ave.vci_type<INCREASE>" -> 1
        | `String "#ave.vci_type<DECREASE>" -> -1 | _ -> invalid_arg "invalid VCI direction" in
      enumerate (fun i -> Scalar.int (width ()) (Z.add (Mem.integer x) (Z.of_int (step*i))))
  | "arith.cmpi",[a;b] ->
      delayed (fun i -> Scalar.compare (J.to_int (attr "predicate")) (input_width ()) (lane a i) (lane b i))
  | ("arith.select"|"ave.hir.vsel"),[mask;a;b] ->
      delayed (fun i -> lane (if Scalar.boolean (lane mask i) then a else b) i)
  | ("vector.shape_cast"|"builtin.unrealized_conversion_cast"),[x] ->
      delayed (fun i -> lane x i)
  | ("ave.hir.preg.and"|"ave.hir.preg.xor"),[a;b;m] ->
      delayed (fun i -> C.VBool (Scalar.boolean (lane m i) &&
        (let x=Scalar.boolean (lane a i) and y=Scalar.boolean (lane b i) in
         if code="ave.hir.preg.and" then x && y else x<>y)))
  | ("ave.hir.vadds"|"ave.hir.vsub"|"ave.hir.vmul"|"ave.hir.vexp"|"ave.hir.vln"|
     "ave.hir.vdiv"|"ave.hir.vtruncf"|"ave.hir.vand"|"ave.hir.vor"|"ave.hir.vxor"|
     "ave.hir.vsmaxs"|"ave.hir.vsmins"|"ave.hir.reduction"|"ave.hir.vmax"|"ave.hir.vcmp"|
     "ave.hir.vector.layout_cast"|"ave.hir.vector_broadcast"|"vector.multi_reduction"|
     "vector.bitcast"|"llvm.bitcast"|"arith.cmpf"|"arith.maximumf"|"arith.mulf"),_ ->
      delayed (fun _ -> raise (C.Prefix_boundary (code ^ " result controls a memory address or predicate")))
  | code,[x] when List.mem code Scalar.casts ->
      let sign=if List.mem code ["arith.extui";"arith.index_castui"] then Scalar.unsigned else Scalar.signed in
      delayed (fun i -> Scalar.int (width ()) (sign (input_width ()) (Mem.integer (lane x i))))
  | code,[a;b] when List.mem code Scalar.binary_opcodes ->
      delayed (fun i -> Scalar.integer_binary code (width ()) (lane a i) (lane b i))
  | ("ave.hir.vmuls" | "ave.hir.vadd"),[a;b;mask] ->
      delayed (fun i ->
        match element_type with
        | M.Integer n -> if Scalar.boolean (lane mask i) then Scalar.integer_binary
            (if code="ave.hir.vmuls" then "arith.muli" else "arith.addi") n (lane a i) (lane b i)
            else Scalar.int n Z.zero
        | M.Float 32 -> if not (Scalar.boolean (lane mask i)) then C.VFloat 0. else
            (match C.demand (lane a i),C.demand (lane b i) with
             | VFloat x,VFloat y -> C.VFloat (Int32.float_of_bits (Int32.bits_of_float
                 (if code="ave.hir.vmuls" then x*.y else x+.y)))
             | _ -> invalid_arg "expected f32 operands")
        | _ -> invalid_arg "unsupported AVE arithmetic element")
  | _ -> raise (C.Prefix_boundary ("unsupported vector computation " ^ code))

let transfer ?(result_index=0) ~ast ~types ~op ~load_value () =
  let attrs=op.M.decoded in
  let attr key=Option.value (List.assoc_opt key attrs) ~default:`Null in
  let read=op.M.opcode="vector.transfer_read" || op.opcode="ave.hir.vload" in
  let ave=String.starts_with ~prefix:"ave." op.opcode in
  let vector_id,buffer_id=match read,ave,op.operands with
    | true,_,b::_ -> fst (List.hd op.results),b
    | false,true,b::_ -> List.hd (List.rev op.operands),b
    | false,false,v::b::_ -> v,b | _ -> invalid_arg "invalid vector transfer" in
  let ty=Mem.shaped ast (Hashtbl.find types vector_id) and mem=Mem.shaped ast (Hashtbl.find types buffer_id) in
  let shape=dimensions ty and rank=List.length mem.shape in
  let count=length shape and strided=op.opcode="ave.hir.store_with_stride" in
  let read_cell=load_value mem.element in
  fun args ->
  let buffer,components=match read,ave,args with
    | true,_,b::rest | false,true,b::rest | false,false,_::b::rest -> Mem.buffer b,rest
    | _ -> invalid_arg "missing vector memory operand" in
  let base=Array.of_list (List.map Mem.integer (List.take rank components)) in
  let mask,padding=match ave,read,List.drop rank components with
    | true,false,[_;m;_] when strided -> Some m,None
    | true,true,[] | false,false,[] -> None,None
    | true,false,[m;_] | false,false,[m] -> Some m,None
    | false,true,[p] -> None,Some p | false,true,[p;m] -> Some m,Some p
    | _ -> invalid_arg "invalid transfer mask or padding" in
  if ave && mem.element<>"i1" then (
    let start=List.fold_left2 (fun acc ix step -> Z.add acc (Z.mul ix step))
        buffer.offset (Array.to_list base) buffer.strides |> Z.to_int in
    let mode=attr "pattern" in
    let limit=if mode=`String "#ave.store_dist<ONEPT_B32>" then 1
      else if not read then (
        let packing=match attr "functionType" with
          | `String "#ave.func_dist_type<pk>" -> 2 | `String "#ave.func_dist_type<pk4>" -> 4
          | `Null | `String "#ave.func_dist_type<norm>" -> 1
          | _ -> raise (C.Prefix_boundary "unsupported AVE store layout") in
        min count (256/(buffer.element_bytes*packing)))
      else count in
    let stride=if strided then Z.to_int (Mem.integer (List.nth components rank)) else 0 in
    let per_block=32/buffer.element_bytes in
    let cells=Array.make count None and addresses=ref [] in
    for i=0 to limit-1 do
      if Option.fold ~none:true ~some:(fun m -> Scalar.boolean (lane m i)) mask then (
        let offset=if strided then (i/per_block)*stride+i mod per_block else match mode with
          | `String "#ave.load_dist<BRC_B32>" -> 0
          | `String "#ave.load_dist<DINTLV_B32>" -> 2*i+result_index
          | `String ("#ave.load_dist<NORM>"|"#ave.store_dist<ONEPT_B32>"|"#ave.store_dist<NORM_B8>"|
                     "#ave.store_dist<NORM_B16>"|"#ave.store_dist<NORM_B32>"|"#ave.store_dist<PK_B32>") -> i
          | _ -> raise (C.Prefix_boundary "unsupported AVE transfer packing") in
        let at=buffer.base_bytes+(start+offset)*buffer.element_bytes in
        let cell=List.init buffer.element_bytes (fun j -> Option.get buffer.storage,at+j) in
        cells.(i)<-Some cell; addresses:=List.rev_append cell !addresses)
    done;
    List.sort_uniq compare !addresses,(fun () -> C.VLanes (Array.map (function
      | Some cell -> read_cell cell
      | None -> C.VDeferred (lazy (raise (C.Prefix_boundary "unavailable AVE read lane")))) cells)))
  else
  let axes,limit = if ave then
      let repeated,limit=match attr "pattern" with
        | `String "#ave.load_dist<BRC_B32>" -> true,count
        | `String "#ave.store_dist<ONEPT_B32>" -> true,1
        | `String ("#ave.load_dist<NORM>"|"#ave.store_dist<NORM_B32>"|"#ave.store_dist<NORM_B16>") -> false,count
        | _ -> raise (C.Prefix_boundary "unsupported AVE transfer packing") in
      (if repeated then [None] else [Some (rank-1)]),limit
    else List.map (function `List [`String "d";`Int d] -> Some d | `Int 0 -> None
                     | _ -> invalid_arg "unsupported vector transfer permutation")
           (J.to_list (J.member "results" (attr "permutation_map"))),count in
  let cells=Array.make count None and addresses=ref [] in
  let packed=Hashtbl.create 16 in
  for i=0 to limit-1 do
    if Option.fold ~none:true ~some:(fun m -> Scalar.boolean (lane m i)) mask then (
      let at=Array.copy base in
      List.iter2 (fun d off -> Option.iter (fun d -> at.(d)<-Z.add at.(d) (Z.of_int off)) d)
        axes (coordinates shape i);
      let at=Array.to_list at in
      if List.for_all2 (fun n size -> Z.sign n>=0 && Z.lt n (Z.of_int size)) at buffer.shape then (
        let view=Mem.at buffer at in
        let cell=if mem.element="i1" then (
            let bit=Z.to_int view.offset in
            let addr=Option.get view.storage,view.base_bytes+bit/8 in
            Hashtbl.replace packed addr (Option.value (Hashtbl.find_opt packed addr) ~default:0 lor (1 lsl (bit mod 8)));
            [addr]) else Mem.addresses view in
        addresses:=List.rev_append cell !addresses;
        cells.(i)<-Some (fun () -> if mem.element="i1" then
            C.VDeferred (lazy (raise (C.Prefix_boundary "packed predicate data controls scheduling")))
          else read_cell cell))
      else if ave then raise (C.Prefix_boundary "vector register extends beyond the declared device view"))
  done;
  if Hashtbl.fold (fun _ mask partial -> partial || mask<>255) packed false then
    raise (C.Prefix_boundary "partial-byte predicate access requires bit addresses");
  let result ()=C.VLanes (Array.map (function Some f -> f ()
      | None -> Option.get padding) cells) in
  List.sort_uniq compare !addresses,result
