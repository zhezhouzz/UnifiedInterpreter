From Stdlib Require Import List.
From UnifiedInterpreter.HFusion Require Import Syntax.

Inductive arith_binary_operator :=
| ArithAddI
| ArithMulI
| ArithDivSI
| ArithRemSI
| ArithAddF
| ArithMaxNumF.

Inductive arith_cast_operator :=
| ArithExtSI
| ArithIndexCast.

Inductive arith_instr :=
| ArithConstant (value : literal) (result_type : mlir_type)
| ArithBinary (operator : arith_binary_operator)
    (left right : typed_value) (result_type : mlir_type)
| ArithCast (operator : arith_cast_operator) (input : typed_value)
    (result_type : mlir_type).
