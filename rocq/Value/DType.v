From Stdlib Require Import String.

Inductive signedness := Signed | Unsigned.

Inductive dtype :=
| DIndex
| DInt (bits : nat) (sign : signedness)
| DF16
| DBF16
| DF32
| DF64.

Inductive round_mode :=
| RoundNearestEven
| RoundTowardZero
| RoundUp
| RoundDown
| RoundIdeal.

Record cast_spec := {
  cast_source : dtype;
  cast_target : dtype;
  cast_round_mode : round_mode
}.
