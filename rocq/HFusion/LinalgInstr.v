From Stdlib Require Import List String.
From UnifiedInterpreter.HFusion Require Import Syntax.

Inductive linalg_binary_fn :=
| LinalgAdd
| LinalgSub
| LinalgMul
| LinalgDiv.

Inductive linalg_unary_fn :=
| LinalgExp
| LinalgLog.

Inductive matmul_input_precision :=
| MatmulIEEE.

Inductive linalg_instr :=
| LinalgFill (input : typed_value) (output : typed_value)
| LinalgTranspose (input output : typed_value) (permutation : list nat)
| LinalgMatmul (left right output : typed_value)
    (input_precision : matmul_input_precision)
| LinalgElemwiseBinary (function : linalg_binary_fn)
    (left right output : typed_value)
| LinalgElemwiseUnary (function : linalg_unary_fn)
    (input output : typed_value)
| LinalgReduce (input output : typed_value) (dimensions : list nat)
| LinalgBroadcast (input output : typed_value) (dimensions : list nat)
| LinalgYield (values : list typed_value).
