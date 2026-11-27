open Core_lang
open Z3

(** 历史模型中的原语声明用于构造 SMT 表达式，也用于计算具体实例的标量值和读写足迹。 *)
type expr =
  | Arg of int | Const of value
  | Add of expr * expr | Sub of expr * expr | Mul of expr * expr
  | Mod of expr * int | Eq of expr * expr | Lt of expr * expr
  | Select of expr * expr * expr | Event of expr
  | Input_slice of int * expr * expr
  | Subview of expr * expr * expr
  | Remainder of expr * expr

type family = {
  streams : stream list;
  parameter : (int * int) list;
  scalar : int -> int -> expr;
  access : int -> int -> int -> expr list * expr list;
  block_edge : int -> int -> int -> endpoint -> bool;
}

exception Unsupported of string

module Formula = struct
  let num ctx n = Arithmetic.Integer.mk_numeral_s ctx (Z.to_string n)
  let int = Arithmetic.Integer.mk_numeral_i
  let bool = Boolean.mk_val
  let eq = Boolean.mk_eq
  let lt = Arithmetic.mk_lt
  let le = Arithmetic.mk_le
  let and_ ctx = function [] -> bool ctx true | [x] -> x | xs -> Boolean.mk_and ctx xs
  let or_ ctx = function [] -> bool ctx false | [x] -> x | xs -> Boolean.mk_or ctx xs
  let add ctx a b = Arithmetic.mk_add ctx [a; b]
  let mul ctx a b = Arithmetic.mk_mul ctx [a; b]
  let fresh ctx name = Expr.mk_fresh_const ctx name (Arithmetic.Integer.mk_sort ctx)
  let simplify e = Expr.simplify e None
  let quantify quant ctx vars body =
    let body = simplify body in
    if vars = [] || Boolean.is_true body || Boolean.is_false body then body
    else Quantifier.expr_of_quantifier (quant ctx vars body None [] [] None None)
  let exists ctx = quantify Quantifier.mk_exists_const ctx
  let forall ctx = quantify Quantifier.mk_forall_const ctx
end
open Formula

type storage_expr = External of int | Local of int * int list * Expr.expr list
type slice = { guard : Expr.expr; storage : storage_expr; offset : Expr.expr; length : Expr.expr }
type term = Integer of Expr.expr | Boolean of Expr.expr | Flag of Expr.expr | View of slice list
          | Float of float

let integer = function Integer x -> x | _ -> invalid_arg "symbolic integer expected"
let boolean = function Boolean x -> x | _ -> invalid_arg "symbolic boolean expected"
let flag = function Flag x -> x | _ -> invalid_arg "symbolic flag expected"
let view = function View v -> v | _ -> invalid_arg "symbolic view expected"
let slice ctx storage offset length = {guard = bool ctx true; storage; offset; length}

let lift_storage ctx = function
  | Invalid_address -> raise (Unsupported "invalid concrete memory access")
  | Input x -> External x
  | Allocated id -> Local (id.stream, id.site, List.map (int ctx) id.iterations)

let lift ctx = function
  | VInt n -> Integer (num ctx n) | VBool b -> Boolean (bool ctx b)
  | VFloat x -> Float x | VEvent f -> Flag (int ctx f)
  | VBuffer _ | VTensor _ -> raise (Unsupported "strided MLIR buffers require a concrete launch")
  | VMemory_read _ | VDeferred _ | VLanes _ -> raise (Unsupported "memory and vector values require concrete execution")
  | VView xs ->
      (* 相邻地址合并为区间，保持原有视图顺序。 *)
      let rec runs acc = function
        | [] -> View (List.rev acc)
        | (s, start) :: tail ->
            let rec take len = function
              | (s', i) :: rest when s = s' && Z.equal (Z.of_int i) (Z.add (Z.of_int start) (Z.of_int len)) ->
                  take (len + 1) rest
              | rest -> runs (slice ctx (lift_storage ctx s) (int ctx start) (int ctx len) :: acc) rest in
            take 1 tail in
      runs [] xs

let eval ctx args =
  let rec eval = function
    | Arg i -> List.nth args i | Const v -> lift ctx v
    | Add (a,b) -> Integer (add ctx (number a) (number b))
    | Sub (a,b) -> Integer (Arithmetic.mk_sub ctx [number a; number b])
    | Mul (a,b) -> Integer (mul ctx (number a) (number b))
    | Mod (a,m) ->
        if m <= 0 then invalid_arg "symbolic modulo requires a positive divisor";
        Integer (Arithmetic.Integer.mk_mod ctx (number a) (int ctx m))
    | Remainder (a,b) -> Integer (Arithmetic.Integer.mk_rem ctx (number a) (number b))
    | Lt (a,b) -> Boolean (lt ctx (number a) (number b))
    | Eq (a,b) ->
        (match eval a, eval b with
         | Integer x, Integer y | Flag x, Flag y | Boolean x, Boolean y -> Boolean (eq ctx x y)
         | _ -> raise (Unsupported "equality requires integers, flags or booleans"))
    | Event e -> Flag (number e)
    | Input_slice (s,offset,length) -> View [slice ctx (External s) (number offset) (number length)]
    | Subview (base,offset,length) ->
        let start=number offset and length=number length and zero=int ctx 0 in
        let limit=add ctx start length in
        let min a b=Boolean.mk_ite ctx (lt ctx a b) a b and max a b=Boolean.mk_ite ctx (lt ctx a b) b a in
        let sub a b=Arithmetic.mk_sub ctx [a;b] in
        let _,parts=List.fold_left_map (fun cursor s ->
          let stop=add ctx cursor s.length in
          let lo=max cursor start and hi=min stop limit in
          Boolean.mk_ite ctx s.guard stop cursor,
          {s with offset=add ctx s.offset (sub lo cursor);length=max zero (sub hi lo)})
          zero (view (eval base)) in
        View parts
    | Select (cond,a,b) ->
        let g = boolean (eval cond) in
        let ite = Boolean.mk_ite ctx g in
        (match eval a, eval b with
         | Integer x, Integer y -> Integer (ite x y)
         | Flag x, Flag y -> Flag (ite x y)
         | Boolean x, Boolean y -> Boolean (ite x y)
         | View x, View y ->
             let under c = List.map (fun s -> {s with guard = and_ ctx [c; s.guard]}) in
             View (under g x @ under (Boolean.mk_not ctx g) y)
         | _ -> raise (Unsupported "incompatible or unsupported Select branches"))
  and number e = integer (eval e) in
  eval

let eval_access ctx family stream pipe op args =
  let reads, writes = family.access stream pipe op in
  let slices = List.concat_map (fun e -> view (eval ctx args e)) in
  slices reads, slices writes

let numeral e = Arithmetic.Integer.get_big_int (simplify e)
let truth e =
  let v = simplify e in
  if Boolean.is_true v then true else if Boolean.is_false v then false
  else invalid_arg "symbolic condition in concrete execution"

let materialize slices =
  List.concat_map (fun s ->
    if not (truth s.guard) then [] else
    let storage = match s.storage with
      | External k -> Input k
      | Local (stream,site,indices) ->
          Allocated {stream; site; iterations = List.map (fun i -> Z.to_int (numeral i)) indices} in
    let offset = numeral s.offset and length = Z.max Z.zero (numeral s.length) in
    List.init (Z.to_int length) (fun i -> storage, Z.to_int (Z.add offset (Z.of_int i)))
  ) slices

let concrete = function
  | Integer x -> VInt (numeral x) | Flag x -> VEvent (Z.to_int (numeral x))
  | Boolean x -> VBool (truth x) | View v -> VView (materialize v) | Float f -> VFloat f

let bind family stream value =
  List.fold_left (fun env (s,x) ->
    if s = stream.id then (x,value) :: List.remove_assoc x env else env) stream.params family.parameter

let validate family =
  let ids = List.map (fun s -> s.id) family.streams in
  let unique xs = List.length xs = List.length (List.sort_uniq compare xs) in
  if not (unique ids) then invalid_arg "duplicate stream";
  List.iter (fun s -> if not (unique s.pipes) then invalid_arg "duplicate pipe") family.streams;
  List.iter (fun (s,_) -> if not (List.mem s ids) then invalid_arg "unknown parameter stream") family.parameter

let instantiate family n =
  validate family;
  if Z.sign n < 0 then invalid_arg "loop count N must be nonnegative";
  let ctx = mk_context [] in
  { Core_lang.streams = List.map (fun s -> {s with params = bind family s (VInt n)}) family.streams;
    scalar_eval = (fun s op args -> concrete (eval ctx (List.map (lift ctx) args) (family.scalar s op)));
    footprint = (fun s p op args ->
      let reads,writes = eval_access ctx family s p op (List.map (lift ctx) args) in
      {reads = materialize reads; writes = materialize writes});
    block_edge = family.block_edge }
