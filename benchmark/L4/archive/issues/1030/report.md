## Problem

A3 software atomics still lower to an ordered sync-block lock, and a result-bearing `hivm.hir.atomic_cas` aborts `hivm-insert-load-store-for-mix-cv`.

### 1. A3 仍用有序锁

`HIVMDecomposeOp` used to pick the lock from the architecture. Mem-based A3 (Ascend910B) got the default ordered token-ring lock. Ordered locks enter only when the lock word equals `get_block_idx` and unlock stores `block_idx + 1`. Independent atomic updates stall on that order. A5/regbase already used `{ordering = #hivm.ordering<unordered>}`.

### 2. `%x = hivm.atomic_cas` 在 insert-load-store 里报错

`atomic_cas` / `atomic_xchg` / `atomic_rmw` are defined in `HIVMDMAOps.td`, so mix-cv propagation's `TypeSwitch` treats them as DMA ops and then does `cast<HIVMStructuredOp>`. Those three ops were plain `HIVM_Op`s and do not implement `HIVMStructuredOpInterface`. The cast asserts:

```text
Casting.h: Assertion `isa<To>(Val) && "cast<Ty>() argument of incompatible type!"' failed.
```

The stack is `InsertLoadStoreForMixCVPass::runPropagateOpPatterns` → `PropagateUpPattern`.

A reproducing kernel is `atomic_xchg_mlir/atomic_cas_A3/kernel.mlir` (`Ascend910B4`). Before the fix the op is still present at that pass:

```mlir
%x = hivm.hir.atomic_cas
    ins(%cmp, %new : memref<160xi32>, memref<160xi32>)
    outs(%gm : memref<160xi32, strided<[1], offset: ?>>) -> tensor<160xi32>
```

## Expected

- A3 and A5 software-atomic locks are unordered.
- A result-bearing atomic compare-and-swap is either decomposed before HIVM, or, if an `hivm.hir.atomic_cas` remains, it is a structured DMA op so insert-load-store does not abort.

## Actual

- A3 decompose emitted `hivm.hir.sync_block_lock` with no `ordering` attribute (ordered).
- `%x = hivm.hir.atomic_cas` aborted insert-load-store with the `HIVMStructuredOp` cast above.

## Impact

A3 Triton `atomic_cas` that returns the old value cannot finish the BiShengIR pipeline. A3 software atomics that do compile take the ordered lock.