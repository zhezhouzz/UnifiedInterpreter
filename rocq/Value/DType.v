From Stdlib Require Import String.

Inductive signedness := Signed | Unsigned.

Inductive dtype :=
(* Target-sized index used by addressing and shape computations. Its concrete
   bit width is supplied by the target configuration, rather than this tag. *)
| DIndex
(* An integer with an explicit bit width and signedness. *)
| DInt (bits : nat) (sign : signedness)
(* IEEE binary16 / FP16: 1 sign bit, 5 exponent bits, and 10 stored fraction
   bits. It has more significand precision than BF16, but a smaller range. *)
| DF16
(* Brain floating point 16 / BF16: 1 sign bit, 8 exponent bits, and 7 stored
   fraction bits. Its range is close to FP32, but its precision is lower than
   FP16. *)
| DBF16
(* IEEE binary32 / FP32: 1 sign bit, 8 exponent bits, and 23 stored fraction
   bits. It is commonly used as the accumulator format for lower-precision
   matrix operations. *)
| DF32
(* IEEE binary64 / FP64: 1 sign bit, 11 exponent bits, and 52 stored fraction
   bits. Ascend support and cost are target-dependent; the interpreter still
   records the type even when a particular backend cannot execute it. *)
| DF64.

(* These are rounding modes carried by an actual IR cast. Idealized exact
   execution is deliberately not a constructor here: it is an interpreter
   backend policy that may preserve the mathematical value while retaining
   this real rounding-mode annotation for later checking. *)
Inductive round_mode :=
(* Round to the nearest representable value; ties choose an even significand. *)
| RoundNearestEven
(* Discard the non-representable part in the direction of zero. *)
| RoundTowardZero
(* Round toward positive infinity. *)
| RoundUp
(* Round toward negative infinity. *)
| RoundDown.

Record cast_spec := {
  cast_source : dtype;
  cast_target : dtype;
  cast_round_mode : round_mode
}.
