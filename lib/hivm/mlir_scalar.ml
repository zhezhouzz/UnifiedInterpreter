open Stdlib
open Unified_interpreter.Core_lang
module Mem = Mlir_memory

let boolean = function
  | VBool b -> b | VInt n when Z.equal n Z.zero || Z.equal n Z.one -> Z.equal n Z.one
  | _ -> invalid_arg "expected an i1 condition"

let number = Mem.integer
let signed bits n = Z.signed_extract n 0 bits
let unsigned bits n = Z.extract n 0 bits
let int bits value = if bits=1 then VBool (Z.testbit value 0) else VInt (signed bits value)

let compare predicate bits left right =
  let signed = signed bits and unsigned = unsigned bits in
  let a = number left and b = number right in
  let order f predicate = predicate (Z.compare (f a) (f b)) 0 in
  VBool (match predicate with
    | 0 -> Z.equal (unsigned a) (unsigned b) | 1 -> not (Z.equal (unsigned a) (unsigned b))
    | 2 -> order signed (<) | 3 -> order signed (<=) | 4 -> order signed (>) | 5 -> order signed (>=)
    | 6 -> order unsigned (<) | 7 -> order unsigned (<=) | 8 -> order unsigned (>) | 9 -> order unsigned (>=)
    | _ -> invalid_arg "unsupported arith.cmpi predicate")

let integer_binary opcode bits a b =
  let a = number a and b = number b in
  let division sign fn =
    let left = sign bits a and right = sign bits b in
    if Z.equal right Z.zero then invalid_arg "division by zero";
    fn left right in
  let shift fn =
    if Z.sign b<0 || Z.geq b (Z.of_int bits) then invalid_arg "shift out of range";
    fn a (Z.to_int b) in
  int bits (match opcode with
    | "arith.addi" -> Z.add a b | "arith.subi" -> Z.sub a b | "arith.muli" -> Z.mul a b
    | "arith.divsi" -> division signed (fun n d ->
        if Z.equal n (Z.neg (Z.shift_left Z.one (bits-1))) && Z.equal d Z.minus_one then
          invalid_arg "signed division overflow";
        Z.div n d)
    | "arith.divui" -> division unsigned Z.div
    | "arith.remsi" -> division signed Z.rem | "arith.remui" -> division unsigned Z.rem
    | "arith.andi" -> Z.logand a b | "arith.ori" -> Z.logor a b | "arith.xori" -> Z.logxor a b
    | "arith.shli" -> shift Z.shift_left | "arith.shrsi" -> shift Z.shift_right
    | "arith.shrui" -> shift (fun a b -> Z.shift_right (unsigned bits a) b)
    | "arith.minsi" -> Z.min a b | "arith.maxsi" -> Z.max a b
    | "arith.minui" -> Z.min (unsigned bits a) (unsigned bits b)
    | "arith.maxui" -> Z.max (unsigned bits a) (unsigned bits b)
    | _ -> invalid_arg ("unsupported integer operation " ^ opcode))

let binary_opcodes = ["arith.addi";"arith.subi";"arith.muli";"arith.divsi";"arith.divui";
  "arith.remsi";"arith.remui";"arith.andi";"arith.ori";"arith.xori";
  "arith.shli";"arith.shrsi";"arith.shrui";"arith.minsi";"arith.maxsi";"arith.minui";"arith.maxui"]

let casts = ["arith.index_cast";"arith.index_castui";"arith.extsi";"arith.extui";"arith.trunci"]
