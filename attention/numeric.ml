module Big = Z
module E = Extracted_semantics.Unified_semantics
open E

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

let scalar : float scalarOps = {
  scalar_zero = 0.; scalar_one = 1.;
  scalar_of_Z = (fun n -> Big.to_float (big_of_z n));
  scalar_add = ( +. ); scalar_sub = ( -. ); scalar_mul = ( *. );
  scalar_div = (fun a b -> Ok (a /. b));
  scalar_div_unsigned = (fun _ _ -> Error ScalarUnsupportedCast);
  scalar_max = maxnum; scalar_min = minnum;
  scalar_max_unsigned = maxnum; scalar_min_unsigned = minnum;
  scalar_pow = (fun a b -> Ok (a ** b));
  scalar_exp = (fun x -> Ok (exp x)); scalar_log = (fun x -> Ok (log x));
  scalar_cast = (fun spec x ->
    match spec.cast_source_element_type, spec.cast_result_element_type with
    | (Float16Type | Float32Type), (Float16Type | Float32Type) -> Ok x
    | _ -> Error ScalarUnsupportedCast);
}

let hivm : float numeric = {
  number_literal = (fun _ x -> Ok (literal x));
  number_zero = (fun _ -> 0.);
  number_binary = (fun op _ a b ->
    Ok (match op with VAdd -> a +. b | VSub -> a -. b
      | VMul -> a *. b | VDiv -> a /. b));
  number_unary = (fun op _ x ->
    Ok (match op with VExp -> exp x | VLn -> log x));
  number_reduce_seed = (fun op _ ->
    match op with ReduceSum -> 0. | ReduceMax -> neg_infinity);
  number_reduce = (fun op _ a b ->
    Ok (match op with ReduceSum -> a +. b | ReduceMax -> propagating_max a b));
  number_cast = (fun spec src dst x ->
    if spec.cast_rint && spec.cast_signed &&
       src = Float32Type && dst = Float16Type
    then Ok x else Error ScalarUnsupportedCast);
  number_mac = (fun _ _ a b acc -> Ok (acc +. (a *. b)));
}
