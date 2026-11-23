From Stdlib Require Import List String ZArith.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import Syntax.
Import ListNotations.
Open Scope string_scope.
Local Notation Cmd := (@command unit nat string string unit).
Definition expected : @shared_program unit nat string string :=
  Run [(CCompute tt 0%nat (Dispatch "unit_load" (Some (Literal (VPipe "PIPE_MTE2")))) []
    (CCompute tt 1%nat (Dispatch "unit_vadd" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 2%nat (Dispatch "unit_store" (Some (Literal (VPipe "PIPE_MTE3")))) []
    (Return tt []))) : Cmd)].

Definition slice_actual : @shared_program unit nat string string :=
  Run [(CCompute tt 0%nat (Dispatch "unit_load" (Some (Literal (VPipe "PIPE_MTE2")))) []
    (CCompute tt 1%nat (Dispatch "unit_vadd" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 2%nat (Dispatch "unit_store" (Some (Literal (VPipe "PIPE_MTE3")))) []
    (Return tt []))) : Cmd)].
