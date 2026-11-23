From Stdlib Require Import List String ZArith.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import Syntax.
Import ListNotations.
Open Scope string_scope.
Local Notation Cmd := (@command unit nat string string unit).
Definition expected : @shared_program unit nat string string :=
  Run [(CCompute tt 0%nat (Dispatch "unit_vabs" (Some (Literal (VPipe "PIPE_V")))) []
    (SetFlag tt (Literal (VPipe "PIPE_V")) (Literal (VPipe "PIPE_MTE2")) (Literal (VEvent 0%nat))
    (CCompute tt 1%nat (Dispatch "unit_load" (Some (Literal (VPipe "PIPE_MTE2")))) []
    (Return tt []))) : Cmd)].

Definition actual : @shared_program unit nat string string :=
  Run [(CCompute tt 0%nat (Dispatch "unit_vabs" (Some (Literal (VPipe "PIPE_V")))) []
    (SetFlag tt (Literal (VPipe "PIPE_V")) (Literal (VPipe "PIPE_MTE2")) (Literal (VEvent 0%nat))
    (CCompute tt 1%nat (Dispatch "unit_load" (Some (Literal (VPipe "PIPE_MTE2")))) []
    (Return tt []))) : Cmd)].

Definition slice_actual : @shared_program unit nat string string :=
  Run [(CCompute tt 0%nat (Dispatch "unit_vabs" (Some (Literal (VPipe "PIPE_V")))) []
    (SetFlag tt (Literal (VPipe "PIPE_V")) (Literal (VPipe "PIPE_MTE2")) (Literal (VEvent 0%nat))
    (CCompute tt 1%nat (Dispatch "unit_load" (Some (Literal (VPipe "PIPE_MTE2")))) []
    (Return tt []))) : Cmd)].

Definition observe_ub_zero : @shared_program unit nat string string :=
  Run [(Read tt 0%nat (Dispatch "unit_vabs" (Some (Literal (VPipe "PIPE_V")))) (Literal (VMemory (ExternalMemory 0%nat)))
    (SetFlag tt (Literal (VPipe "PIPE_V")) (Literal (VPipe "PIPE_MTE2")) (Literal (VEvent 0%nat))
    (Write tt (Dispatch "unit_load" (Some (Literal (VPipe "PIPE_MTE2")))) (Literal (VMemory (ExternalMemory 0%nat))) (Literal (VInt 2%Z))
    (Return tt []))) : Cmd)].
