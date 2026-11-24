module Big = Z
module E = Extracted_semantics.Unified_semantics
open E

type cell = Integer of int64 | Floating of float | Undefined

let rec positive_of_big n =
  if Big.equal n Big.one then XH
  else if Big.testbit n 0 then XI (positive_of_big (Big.shift_right n 1))
  else XO (positive_of_big (Big.shift_right n 1))

let z_of_big n =
  let sign = Big.sign n in
  if sign = 0 then Z0
  else if sign > 0 then Zpos (positive_of_big n)
  else Zneg (positive_of_big (Big.neg n))

let rec big_of_positive = function
  | XH -> Big.one
  | XO p -> Big.shift_left (big_of_positive p) 1
  | XI p -> Big.succ (Big.shift_left (big_of_positive p) 1)

let big_of_z = function
  | Z0 -> Big.zero | Zpos p -> big_of_positive p
  | Zneg p -> Big.neg (big_of_positive p)

let z_of_int n = z_of_big (Big.of_int n)
let int_of_z n = Big.to_int (big_of_z n)

let literal = function
  | FiniteFloat q -> Big.to_float (big_of_z q.qnum) /.
      Big.to_float (big_of_positive q.qden)
  | PositiveInfinity -> infinity
  | NegativeInfinity -> neg_infinity
  | NotANumber -> nan

let maxnum a b =
  if Float.is_nan a then b else if Float.is_nan b then a else Float.max a b
let minnum a b =
  if Float.is_nan a then b else if Float.is_nan b then a else Float.min a b
let propagating_max a b =
  if Float.is_nan a || Float.is_nan b then nan else Float.max a b

let is_float = function Float16Type | BFloat16Type | Float32Type -> true | _ -> false

let as_float = function
  | Floating x -> x
  | Undefined -> invalid_arg "read uninitialized tensor element"
  | Integer _ -> invalid_arg "expected floating-point tensor element"

let as_int = function
  | Integer x -> x
  | Undefined -> invalid_arg "read uninitialized tensor element"
  | Floating _ -> invalid_arg "expected integer tensor element"

let width ty = match integer_width ty with
  | Some n -> n | None -> invalid_arg "expected integer element type"

let canonical ty x =
  match width ty with
  | 1 -> Int64.logand x 1L
  | bits ->
      let shift = 64 - bits in
      Int64.shift_right (Int64.shift_left x shift) shift

let normalize ty x =
  if is_float ty then Floating (as_float x) else Integer (canonical ty (as_int x))

let cell_of_z ty x = Integer (canonical ty (Big.to_int64 (big_of_z x)))
let z_of_cell x = z_of_big (Big.of_int64 (as_int x))

let cast source target x =
  let signed x = if width source = 1 && x <> 0L then -1L else x in
  match is_float source, is_float target with
  | true, true -> Ok (Floating (as_float x))
  | false, true -> Ok (Floating (Int64.to_float (signed (as_int x))))
  | false, false when mlir_element_type_eqb source target -> Ok (normalize target x)
  | false, false -> Ok (Integer (canonical target (signed (as_int x))))
  | true, false -> Error ScalarUnsupportedCast

let bitcast source target = match source,target with
  | Float32Type,IntegerType (32,Signless) ->
      fun x -> Integer (Int64.of_int32 (Int32.bits_of_float (as_float x)))
  | IntegerType (32,Signless),Float32Type ->
      fun x -> Floating (Int32.float_of_bits (Int64.to_int32 (as_int x)))
  | _ -> invalid_arg "bitcast requires f32 and i32"

let binary ints floats a b =
  match a,b with
  | Integer a,Integer b -> Integer (ints a b)
  | _ -> Floating (floats (as_float a) (as_float b))

let divide a b =
  match a,b with
  | Integer _,Integer 0L -> Error ScalarDivisionByZero
  | _ -> Ok (binary Int64.div ( /. ) a b)

let scalar : cell scalarOps = {
  scalar_zero = Floating 0.; scalar_one = Floating 1.;
  scalar_of_Z = (fun n -> Floating (Big.to_float (big_of_z n)));
  scalar_add = binary Int64.add ( +. ); scalar_sub = binary Int64.sub ( -. );
  scalar_mul = binary Int64.mul ( *. );
  scalar_div = divide;
  scalar_div_unsigned = (fun _ _ -> Error ScalarUnsupportedCast);
  scalar_max = binary max maxnum; scalar_min = binary min minnum;
  scalar_max_unsigned = binary max maxnum; scalar_min_unsigned = binary min minnum;
  scalar_pow = (fun a b -> Ok (Floating (as_float a ** as_float b)));
  scalar_exp = (fun x -> Ok (Floating (exp (as_float x))));
  scalar_log = (fun x -> Ok (Floating (log (as_float x))));
  scalar_cast = (fun spec -> cast spec.cast_source_element_type spec.cast_result_element_type);
}

let vector_binary op ty a b =
  let result = match op with
    | VAdd -> Ok (scalar.scalar_add a b)
    | VSub -> Ok (scalar.scalar_sub a b)
    | VMul -> Ok (scalar.scalar_mul a b)
    | VDiv -> divide a b
    | VAnd -> Ok (Integer (Int64.logand (as_int a) (as_int b)))
    | VShr ->
        let shift = as_int b in
        if shift < 0L || shift >= Int64.of_int (width ty) then Error ScalarDomainError
        else Ok (Integer (Int64.shift_right (as_int a) (Int64.to_int shift)))
    | VMin -> Ok (binary min Float.min a b)
    | VMax -> Ok (binary max propagating_max a b)
  in
  match result with Ok x -> Ok (normalize ty x) | Error e -> Error e

let hivm : cell numeric = {
  number_literal = (fun _ x -> Ok (Floating (literal x)));
  number_zero = (fun ty -> if is_float ty then Floating 0. else Integer 0L);
  number_binary = vector_binary;
  number_unary = (fun op _ x ->
    match op with VExp -> scalar.scalar_exp x | VLn -> scalar.scalar_log x);
  number_reduce_seed = (fun op _ ->
    Floating (match op with ReduceSum -> 0. | ReduceMax -> neg_infinity));
  number_reduce = (fun op _ a b ->
    Ok (match op with ReduceSum -> scalar.scalar_add a b
      | ReduceMax -> Floating (propagating_max (as_float a) (as_float b))));
  number_cast = (fun _ -> cast);
  number_mac = (fun _ _ a b acc -> Ok (Floating (as_float acc +. (as_float a *. as_float b))));
}
