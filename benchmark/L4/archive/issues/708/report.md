
### 🐛 问题描述
            
 GSS (like InjectSync) treats func::CallOp as skippable, so a SIMT VF call leaves no sync edge to its VECTOR consumer → the device race.
 
 The SIMT gather runs as a separate vector-function scope launched by the entry
func `conv2d_forward_kernel_mix_aiv` (`hivm.func_core_type = AIV`). The AIV
writes the 32×32 A tile into UB (`AUB@0`) from SIMT lanes, and the VECTOR
`fused_0` reads that UB block a few ops later. The sync pipeline fails to order
these two for three layered reasons:

### 2.1 `InjectBlockSync` never runs on the entry func

`InjectBlockSyncPass::runOnOperation()` gates on the func's core type
(`InjectBlockSync.cpp:493`):

```cpp
if (hivm::util::queryFuncCoreType(funcOp) != MIX) {
  // skip — needs both AIV and AIC on the same func
}
```

The entry func here is **AIV-only** (it *launches* the AIC via `sync_block` /
`launch_func` rather than being a mixed func itself), so cross-core-type sync
via this pass is skipped entirely for the SIMT→VECTOR ordering.

### 2.2 Intra-core sync solvers treat `func::CallOp` as skippable

The default intra-core solver (`InjectSync` / `AutoInjectSync`) collects the
VF call graph through `IRTranslator`; `IRTranslator::isSkippableOp()`
(`IRTranslator.cpp:119`) returns `true` for `func::CallOp`, so the SIMT VF call
contributes **no set/wait flag edge**. Its VECTOR consumer `fused_0` is ordered
only against same-core VECTOR/MTE2/MTE3 events — those never wait for SIMT lane
completion, leaving an open race on `AUB@0`.

### 2.3 The A5 merged pipeline runs GraphSyncSolver (GSS) by default

A first attempt to hook the barrier into `AutoInjectSync` (NORMAL mode) never
fired, because the default A5 regbase pipeline does **not** run
`hivm-inject-sync` in NORMAL mode:

- `bishengir/Tools/bishengir-compile/Options.td:196-202` defaults
  `EnableHIVMGraphSyncSolver` to `"true"` for the A5 (RegBase) targets.
- `hivmIntraCoreSyncPipeline` (`HIVMRegbasePipelines.cpp:98-130`) therefore
  runs **GSS** (`hivm-sync-optimization-reg-base`); only with
  `enable-hivm-inject-barrier-all-sync` does it fall back to barrier-all mode.
- GSS likewise treats `func::CallOp` as skippable (same blind spot).

This also explains the earlier observation that barrier-all mode "fixed" the
race: with barrier-all enabled (`Options.td:101`), `hivmIntraCoreSyncPipeline`
bypasses GSS and the `InjectSync::BARRIERALL` pass inserts `pipe_barrier` on
every op, including both sides of the call.

### 2.4 Resulting defect

| Production | Consumption | Ordering present | Race |
|---|---|---|---|
| SIMT VF `scope_1` → UB `AUB@0` | VECTOR `fused_0` reads `AUB@0` | none (CallOp skippable) | **yes** |

Device-consistent signature: with a fixed pipeline schedule the same lanes race
the same way every run → deterministic mismatch; the band of A-tile rows fed
from not-yet-written UB cells corrupts ~25% of the output. Template mode never
shows this because its A path never crosses core types.