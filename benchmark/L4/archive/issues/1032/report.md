## Performance

A pure-SIMT two-stage sampling program on Ascend 950 performs both a coarse and a fine cumulative distribution scan. Even when a tile contains a single positive weight, the program evaluates the scans, threshold comparisons and reductions. Two warps also cooperate on a request whose supported layout can run in one warp.

Introduce a compiler-side optimization for this IR pattern, with a runtime guard for direct selection and a verified one-warp-per-request layout. Preserve the floating-point result and keep the original compiler pipeline available for programs with unsupported memory effects, collective layouts or launch options.

## Verification

Exercise a renamed positive example and similar programs that must retain the original layout. Check emitted launch metadata, device code for unrelated kernels, and dense and sparse input behavior. Compare execution time using the same input IR and launch settings.

## Environment

Ascend 950, BiShengIR RegBase, pure-SIMT compilation of Triton IR.
