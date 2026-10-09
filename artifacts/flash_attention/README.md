# FlashAttention HFusion Snapshot

This directory keeps the source and one compiled HFusion-level artifact used
to define the first realistic interpreter milestone.

## Provenance

- `source/06-fused-attention.py` is archived from
  `Ascend/triton-ascend`, commit
  `865691e2e9b656bc58008170207b4108d92e8dd1`.
- Upstream path:
  `third_party/ascend/tutorials/06-fused-attention.py`.
- `ir/hfusion_level.mlir` was supplied by the project collaborators as the
  corresponding HFusion output.

The observed specialization is `Z=1`, `H=1`, `N_CTX=128`, `HEAD_DIM=128`,
`causal=false`, `f16`, `BM=32`, `BN=128`, with 20 logical cores.

## Source-to-HFusion Correspondence

| Triton-level idea | HFusion artifact |
| --- | --- |
| program/core id and grid traversal | `scf.for %arg16 = %arg13 to 4 step 20` |
| block pointer calculation | scalar `arith` followed by `memref.reinterpret_cast` |
| block load | `memref.alloc`, `memref.copy`, `bufferization.to_tensor` |
| `q @ k^T` | `linalg.transpose`, then `linalg.matmul` |
| stable softmax | max reduction, broadcast, subtract, `exp`, sum reduction |
| probability narrowing | `hfusion.cast` with `round_mode = rint` |
| probability times value | the second `linalg.matmul` |
| output and log-sum-exp stores | `bufferization.materialize_in_destination` |

This snapshot is deliberately immutable. New compiler outputs should be added
as separate artifacts with their compiler revision and specialization, rather
than replacing this file.
