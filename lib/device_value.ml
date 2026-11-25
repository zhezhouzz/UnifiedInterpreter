open Device_ast

(* 每个元素保存其位表示；layout 记录相邻有效元素在寄存器中的间距。 *)
type vector = { layout : layout; registers : int; lanes : int64 array }
type bank = Global of int | Unified of location | Cbuf of int | Matrix_a of int | Matrix_b of int | Acc of int
type view = { bank : bank; ty : dtype; bit : int; shape : int array; strides : int array }
type value = Reg of vector | View of view

let reg = function Reg r -> r | View _ -> invalid_arg "expected register"
let view = function View v -> v | Reg _ -> invalid_arg "expected buffer"
let truncate ty x =
  let width = bits ty in
  if width = 64 then x else Int64.logand x (Int64.pred (Int64.shift_left 1L width))
let signed ty x =
  let shift = 64 - bits ty in
  Int64.shift_right (Int64.shift_left x shift) shift
let is_float = function F16 | F32 -> true | _ -> false

let half_float n =
  let sign = if n land 0x8000 = 0 then 1. else -1. in
  let frac = n land 1023 and exp = n lsr 10 land 31 in
  let value = match exp with
    | 0 -> Float.ldexp (float_of_int frac) (-24)
    | 31 -> if frac = 0 then infinity else nan
    | _ -> Float.ldexp (float_of_int (1024 + frac)) (exp - 25) in
  sign *. value

let round_even x =
  let floor = int_of_float x in
  let frac = x -. float_of_int floor in
  if frac > 0.5 || (frac = 0.5 && floor land 1 = 1) then floor + 1 else floor

let half_bits x =
  let sign = if Float.sign_bit x then 0x8000 else 0 in
  let a = abs_float x in
  let magnitude =
    if Float.is_nan a then 0x7e00
    else if a >= 65520. then 0x7c00
    else if a < 0x1p-14 then round_even (Float.ldexp a 24)
    else
      let mantissa, exp = Float.frexp a in
      (exp + 13) * 1024 + round_even (mantissa *. 2048.) in
  Int64.of_int (sign lor magnitude)

let encode ty x = match ty with
  | F16 -> half_bits x
  | F32 -> truncate I32 (Int64.of_int32 (Int32.bits_of_float x))
  | _ -> invalid_arg "expected floating-point type"
let decode ty x = match ty with
  | F16 -> half_float (Int64.to_int x)
  | F32 -> Int32.float_of_bits (Int64.to_int32 x)
  | _ -> invalid_arg "expected floating-point type"
let vec ty lanes = Reg {layout = {element = ty; lane_bits = bits ty}; registers=1; lanes}
let scalar ty n = vec ty [|truncate ty n|]
let single r = match r.lanes with [|n|] -> n | _ -> invalid_arg "expected scalar"
let host_int x =
  let n = Int64.to_int x in
  if Int64.of_int n <> x then invalid_arg "integer outside host indexing range";
  n
let integer v =
  let r = reg v in
  if is_float r.layout.element then invalid_arg "expected integer";
  let n = single r in
  if r.layout.element = I1 then host_int n else host_int (signed r.layout.element n)
let truth v = let r = reg v in
  if r.layout.element <> I1 then invalid_arg "expected predicate";
  single r <> 0L
let common_width rs =
  let n = List.fold_left (fun n r -> max n (Array.length r.lanes)) 1 rs in
  List.iter (fun r -> if Array.length r.lanes <> n && Array.length r.lanes <> 1
    then invalid_arg "incompatible vector widths") rs;
  n
let lane r i = r.lanes.(if Array.length r.lanes = 1 then 0 else i)
let same a b =
  if a.layout.element <> b.layout.element then invalid_arg "incompatible element types";
  a.layout.element
let wider a b = if Array.length a.lanes >= Array.length b.lanes then a else b
let binary op a b =
  let ty = same a b in
  let calc x y =
    if is_float ty then
      let x = decode ty x and y = decode ty y in
      encode ty (match op with Add -> x +. y | Sub -> x -. y | Mul -> x *. y
        | Div -> x /. y | Min -> Float.min x y | Max -> Float.max x y
        | _ -> invalid_arg "invalid floating-point operation")
    else
      let x = signed ty x and y = signed ty y in
      truncate ty (match op with Add -> Int64.add x y | Sub -> Int64.sub x y
        | Mul -> Int64.mul x y | Div -> Int64.div x y | Rem -> Int64.rem x y
        | Min -> Int64.min x y | Max -> Int64.max x y | And -> Int64.logand x y
        | Or -> Int64.logor x y | Xor -> Int64.logxor x y
        | Shr -> Int64.shift_right x (Int64.to_int y)) in
  Reg {(wider a b) with lanes=Array.init (common_width [a;b]) (fun i -> calc (lane a i) (lane b i))}
let compare_lanes op a b =
  let ty = same a b in
  let cmp x y = match op with Eq -> x = y | Ne -> x <> y | Lt -> x < y
    | Le -> x <= y | Ge -> x >= y | Gt -> x > y in
  let shape = wider a b in
  Reg {shape with layout={shape.layout with element=I1};lanes=Array.init (common_width [a;b]) (fun i ->
    let x = lane a i and y = lane b i in
    let yes = if is_float ty then cmp (decode ty x) (decode ty y)
      else cmp (signed ty x) (signed ty y) in if yes then 1L else 0L)}
let cast ty r =
  let src = r.layout.element in
  let convert x =
    if is_float src then
      if is_float ty then encode ty (decode src x)
      else truncate ty (Int64.of_float (decode src x))
    else
      let x = if src = I1 then x else signed src x in
      if is_float ty then encode ty (Int64.to_float x) else truncate ty x in
  vec ty (Array.map convert r.lanes)

let times a b =
  if a < 0 || b < 0 || (b <> 0 && a > max_int / b) then invalid_arg "invalid extent or address";
  a*b
let plus a b =
  if a < 0 || b < 0 || a > max_int-b then invalid_arg "invalid address";
  a+b
let product = Array.fold_left times 1
let contiguous shape =
  let stride = ref 1 in
  let strides = Array.copy shape in
  for i = Array.length shape - 1 downto 0 do
    strides.(i) <- !stride;
    stride := times !stride shape.(i)
  done;
  strides
let index v coords =
  if Array.length coords <> Array.length v.shape then invalid_arg "coordinate rank";
  let offset = ref 0 in
  Array.iteri (fun i x ->
    if x < 0 || x >= v.shape.(i) then invalid_arg "buffer coordinate out of bounds";
    offset := plus !offset (times x v.strides.(i))) coords;
  plus v.bit (times !offset (bits v.ty))
let coords shape linear =
  let remaining = ref linear in
  let result = Array.make (Array.length shape) 0 in
  for i = Array.length shape - 1 downto 0 do
    result.(i) <- !remaining mod shape.(i);
    remaining := !remaining / shape.(i)
  done;
  if !remaining <> 0 then invalid_arg "flat buffer index";
  result
let bank_name = function Global i -> Printf.sprintf "gm%d" i
  | Unified l -> Printf.sprintf "ub%d.%s" l.block (core_name l.core)
  | Cbuf b -> Printf.sprintf "l1.%d" b | Matrix_a b -> Printf.sprintf "l0a.%d" b
  | Matrix_b b -> Printf.sprintf "l0b.%d" b | Acc b -> Printf.sprintf "l0c.%d" b

type memory = (bank, bytes) Hashtbl.t
let storage memory bank = match Hashtbl.find_opt memory bank with
  | Some b -> b | None -> invalid_arg ("missing storage " ^ bank_name bank)
let read_bits memory v addr =
  let b = storage memory v.bank and at = addr / 8 in
  if addr < 0 || (v.ty <> I1 && addr mod 8 <> 0) then invalid_arg "unaligned address";
  let open Bytes in
  match v.ty with
  | I1 -> Int64.of_int ((get_uint8 b at lsr (addr mod 8)) land 1)
  | I8 -> Int64.of_int (get_uint8 b at)
  | I16 | F16 -> Int64.of_int (get_uint16_le b at)
  | I32 | F32 -> truncate I32 (Int64.of_int32 (get_int32_le b at))
  | I64 -> get_int64_le b at
let write_bits memory v addr x =
  let b = storage memory v.bank and at = addr / 8 in
  if addr < 0 || (v.ty <> I1 && addr mod 8 <> 0) then invalid_arg "unaligned address";
  let open Bytes in
  match v.ty with
  | I1 ->
      let mask = 1 lsl (addr mod 8) in
      let old = get_uint8 b at in
      set_uint8 b at (if x = 0L then old land (lnot mask) else old lor mask)
  | I8 -> set_uint8 b at (Int64.to_int x)
  | I16 | F16 -> set_uint16_le b at (Int64.to_int x)
  | I32 | F32 -> set_int32_le b at (Int64.to_int32 x)
  | I64 -> set_int64_le b at x
