From Stdlib Require Import List String ZArith.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import Syntax.
Import ListNotations.
Open Scope string_scope.
Local Notation Cmd := (@command unit nat string string unit).
Definition fixture : @shared_program unit nat string string :=
  Run [(Read tt 0%nat (Dispatch "vector" (Some (Literal (VPipe "PIPE_V")))) (Literal (VMemory (ExternalMemory 0%nat)))
    (SetFlag tt (Literal (VPipe "PIPE_V")) (Literal (VPipe "PIPE_S")) (Literal (VEvent 0%nat))
    (WaitFlag tt (Literal (VPipe "PIPE_V")) (Literal (VPipe "PIPE_S")) (Literal (VEvent 0%nat))
    (Write tt (Dispatch "scalar" (Some (Literal (VPipe "PIPE_S")))) (Literal (VMemory (ExternalMemory 0%nat))) (Literal (VInt 1%Z))
    (SetFlag tt (Literal (VPipe "PIPE_S")) (Literal (VPipe "PIPE_V")) (Literal (VEvent 0%nat))
    (WaitFlag tt (Literal (VPipe "PIPE_S")) (Literal (VPipe "PIPE_V")) (Literal (VEvent 0%nat))
    (Read tt 1%nat (Dispatch "vector" (Some (Literal (VPipe "PIPE_V")))) (Literal (VMemory (ExternalMemory 0%nat)))
    (Return tt []))))))) : Cmd)].
