From Stdlib Require Import List String ZArith.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import Syntax.
Import ListNotations.
Open Scope string_scope.
Local Notation Cmd := (@command unit nat string string unit).
Definition expected : @shared_program unit nat string string :=
  Run [(SetFlag tt (Literal (VPipe "PIPE_MTE1")) (Literal (VPipe "PIPE_MTE2")) (Literal (VEvent 2%nat))
    (SetFlag tt (Literal (VPipe "PIPE_MTE1")) (Literal (VPipe "PIPE_MTE2")) (Literal (VEvent 3%nat))
    (SetFlag tt (Literal (VPipe "PIPE_FIX")) (Literal (VPipe "PIPE_M")) (Literal (VEvent 0%nat))
    (SetFlag tt (Literal (VPipe "PIPE_M")) (Literal (VPipe "PIPE_MTE1")) (Literal (VEvent 0%nat))
    (SetFlag tt (Literal (VPipe "PIPE_M")) (Literal (VPipe "PIPE_MTE1")) (Literal (VEvent 1%nat))
    (Return tt []))))) : Cmd)].

Definition slice_actual : @shared_program unit nat string string :=
  Run [(SetFlag tt (Literal (VPipe "PIPE_MTE1")) (Literal (VPipe "PIPE_MTE2")) (Literal (VEvent 2%nat))
    (SetFlag tt (Literal (VPipe "PIPE_MTE1")) (Literal (VPipe "PIPE_MTE2")) (Literal (VEvent 3%nat))
    (SetFlag tt (Literal (VPipe "PIPE_FIX")) (Literal (VPipe "PIPE_M")) (Literal (VEvent 0%nat))
    (SetFlag tt (Literal (VPipe "PIPE_M")) (Literal (VPipe "PIPE_MTE1")) (Literal (VEvent 0%nat))
    (SetFlag tt (Literal (VPipe "PIPE_M")) (Literal (VPipe "PIPE_MTE1")) (Literal (VEvent 1%nat))
    (Return tt []))))) : Cmd)].
