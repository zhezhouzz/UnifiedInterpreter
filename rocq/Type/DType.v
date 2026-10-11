From Stdlib Require Import String.

(* MLIR integers distinguish signless [iN], signed [siN], and unsigned [uiN].
   Signless is not shorthand for signed: individual operations determine how
   its bits are interpreted. *)
Inductive signedness := Signless | Signed | Unsigned.

Inductive float_format :=
(* IEEE binary16 / FP16: 1 sign bit, 5 exponent bits, and 10 stored fraction
   bits. It has more significand precision than BF16, but a smaller range. *)
| F16
(* Brain floating point 16 / BF16: 1 sign bit, 8 exponent bits, and 7 stored
   fraction bits. Its range is close to FP32, but its precision is lower. *)
| BF16
(* IEEE binary32 / FP32, commonly used as an accumulator format. *)
| F32
(* IEEE binary64 / FP64. Ascend support and cost are target-dependent. *)
| F64.

Inductive dtype :=
(* Target-sized index used by addressing and shape computations. Its concrete
   bit width is supplied by the target configuration, rather than this tag. *)
| DIndex
(* An integer with an explicit bit width and signedness. *)
| DInt (bits : nat) (sign : signedness)
(* A floating-point value in one of the supported formats. *)
| DFloat (format : float_format).

Notation DF16 := (DFloat F16).
Notation DBF16 := (DFloat BF16).
Notation DF32 := (DFloat F32).
Notation DF64 := (DFloat F64).

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

Inductive cast_kind :=
| CastSigned
| CastUnsigned
| Bitcast.

Inductive unsigned_mode :=
| SI2SI
| SI2UI
| UI2SI
| UI2UI.

(* HFusion additionally supports these rounding modes beyond the four basic
   directed IEEE modes above. *)
Inductive extended_round_mode :=
| RoundBasic (mode : round_mode)
| RoundNearestAway
| RoundOdd
| TruncWithOverflow.

Record cast_spec := {
  cast_source : dtype;
  cast_target : dtype;
  cast_kind_value : cast_kind;
  cast_round_mode : extended_round_mode;
  cast_unsigned_mode : unsigned_mode;
  cast_enable_overflow : bool;
  cast_enable_saturate : bool
}.
