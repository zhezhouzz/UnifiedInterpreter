From Stdlib Require Import List String ZArith.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import Syntax.
Import ListNotations.
Open Scope string_scope.
Local Notation Cmd := (@command unit nat string string unit).
Definition expected : @shared_program unit nat string string :=
  Run [(CCompute tt 0%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 1%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 2%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 3%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 4%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 5%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 6%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 7%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 8%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 9%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 10%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 11%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 12%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 13%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 14%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 15%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 16%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 17%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 18%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 19%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 20%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 21%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 22%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 23%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 24%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 25%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 26%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 27%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (CCompute tt 28%nat (Dispatch "unit_vcast" (Some (Literal (VPipe "PIPE_V")))) []
    (Return tt []))))))))))))))))))))))))))))) : Cmd)].
