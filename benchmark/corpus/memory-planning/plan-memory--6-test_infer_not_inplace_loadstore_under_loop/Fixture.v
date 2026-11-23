From Stdlib Require Import List String ZArith.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import Syntax.
Import ListNotations.
Open Scope string_scope.
Local Notation Cmd := (@command unit nat string string unit).
Definition expected : @shared_program unit nat string string :=
  Run [(WaitFlag tt (Literal (VPipe "PIPE_V")) (Literal (VPipe "PIPE_MTE2")) (Literal (VEvent 0%nat))
    (CCompute tt 0%nat (Dispatch "unit_load" (Some (Literal (VPipe "PIPE_MTE2")))) []
    (SetFlag tt (Literal (VPipe "PIPE_MTE2")) (Literal (VPipe "PIPE_V")) (Literal (VEvent 1%nat))
    (WaitFlag tt (Literal (VPipe "PIPE_V")) (Literal (VPipe "PIPE_MTE2")) (Literal (VEvent 1%nat))
    (CCompute tt 1%nat (Dispatch "unit_load" (Some (Literal (VPipe "PIPE_MTE2")))) []
    (SetFlag tt (Literal (VPipe "PIPE_MTE2")) (Literal (VPipe "PIPE_V")) (Literal (VEvent 0%nat))
    (WaitFlag tt (Literal (VPipe "PIPE_MTE2")) (Literal (VPipe "PIPE_V")) (Literal (VEvent 1%nat))
    (Return tt []))))))) : Cmd)].

Definition slice_actual : @shared_program unit nat string string :=
  Run [(WaitFlag tt (Literal (VPipe "PIPE_V")) (Literal (VPipe "PIPE_MTE2")) (Literal (VEvent 0%nat))
    (CCompute tt 0%nat (Dispatch "unit_load" (Some (Literal (VPipe "PIPE_MTE2")))) []
    (SetFlag tt (Literal (VPipe "PIPE_MTE2")) (Literal (VPipe "PIPE_V")) (Literal (VEvent 1%nat))
    (WaitFlag tt (Literal (VPipe "PIPE_V")) (Literal (VPipe "PIPE_MTE2")) (Literal (VEvent 1%nat))
    (CCompute tt 1%nat (Dispatch "unit_load" (Some (Literal (VPipe "PIPE_MTE2")))) []
    (SetFlag tt (Literal (VPipe "PIPE_MTE2")) (Literal (VPipe "PIPE_V")) (Literal (VEvent 0%nat))
    (WaitFlag tt (Literal (VPipe "PIPE_MTE2")) (Literal (VPipe "PIPE_V")) (Literal (VEvent 1%nat))
    (Return tt []))))))) : Cmd)].
