### Environment

Ascend960, AscendNPU-IR v2 pipeline, CANN 9.2.0.

### Reproduction and observed result

Compile `create-preload-affine-view-size.mlir` with CreatePreload. A tile extent computed by `affine.apply` from the loop induction variable triggers `LLVM ERROR: Unhandled scope result case`. Each pipeline stage needs its extent computed from that stage’s induction variable. Expanding A6 multibuffers before preload can also give a producer and consumer the same slot.

The linked regressions cover the affine extent and the A6 pass order. With both corrections in the combined build, `recommendation/test_jagged_dense_flash_attention_bwd_dk_kernel.py` passed its original CANN model comparison.

[Compiler comparison in !5334](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5334?ref=&did=f6c3234e56bd97f7ba532f33c3d55f4be87fe4a6#tid-202318400) · [Regression evidence (ZIP)](https://raw.gitcode.com/Ascend/AscendNPU-IR/attachment/uploads/102e72cc-2413-4773-8c8b-554c261a9f7c/05-preload-28f715b74a.zip)