From Stdlib Require Import List String ZArith.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import Syntax.
Import ListNotations.
Open Scope string_scope.
Local Notation Cmd := (@command unit nat string string unit).
Definition expected : @shared_program unit nat string string :=
  Run [(CCompute tt 0%nat (Dispatch "unit_vexp" (Some (Literal (VPipe "PIPE_V")))) []
    (Return tt []) : Cmd)].
