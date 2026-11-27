module Ast = Attention_runtime.Parser
module E = Extracted_semantics.Unified_semantics
module Numeric = Attention_runtime.Numeric
module R = Attention_runtime.Runner
open Ast

type buffer = {
  allocation : string; elements : int; initialized : bool;
  offset : int; shape : int list; strides : int list;
}
type argument = Buffer of buffer | Integer of int | Parameter | Float of float
type launch = (string * argument) list list
type event = { stream : int; entry : string; path : int list; opcode : string;
               iterations : int list }
type race = { first : event; second : event; forward : event list; reverse : event list }
type status = Complete | Race | Full_race of int | No_race | Unknown of string
type report = { entry : string; launch : launch; n : Z.t option; status : status; races : race list }

let rec resolve (program : program) = function
  | [] -> invalid_arg "empty HFusion AST path"
  | i :: rest ->
      let op = List.nth program.body i in
      if rest = [] then op else resolve {program with body=op.region} rest

type expr = Lit of Z.t | N | Iv of int | Binary of E.arith_binary_operator * E.mlir_type * expr * expr
exception Invalid_iteration
let lit n = Lit (Z.of_int n)
let eval_binary op ty a b =
  match E.sem_integer_binary op ty (Numeric.z_of_big a) (Numeric.z_of_big b) with
  | E.Ok z -> Numeric.big_of_z z | E.Error _ -> raise Invalid_iteration
let rec eval n ivs = function
  | Lit z -> z | N -> n | Iv i -> List.nth ivs i
  | Binary (op,ty,x,y) -> eval_binary op ty (eval n ivs x) (eval n ivs y)
let width ty = match E.integer_width ty with
  | Some w -> w | None -> invalid_arg "unsupported HFusion integer type"
let canonical ty z = Numeric.big_of_z (E.canonical_integer (width ty) (Numeric.z_of_big z))

(* 闭区间使用物理元素下标。同一分配只有一种元素类型。 *)
type interval = Z.t * Z.t
let normalize ranges =
  List.fold_left (fun acc (lo,hi) -> match acc with
    | (a,b)::rest when Z.leq lo (Z.succ b) -> (a,Z.max hi b)::rest
    | _ -> (lo,hi)::acc) [] (List.sort compare ranges) |> List.rev
let layout shape strides =
  let extend size stride ranges =
    if size < 0 then invalid_arg "HFusion needs a concrete descriptor shape";
    let stride = Z.of_int stride in
    match ranges with
    | [] -> []
    | _ when size=0 -> []
    | [a,b] when Z.leq (Z.abs stride) (Z.succ (Z.sub b a)) ->
        let last = Z.mul (Z.of_int (size-1)) stride in
        [Z.add a (Z.min Z.zero last),Z.add b (Z.max Z.zero last)]
    | _ -> List.init size (fun i ->
        let d=Z.mul (Z.of_int i) stride in
        List.map (fun (a,b) -> Z.add d a,Z.add d b) ranges) |> List.concat |> normalize in
  List.fold_right2 extend shape strides [Z.zero,Z.zero]
let row_major shape =
  List.fold_right (fun dim (size,strides) ->
    Z.mul size (Z.of_int dim), Z.to_int size::strides) shape (Z.one,[])
let rec overlaps left right = match left,right with
  | [],_ | _,[] -> false
  | (a,b)::xs,(c,d)::ys ->
      if Z.lt b c then overlaps xs right else if Z.lt d a then overlaps left ys else true
let translate delta = List.map (fun (a,b) -> Z.add delta a,Z.add delta b)

type storage = External of string | Local of int * int list * int
type view = { storage : storage; capacity : Z.t; initial : bool; base : expr;
              dims : int list; cells : interval list }
type value = Scalar of expr | Floating | Mem of view | Alias of view | Tensor | Empty
type loop = { lo : expr; hi : expr; step : expr; ty : E.mlir_type }
type access = { stream : int; path : int list; opcode : string; loops : loop list;
                reads : view list; writes : view list; claims : view list }
type statement = For of loop * statement list | Access of access | Check of view
               | Disjoint of view * view | Evaluate of expr | Stop
type model = { program : program; launch : launch; streams : statement list list;
               sites : access list; parameter_max : Z.t option }

let compile (program : program) launch =
  Attention_runtime.Validate.kernel ~stage:"hfusion" program;
  let sites = ref [] and parameter_max = ref None and buffers = Hashtbl.create 12 in
  let stream pid bindings =
    if List.sort compare (List.map fst bindings) <> List.sort compare (List.map fst program.arguments)
    then invalid_arg "HFusion launch bindings must match all function arguments";
    let env = List.map (fun (name,ty) ->
      let value = match ty,List.assoc name bindings with
      | ShapedType ("memref",decl,element),Buffer b ->
          if b.elements < 0 || List.length decl <> List.length b.shape ||
             not (List.for_all2 (fun a n -> n>=0 && (a= -1 || a=n)) decl b.shape) ||
             List.length b.shape <> List.length b.strides then invalid_arg ("invalid descriptor "^name);
          let metadata = element,b.elements,b.initialized in
          (match Hashtbl.find_opt buffers b.allocation with
           | Some other when other<>metadata -> invalid_arg ("inconsistent allocation "^b.allocation)
           | _ -> Hashtbl.replace buffers b.allocation metadata);
          let cells=layout b.shape b.strides in
          if List.exists (fun (a,z) -> Z.sign a<0 || Z.geq z (Z.of_int b.elements))
            (translate (Z.of_int b.offset) cells) then invalid_arg ("out of bounds argument "^name);
          Mem {storage=External b.allocation; capacity=Z.of_int b.elements;initial=b.initialized;
               base=lit b.offset;dims=b.shape;cells}
      | ScalarType (E.Float32Type | E.Float16Type),Float _ -> Floating
      | ScalarType ty,Integer n when Z.equal (canonical ty (Z.of_int n)) (Z.of_int n) -> Scalar (lit n)
      | ScalarType ty,Parameter ->
          let w=width ty in
          let max_n=if w=1 then Z.one else Z.pred (Z.shift_left Z.one (w-1)) in
          parameter_max:=Some (Z.min max_n (Option.value !parameter_max ~default:max_n));
          Scalar N
      | _ -> invalid_arg ("invalid HFusion argument "^name) in name,value) program.arguments in
    let rec block env parent loops ops =
      let body = ref [] in
      let emit s = body:=s::!body in
      let operation env index (op : operation) =
        let path=parent@[index] in
        let fail message = Attention_runtime.Source.fail op.span message in
        let get name=List.assoc name env in
        let mem = function Mem v -> v | _ -> fail "expected memref" in
        let scalar = function Scalar e -> e | _ -> fail "expected integer" in
        let materialize = List.filter_map (function Alias v -> Some v | _ -> None) in
        let access reads writes claims =
          if reads<>[] || writes<>[] || claims<>[] then begin
            let a={stream=pid;path;opcode=op.opcode;loops;reads;writes;claims} in
            sites:=a::!sites;emit (Access a)
          end in
        let values=List.map get op.operands in
        let result = match op.opcode,values with
        | "scf.for",[a;b;c] ->
            let iv,t=List.hd op.region_arguments in
            let ty=match t with ScalarType ty -> ty | _ -> fail "expected integer loop variable" in
            let loop={lo=scalar a;hi=scalar b;step=scalar c;ty} in
            emit (For (loop,block ((iv,Scalar (Iv (List.length loops)))::env) path (loops@[loop]) op.region));None
        | "arith.constant",[] ->
            (match R.attribute op "value" with
             | `Int i -> Some (Scalar (Lit (canonical (R.trailing_scalar op) (Z.of_int i))))
             | `String _ when R.trailing_scalar op=E.Float32Type -> Some Floating
             | _ -> fail "invalid arith.constant")
        | ("arith.addi"|"arith.muli"|"arith.divsi"|"arith.remsi"),[a;b] ->
            let operator=match op.opcode with "arith.addi" -> E.ArithAddI | "arith.muli" -> E.ArithMulI
              | "arith.divsi" -> E.ArithDivSI | _ -> E.ArithRemSI in
            let x=Binary (operator,R.trailing_scalar op,scalar a,scalar b) in
            emit (Evaluate x);Some (Scalar x)
        | ("arith.index_cast"|"arith.extsi"),[Scalar x] ->
            let source=match op.operand_types with [ScalarType ty] -> ty | _ -> fail "invalid cast" in
            let operator=if op.opcode="arith.index_cast" then E.ArithIndexCast else E.ArithExtSI in
            (match E.sem_integer_cast operator source (R.trailing_scalar op) E.Z0 with
             | E.Error _ -> fail "unsupported integer cast" | E.Ok _ -> Some (Scalar x))
        | "memref.alloc",[] ->
            let dims,_=R.last_type op in
            let capacity,strides=row_major dims in
            Some (Mem {storage=Local(pid,path,List.length loops);capacity;initial=false;base=lit 0;
                       dims;cells=layout dims strides})
        | "memref.reinterpret_cast",src::_ ->
            let v=mem src and dims=R.dims "sizes" op in
            let base=match R.attribute op "offsets" with
              | `List [`String s] when String.starts_with ~prefix:"%" s -> scalar (get s)
              | `List [`String s] -> Lit (Z.of_string s) | _ -> fail "invalid reinterpret offset" in
            let v={v with base;dims;cells=layout dims (R.dims "strides" op)} in
            emit (Check v);Some (Mem v)
        | "memref.copy",[Mem a;Mem b] ->
            if a.dims<>b.dims then fail "copy shape mismatch";
            emit (Disjoint (a,b));access [a] [b] [];None
        | "bufferization.to_tensor",[Mem v] ->
            let dims,_=R.last_type op in
            if List.length dims<>List.length v.dims ||
               not (List.for_all2 (fun d size -> d= -1 || d=size) dims v.dims) then emit Stop;
            if R.flag "restrict" op then access [] [] [v];Some (Alias v)
        | "bufferization.materialize_in_destination",[src;Mem dst] ->
            let shape=match src,op.operand_types with Alias v,_ -> v.dims
              | _,ShapedType ("tensor",sh,_)::_ -> sh
              | _ -> fail "expected tensor source" in
            if not (R.flag "writable" op) || src=Empty || dst.dims<>shape then emit Stop;
            access (materialize [src]) [dst] [];None
        | "tensor.empty",[] ->
            let shape,ty=R.last_type op in
            (match E.sem_empty shape ty with E.Ok _ -> () | E.Error _ -> emit Stop);
            Some Empty
        | ("tensor.expand_shape"|"tensor.collapse_shape"),[v] ->
            access (materialize [v]) [] [];Some (if v=Empty then Empty else Tensor)
        | "func.return",[] | "scf.yield",[] | "linalg.yield",[Floating] -> None
        | ("arith.addf"|"arith.maxnumf"),[Floating;Floating] -> Some Floating
        | _,_ when op.stage=Attention_runtime.Stage.HFusion && op.outputs<>[] ->
            let inputs=List.map get op.inputs and outs=List.map get op.outputs in
            if List.mem Empty inputs ||
               (List.mem op.opcode ["linalg.matmul";"linalg.reduce"] && List.mem Empty outs)
            then emit Stop;
            if op.opcode="linalg.reduce" then begin
              List.iter (fun (child : operation) ->
                if child.opcode<>"linalg.yield" && not (String.starts_with ~prefix:"arith." child.opcode)
                then fail "HFusion scheduler requires a scalar arithmetic reduction region") op.region;
              let locals=List.map (fun (name,_) -> name,Floating) op.region_arguments in
              List.iter emit (block (locals@env) path loops op.region)
            end;
            access (materialize (inputs@outs)) [] [];Some Tensor
        | _ -> fail ("unsupported HFusion scheduler operation "^op.opcode) in
        match op.result,result with Some name,Some x -> (name,x)::env | None,None -> env
        | _ -> fail "result count mismatch" in
      ignore (List.fold_left (fun (env,i) op -> operation env i op,i+1) (env,0) ops);
      List.rev !body in
    block env [] [] program.body in
  let streams=List.mapi stream launch in
  {program;launch;streams;sites=List.rev !sites;parameter_max= !parameter_max}
