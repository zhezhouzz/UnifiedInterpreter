open Stdlib
open Unified_interpreter
module C = Core_lang
module M = Hivm_module

type element = Integer of int | F16 | BF16 | F32 | F64 | Descriptor
type storage = {name:string; mutable data:bytes; descriptors:(int, view) Hashtbl.t}
and view = {storage:storage; element:element; origin:int; base:int; shape:int array; strides:int array}
type t = Scalar of C.value | Buffer of view | Lanes of C.value array

let element ast name = match Mlir_memory.type_of ast name with
  | M.Integer n -> Integer n
  | M.Float 16 -> if name="bf16" then BF16 else F16
  | M.Float 32 -> F32 | M.Float 64 -> F64
  | M.Shaped {kind=Memref;_} -> Descriptor
  | _ -> invalid_arg ("invalid memory element "^name)
let width = function Integer n -> max 1 ((n+7)/8) | F16|BF16 -> 2 | F32 -> 4 | F64|Descriptor -> 8
let storage name n = {name;data=Bytes.make n '\000';descriptors=Hashtbl.create 0}
let size shape = Array.fold_left Device_value.times 1 shape
let create element dims =
  let shape=Array.of_list dims in
  {storage=storage "allocation" (Device_value.times (size shape) (width element));
   element;origin=0;base=0;shape;strides=Device_value.contiguous shape}
let buffer = function Buffer b -> b | _ -> invalid_arg "expected shaped value"
let scalar = function Scalar s -> s | _ -> invalid_arg "expected scalar"
let z v = Mlir_memory.integer (scalar v)
let number v = Z.to_int (z v)
let int n = Scalar (C.VInt (Z.of_int n))
let real = function C.VFloat x -> x | v -> Z.to_float (Mlir_memory.integer v)
let float_bits elem x = match elem with
  | F16 -> Device_value.half_bits x
  | BF16 ->
      let n=Int32.bits_of_float x in
      Int64.of_int32 (Int32.shift_right_logical
        (Int32.add n (Int32.add 0x7fffl (Int32.logand 1l (Int32.shift_right_logical n 16)))) 16)
  | F32 -> Int64.of_int32 (Int32.bits_of_float x)
  | F64 -> Int64.bits_of_float x
  | _ -> invalid_arg "expected floating element"
let from_bits elem n = match elem with
  | F16 -> C.VFloat (Device_value.half_float (Int64.to_int n))
  | BF16 -> VFloat (Int32.float_of_bits (Int32.shift_left (Int64.to_int32 n) 16))
  | F32 -> VFloat (Int32.float_of_bits (Int64.to_int32 n))
  | F64 -> VFloat (Int64.float_of_bits n)
  | Integer bits -> Mlir_scalar.int bits (Z.of_int64 n)
  | Descriptor -> invalid_arg "expected numeric element"
let bits elem s = match elem,s with
  | Integer n,_ -> Z.to_int64 (Z.signed_extract (Mlir_memory.integer s) 0 (min n 64))
  | _,C.VFloat x -> float_bits elem x
  | _ -> invalid_arg "invalid stored value"
exception Memory_fault of string
exception Out_of_bounds of string
let address b offset =
  let pos=b.base+offset*width b.element in
  if pos<0 || pos>Bytes.length b.storage.data-width b.element then
    raise (Out_of_bounds (Printf.sprintf "%s byte %d outside %d bytes" b.storage.name pos (Bytes.length b.storage.data)));
  pos
let position b indices =
  let rank=Array.length b.shape in
  let rec walk axis offset = function
    | [] when axis=rank -> offset
    | i::tail when axis<rank ->
        let n=b.shape.(axis) in
        if i<0 || i>=n then raise (Out_of_bounds (Printf.sprintf "%s index %d outside dimension %d" b.storage.name i n));
        walk (axis+1) (offset+i*b.strides.(axis)) tail
    | _->invalid_arg "index rank mismatch" in
  walk 0 0 indices
let read b offset =
  let pos=address b offset and data=b.storage.data in
  match b.element with
  | Descriptor -> (match Hashtbl.find_opt b.storage.descriptors pos with
      | Some v -> Buffer v | None -> raise (Memory_fault ("uninitialized descriptor in "^b.storage.name)))
  | Integer bits when width b.element>8 ->
      Scalar (Mlir_scalar.int bits (Z.of_bits (Bytes.sub_string data pos (width b.element))))
  | elem ->
    let n=match width elem with
      | 1 -> Int64.of_int (Bytes.get_uint8 data pos) | 2 -> Int64.of_int (Bytes.get_uint16_le data pos)
      | 4 -> Int64.of_int32 (Bytes.get_int32_le data pos) | 8 -> Bytes.get_int64_le data pos
      | _ -> invalid_arg "unsupported integer storage width" in
    Scalar (from_bits elem n)
let write b offset value =
  let pos=address b offset and data=b.storage.data in
  match b.element,value with
  | Descriptor,Buffer v -> Hashtbl.replace b.storage.descriptors pos v
  | Integer bits,Scalar s when width b.element>8 ->
      let raw=Z.to_bits (Z.extract (Mlir_memory.integer s) 0 bits) in
      let n=width b.element in
      Bytes.fill data pos n '\000';
      Bytes.blit_string raw 0 data pos (min n (String.length raw))
  | elem,Scalar s ->
    let n=bits elem s in
    (match width elem with
     | 1 -> Bytes.set_uint8 data pos (Int64.to_int n)
     | 2 -> Bytes.set_uint16_le data pos (Int64.to_int n)
     | 4 -> Bytes.set_int32_le data pos (Int64.to_int32 n)
     | 8 -> Bytes.set_int64_le data pos n | _ -> invalid_arg "unsupported integer width")
  | _ -> invalid_arg "memory element mismatch"
let offset b i =
  let rec index d i sum =
    if d<0 then sum else if d=0 then sum+i*b.strides.(0) else
    index (d-1) (i/b.shape.(d)) (sum+(i mod b.shape.(d))*b.strides.(d)) in
  index (Array.length b.shape-1) i 0
let get b i = read b (offset b i)
let put b i x = write b (offset b i) x
let copy src dst =
  if src.shape<>dst.shape || src.element<>dst.element then invalid_arg "copy shape or element mismatch";
  let n=size src.shape in
  if n>0 then
    if src.element<>Descriptor && src.strides=Device_value.contiguous src.shape &&
       dst.strides=Device_value.contiguous dst.shape then (
      ignore (address src (n-1)); ignore (address dst (n-1));
      Bytes.blit src.storage.data (address src 0) dst.storage.data (address dst 0) (n*width src.element))
    else if src.storage==dst.storage then Array.iteri (put dst) (Array.init n (get src))
    else for i=0 to n-1 do put dst i (get src i) done
let clone b = let dst=create b.element (Array.to_list b.shape) in copy b dst; dst
