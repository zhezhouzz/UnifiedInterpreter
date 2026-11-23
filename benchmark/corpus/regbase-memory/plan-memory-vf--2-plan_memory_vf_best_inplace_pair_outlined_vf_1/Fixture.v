From Stdlib Require Import List String ZArith.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import Syntax.
Import ListNotations.
Open Scope string_scope.
Local Notation Cmd := (@command unit nat string string unit).
Definition expected : @shared_program unit nat string string :=
  Run [(SetFlag tt (Literal (VPipe "PIPE_V")) (Literal (VPipe "PIPE_S")) (Literal (VEvent 0%nat))
    (WaitFlag tt (Literal (VPipe "PIPE_V")) (Literal (VPipe "PIPE_S")) (Literal (VEvent 0%nat))
    (Return tt [])) : Cmd)].

Definition slice_actual : @shared_program unit nat string string :=
  Run [(SetFlag tt (Literal (VPipe "PIPE_V")) (Literal (VPipe "PIPE_S")) (Literal (VEvent 0%nat))
    (WaitFlag tt (Literal (VPipe "PIPE_V")) (Literal (VPipe "PIPE_S")) (Literal (VEvent 0%nat))
    (Return tt [])) : Cmd)].
