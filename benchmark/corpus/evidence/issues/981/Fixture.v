From Stdlib Require Import List String ZArith.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import Syntax.
Import ListNotations.
Open Scope string_scope.
Local Notation Cmd := (@command unit nat string string unit).
Definition after_0 : @shared_program unit nat string string :=
  Run [(Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 2%nat))) (Literal (VInt 0%Z))
    (Read tt 0%nat (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 0%nat)))
    (Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 1%nat))) (OVar 0%nat)
    (Return tt []))) : Cmd)].

Definition after_127 : @shared_program unit nat string string :=
  Run [(Read tt 0%nat (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 0%nat)))
    (Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 1%nat))) (OVar 0%nat)
    (Return tt [])) : Cmd)].

Definition after_63 : @shared_program unit nat string string :=
  Run [(Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 2%nat))) (Literal (VInt 0%Z))
    (Read tt 0%nat (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 0%nat)))
    (Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 1%nat))) (OVar 0%nat)
    (Return tt []))) : Cmd)].

Definition after_64 : @shared_program unit nat string string :=
  Run [(Read tt 0%nat (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 0%nat)))
    (Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 1%nat))) (OVar 0%nat)
    (Return tt [])) : Cmd)].

Definition before_0 : @shared_program unit nat string string :=
  Run [(Read tt 0%nat (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 0%nat)))
    (Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 2%nat))) (OVar 0%nat)
    (Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 2%nat))) (Literal (VInt 0%Z))
    (Read tt 1%nat (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 2%nat)))
    (Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 1%nat))) (OVar 1%nat)
    (Return tt []))))) : Cmd)].

Definition before_127 : @shared_program unit nat string string :=
  Run [(Read tt 0%nat (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 0%nat)))
    (Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 2%nat))) (OVar 0%nat)
    (Read tt 1%nat (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 2%nat)))
    (Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 1%nat))) (OVar 1%nat)
    (Return tt [])))) : Cmd)].

Definition before_63 : @shared_program unit nat string string :=
  Run [(Read tt 0%nat (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 0%nat)))
    (Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 2%nat))) (OVar 0%nat)
    (Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 2%nat))) (Literal (VInt 0%Z))
    (Read tt 1%nat (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 2%nat)))
    (Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 1%nat))) (OVar 1%nat)
    (Return tt []))))) : Cmd)].

Definition before_64 : @shared_program unit nat string string :=
  Run [(Read tt 0%nat (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 0%nat)))
    (Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 2%nat))) (OVar 0%nat)
    (Read tt 1%nat (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 2%nat)))
    (Write tt (Dispatch "mem" None) (Literal (VMemory (ExternalMemory 1%nat))) (OVar 1%nat)
    (Return tt [])))) : Cmd)].
