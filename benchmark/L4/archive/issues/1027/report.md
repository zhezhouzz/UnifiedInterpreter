## Environment

A5 target `Ascend950DT_9582`, AscendNPU-IR base `214c49d973f4`. DTS ticket `DTS2026111745590`.

## Failure

The attention-backward kernel `_attn_bwd_pipelined_kernel` has four `scf.if` results explicitly bound to L0C allocations. Each arm yields a local matmul accumulator. Fixpipe insertion replaces both yields with UB transfer results. After bufferization, `BindBuffer` aliases those UB destinations to L0C. Memory-scope inference then fails on the incompatible scopes.

The binding must continue to refer to the raw accumulator. A store needs the transferred value, while a later matmul using the result as its C operand can consume the accumulator directly.

## Reproduction

Run the reduced MLIR fixture through `bishengir-opt --hivm-insert-fixpipe` built at the base revision. In `@single_fixpipe_after_scf_if`, inspect the operands of the two `scf.yield` operations. Both take a Fixpipe result. In the full pipeline the captured kernel produces eight CC-to-UB casts after `bind-buffer`. [Reduced fixture](https://gitcode.com/hocky/AscendNPU-IR/blob/ef7c5b2d32155cab0b7adfe5c294b4102c80d324/bishengir/test/Dialect/HIVM/insert-fixpipe-for-scf-if-mmad.mlir) · [Before/after IR from the captured kernel](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5305?ref=&did=b07f3d5b8bd61950922e076658699bffc2896c61#tid-202188747)

The proposed fix is [AscendNPU-IR !5305](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5305).
