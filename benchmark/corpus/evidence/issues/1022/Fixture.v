From Stdlib Require Import List String ZArith.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import Syntax.
Import ListNotations.
Open Scope string_scope.
Local Notation Cmd := (@command unit nat string string unit).
Definition fixed : @shared_program unit nat string string :=
  Run [(Write tt (Dispatch "fill" (Some (Literal (VPipe "PIPE_V")))) (Literal (VMemory (ExternalMemory 256%nat))) (Literal (VInt 5%Z))
    (Write tt (Dispatch "fill" (Some (Literal (VPipe "PIPE_V")))) (Literal (VMemory (ExternalMemory 0%nat))) (Literal (VInt 2%Z))
    (Read tt 0%nat (Dispatch "add" (Some (Literal (VPipe "PIPE_V")))) (Literal (VMemory (ExternalMemory 256%nat)))
    (Return tt []))) : Cmd)].

Definition legacy : @shared_program unit nat string string :=
  Run [(Write tt (Dispatch "fill" (Some (Literal (VPipe "PIPE_V")))) (Literal (VMemory (ExternalMemory 0%nat))) (Literal (VInt 5%Z))
    (Write tt (Dispatch "fill" (Some (Literal (VPipe "PIPE_V")))) (Literal (VMemory (ExternalMemory 0%nat))) (Literal (VInt 2%Z))
    (Read tt 0%nat (Dispatch "add" (Some (Literal (VPipe "PIPE_V")))) (Literal (VMemory (ExternalMemory 0%nat)))
    (Return tt []))) : Cmd)].
