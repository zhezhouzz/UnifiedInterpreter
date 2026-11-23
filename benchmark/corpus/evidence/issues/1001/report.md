## 1. Background and Motivation

On Ascend, `torch.sin` is one fused SIMT kernel: hardware `DMA` moves tiled data while SIMT units compute only the math, switching algorithm at runtime
based on input magnitude (Cody-Waite for inputs below `71476.0625`, Payne-Hanek above).

The Triton SIMD path cannot reuse any of that. `math.sin` is expanded in `MLIR` at the `Normalize` pass into SIMD vector operations, with algorithm fixed at
compile time by `--enable-high-precision` (default `true`). Measured against `torch.sin` (`tl.sin / torch.sin`), the picture is range-dependent:

- `small` inputs (`|x| <= 1.0`): SIMD lags by up to ~1.8x (e.g. 1.81); on larger tensors the gap shrinks to ~1-3%;
- `huge` inputs: SIMD is **already faster** than torch, up to ~100x on large tensors. The SIMD Payne-Hanek reduction is memory-bound, while the
  SIMT reference pays for 64-bit arithmetic.

So the only range where SIMD `sin` loses is `small` inputs (`|x| <= 1.0`). There, a runtime magnitude dispatch on SIMD would close the gap, but it is not implementable today:

1. The naive `select` approach gives no performance gain, since both algorithms would run and only then the correct result be selected per element;
2. The second approach - a real `if` dispatch - requires a large number of compiler changes, since existing passes (including large ones such as `AutoVectorize`, `PlanMemory`, etc.) cannot handle such a structure.

The proposed feature: let SIMD vector code call a SIMT device routine (`sin` first) instead of expanding it inline. The target is the `small` gap above; the call is not expected to beat `torch` on `huge` inputs. If it works, SIMD code reuses the runtime-switched SIMT routine and stays composable with surrounding vector ops.

A proof-of-concept (`SIMT sin call from SIMD context`) was built. Results:

- `small` inputs: ~99%-143% of torch — the `tl.sin / torch.sin` ratio improves from `1.81` to `1.43`;
- `huge` inputs: up to >4x slower than torch (e.g. 4.24).

So the PoC is promising only for the `small` case, and points at the call boundary and tile padding — not the math — as the thing to fix.

Observations from the PoC: the same algorithm ran slower than torch because the call computed the full padded tile and kept a dead zero-fill; the boundary itself adds no `GM` transfers. What remains is the call envelope (descriptors, flags) and grid sizing. So the feature is not "just link the call" — the boundary still needs design, but the problem is not extra `GM` traffic.

It was also noticed that the functions from `libdevice` and from `TemplateLib` share the same symbol name, so in `SIMT-only` mode `sin` links against the `libdevice` implementation, which appears to be incorrect behavior (see 4.1).

Moreover, the `libdevice` implementation has a magnitude bound at which the computation loops forever due to variable overflow.

## 2. Current Status

| Component | Status | Role in this feature |
|---|---|---|
| CANN `Sin` SIMT kernel | Shipped, reference | Algorithm and performance target |
| `TemplateLib` `simt_sin` | Shipped (bounded, no loops) | Callee |
| Standalone `libdevice` `sin` | Shipped (external; unbounded loop) | Must not supply the symbol (see 4.1) |
| SIMD -> SIMT call PoC | Experiment only | Proves feasibility, misses performance target |
| SIMD -> SIMT call convention | Implemented for f32 `sin` ranks 1--5 | Current lowering uses rank-specialized UB memref descriptors |

## 3. Expected Functional Content

### 3.1 Functional goals

- A SIMD vector function can call a SIMT device routine elementwise for f32 `sin` ranks 1--5.
- The calls bind to the bounded `TemplateLib` `sin_fp32_simt_<rank>d` callees.
- Numeric behavior of the call equals the standalone SIMT routine bit for bit for the same input. This is a boundary invariant, not an accuracy criterion.
- Performance requirements and the `BLOCK=8192`, ≥1M harness are in section 5.2.

### 3.2 Non-goals (out of scope for this request)

- Fixing the standalone `libdevice` loop itself (separate issue, if ever; this feature only requires the duplicate symbol to resolve to `TemplateLib`).
- Changing the CANN `Sin` op or its kernel.
- Porting the SIMD Normalize reduction into the SIMT callee is deferred to 4.4; it is not part of the initial landing.
- Runtime magnitude dispatch implemented in SIMD itself (as opposed to inside the SIMT callee); left for a later AR.

### 3.3 Support matrix (for the test team: what must hold)

OK = must hold.

| Case | small | huge |
|---|---|---|
| f32 SIMT call, result accuracy, ranks 1--5 | OK | OK |
| Partial tiles: valid region correct, no writes outside `[0, n)` | OK | OK |

range definitions: `small := [-1.0, 1.0]`, `huge := [-1.0e8, 1.0e8]`.

## 4. Specific Design Plan (one section per AR)

Implement and integrate the following ARs as one feature track. Each subsection is one AR.

### 4.1 [npuir] Resolve the duplicate symbol to TemplateLib

Goal: canonical `_mlir_ciface_simt_*` symbols must be provided only by `TemplateLib`. `libdevice` remains linked and reachable, but must define its SIMT routines under provider-qualified names. This protects the simt_only/standalone path. The SIMD-to-SIMT call path uses distinct rank-suffixed `_mlir_ciface_sin_fp32_simt_<rank>d` symbols and is not part of the canonical `simt_sin_float` collision.

Design
- Owner: `libdevice` and the frontend lowering for the libdevice path.
- Decision: rename, do not remove. `libdevice` stays a supported provider; its colliding `simt_*` copies are renamed provider-qualified (`_mlir_ciface_libdevice_simt_*` or equivalent). The canonical `_mlir_ciface_simt_*` names then have exactly one definition.
- If `libdevice.sin` must keep mapping to libdevice's implementation, the frontend lowering (`__hmf_sin_fp32` / `ascend_dpx::SinOp` path) must emit the renamed symbol. Otherwise it will silently resolve to `TemplateLib`. This frontend change is part of the AR.
- Inventory the symbols defined by both providers (not only `sin`).
- Mechanism (confirmed in code): on A5 the frontend-provided bitcodes are linked before `meta_op`, and duplicates resolve to the first module — so `libdevice` wins. Relying on link order is not a fix; the collision must be removed by the rename.

IR demonstration (phase): no IR change; the observable is symbol resolution.
Before:
```
  libdevice: _mlir_ciface_simt_sin_float          -> libdevice implementation
  meta_op:   _mlir_ciface_simt_sin_float          -> TemplateLib implementation
```
After:
```
  libdevice: _mlir_ciface_libdevice_simt_sin_float -> libdevice implementation
  meta_op:   _mlir_ciface_simt_sin_float           -> TemplateLib implementation
```

Test focus: each canonical `simt_*` symbol is defined exactly once across the linked bitcodes and served by `TemplateLib`; the `libdevice` path still resolves to libdevice's renamed implementation; the reproducer kernel is identical with and without the `libdevice` bitcode on the link line; resolution does not depend on link order.

### 4.2 [npuir] Call boundary: convention and outlining

Goal: define how a SIMD vector function invokes a SIMT routine — argument passing, masking for partial tiles, output placement, buffer ownership, sync, and the ABI.

Design
- Decision (scope): the landing covers f32 `sin` ranks 1--5. The convention is
  written to be reusable for other SIMT routines, but the first non-sin routine
  is a separate AR.
- Args: UB tiles by memref descriptor (ptr, offset, size, stride); the callee never touches GM.
- Masking (contract; optimization in effect): count-based — the descriptor carries the valid element count; the callee computes exactly that many elements. Masked lanes are not computed and other= padding is never read. Correctness does not depend on this: the callee is elementwise and bounded, and the store is masked; the count only avoids computing the padding.
- Output: out-of-place into a caller-owned `UB` tile; the callee writes `total` elements. In-place is a future extension.
- Ownership: the caller owns all buffers and double-buffering; the callee is stateless and allocates nothing.
- Sync: input ready before the call, completion awaited after — on the caller (flag shape is 4.3 scope).
- ABI (target): pass `(ptr, offset, count, stride)` directly; no per-call descriptor construction.
- PoC status: the PoC implements the custom-op call with `UB` memref descriptors and an out-of-place destination; the callee reads `total = src->sizes[0]` and allocates nothing. The tail-slice path is implemented only for the narrow case where the result has a single zero-offset `extract_slice` user; other consumers still see the full padded tile. The fast ABI and a general count-based contract are not implemented; sync relies on the existing pipeline.

IR demonstration (phase)
Before (PoC): the full padded tile reaches the callee; the descriptor carries the padded size.
```
  %pad  = ... // padded tile + zero-fill
  %call = hivm.hir.custom "sin_fp32_simt" ins(%pad) ...
```
After (target): the input is sliced to the valid count; the descriptor carries that count.
```
  %slice = tensor.extract_slice %in[0][%n][1] : tensor<?xf32>
  %call  = hivm.hir.custom "sin_fp32_simt" ins(%slice) ...
```
The dead zero-fill is erased.

Test focus: partial-tile correctness — the valid region is correct and nothing outside [0, n) is written. Boundary check (lit/unit, requires 4.1) — the call path and simt_only are bit-identical on the valid region; this verifies the boundary, not accuracy. The count-based tail slice is an optimization and is covered by the lit dump test.

### 4.3 [npuir] Pipeline integration (bufferization, memory, sync)

Goal: the call must survive `one-shot-bufferize`, `PlanMemory`, and sync solving without pessimizing the surrounding code.

Design
- Measured on the PoC: the boundary adds no `GM` transfers — read/write traffic and `MTE` times match the CANN kernel.
- The PoC overhead was elsewhere: the call computed the full padded tile instead of the valid region, fixed by count-based masking; the dead zero-fill was removed as well.
- What remains is the call envelope itself (stack descriptors and flag pairs), to be addressed by the fast ABI and data-driven sync.

IR demonstration (phase)
Pipeline dumps show the call operands staying UB-resident; no store/load pair is inserted at the boundary.
```
  // after one-shot-bufferize + PlanMemory
  // the input/output memrefs of the call are UB allocations;
  // no memref.load/store or copy is inserted at the boundary
```

Test focus: no extra GM round-trips attributable to the call boundary (backed by the measurement); stage-dump comparison as the regression guard.

### 4.4 [npuir] Speed up the SIMT Payne-Hanek branch

Goal: replace the Payne-Hanek reduction in the SIMT callee with a
Normalize-style reduction, so the call gets closer to `torch` on
`huge` inputs.

Design
- Decision (accuracy): `small` inputs keep the current callee; `huge` inputs may drop to the `3.6e-6` bound. The standalone reference is re-pinned to the updated callee.
- Root cause: the current callee is compute-bound on the Payne-Hanek chain. The gap is per-element arithmetic; boundary, tiling, or codegen work cannot close it.
- Idea: port the SIMD `Normalize` reduction into the callee.

IR demonstration (phase): no IR change at the call site; the change is in the linked `TemplateLib` callee. The module stays identical:
  %call = hivm.hir.custom "sin_fp32_simt" ins(%slice) ...
Only the callee bitcode changes (int64 Payne-Hanek -> Normalize-style reduction).

Test focus: `huge` inputs get closer to `torch`; accuracy follows the M2 bounds in section 5.2; `small` inputs are unchanged; the standalone reference is re-pinned.

## 5. Testing Plan

### 5.1 Unit / lit (compiler)

| Area | Cases | Verification |
|---|---|---|
| Single provider | one definition across linked bitcodes; link-order swap reproducer | `--link-aicore-bitcode` with/without `libdevice` bitcode; `meta_op` before/after |
| Call boundary (IR) | custom op created, tail slice, dead-fill erasure | lit on `--bishengir-print-ir-after` dumps: `convert-math-to-hfusion` (custom op created, input sliced to the valid count, zero-fill erased); `hfusion-pre-vectorization-fusion`, `hfusion-auto-vectorize-v2`, and `outline-vector-function` (custom op unchanged); final LLVM translation (`llvm.call @sin_fp32_simt_<rank>d`, descriptor carries the runtime count) |
| Boundary invariance | call path vs `simt_only` on the valid region | bit-identical results (requires 4.1); this is not an accuracy criterion |
| Partial tiles | `n = k*BLOCK + r`, `r ∈ {1, BLOCK/2, BLOCK-1}` | valid region correct; no writes outside `[0, n)` |
| Pipeline survival | `bufferize` + `PlanMemory` + sync dumps around the call | `--mlir-print-ir-after-all` stage comparison |

### 5.2 Integration / e2e

Numeric acceptance (f32 ranks 1--5, `small` and `huge` inputs, at sizes 1M, 16M, and 64M):
- `TemplateLib` callee: max abs diff vs `torch.sin` ≤ `1e-6`. This is a regression guard: the callee implements the same algorithm family as `torch`.
- After 4.4, `small` remains ≤ `1e-6`; `huge` inputs are ≤ `3.6e-6` versus `torch.sin`.

Performance acceptance (f32 ranks 1--5, `tl.sin / torch.sin`, per regime):
- Test only sizes >=1M: 1M, 16M, 64M.
- Use `BLOCK=8192` for every range and size, matching the Torch-comparison
  tiling for these tensors.
- `small`: target ≤ `1.0x`; the larger sizes are memory-bound.
- `huge`: record the ratio for information; this range is outside the call's
  performance acceptance until 4.4.
- The compiler does not read `BISHENGIR_SIN_NORMALIZE`; do not set this
  variable in test scripts.

Etalon tests (attached): `sin_original_test.py` and `test_common.py`.

### 5.3 Unsupported cases (test restrictions)

- No additional test restrictions: the §3.3 support matrix defines what must hold.

## 6. Precision Requirements

- Call results must equal the standalone SIMT routine bit for bit on the valid region (the boundary adds no error). This is a boundary invariant, not an accuracy criterion.
- The acceptance bounds are in section 5.2: ≤ `1e-6` versus `torch.sin`; after 4.4, `small` stays ≤ `1e-6`, and `huge` inputs ≤ `3.6e-6`.

## 7. FAQ

Q: Why not just keep the inline Normalize expansion?
A: It lags `torch` by up to ~1.8x on `small` inputs with no runtime dispatch possible. The call reuses the runtime-switched SIMT algorithm instead.

Q: Why was the PoC slow if the algorithm is the same as `torch`?
A: The PoC computed the full padded tile instead of the valid region and kept the dead zero-fill; both are fixed by count-based masking and fill erasure. The boundary itself adds no `GM` transfers — traffic and `MTE` times match the CANN kernel. What remains is the call envelope. The call is aimed at `small`; on `huge` inputs the call remains slower than `torch` until 4.4.

Q: Does this feature depend on the libdevice hang fix?
A: No. The calls use distinct `sin_fp32_simt_<rank>d` symbols. Section 4.1
covers separate SIMT-only and standalone symbol resolution.

Q: Why `TemplateLib` rather than porting the CANN algorithm as the callee?
A: `TemplateLib` already implements the same algorithm family in bounded form,
so no port is needed for this feature. Porting a Normalize-style reduction into
the callee remains a separate direction (4.4) and would change `huge`-input
accuracy.

Q: Is the duplicate symbol resolved?
A: Not yet for SIMT-only/standalone resolution. The SIMD-to-SIMT calls are
unaffected because they use `sin_fp32_simt_<rank>d`, not the colliding canonical
`simt_sin_float` symbol. The proposed fix remains to rename colliding libdevice
symbols and update the libdevice frontend path to call provider-qualified names.