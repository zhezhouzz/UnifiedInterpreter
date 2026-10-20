# HIVM compute-stage attention semantics

## Boundary and how to run

The sole input defining this milestone is
`artifacts/flash_attention/ir/attention_hivm_compute.mlir`, dumped immediately
after `convert-hfusion-to-hivm`. It has 10 HIVM compute primitive kinds.
The implementation supplies their executable **parameterized Rocq semantics**,
small examples/proofs, a primitive dispatcher and an OCaml extraction check.
It does not parse this file, execute its whole function, or run FlashAttention.
The memory/lowered snapshots, DMA queues, pipeline synchronization, scheduling,
hardware conformance and bit-accurate floating-point backends are out of scope.

From the repository root, with the project's isolated opam switch:

```sh
ROCQ_OPAM_SWITCH=unified-interpreter ./scripts/check_rocq.sh
opam exec --switch=unified-interpreter -- dune test
```

The first command inventories the artifact, checks Rocq proofs, regenerates
extraction, compiles it, and runs `scripts/check_extracted_hivm.ml` against the
generated module. That driver never calls the hand-written `lib/` interpreter.
Generated `.ml/.mli` and compilation products remain ignored build artifacts.

## Operation coverage

Only the tensor forms and attribute combinations occurring in this snapshot
are supported, with smaller positive shapes allowed for tests. Operations
accept rank-one/rank-two positive shapes where applicable. Unsupported modes
return errors; this is not a claim to implement every mode of an admitted
opcode. Raw MLIR parsing/elaboration, including unknown attribute rejection,
is future work. All inputs to these functions are already typed API values.

| Artifact operation | Implementation / boundary |
| --- | --- |
| `hivm.hir.vadd` | `Semantics.sem_binary VAdd`; f32 tensor/tensor or scalar broadcasting |
| `hivm.hir.vsub` | `Semantics.sem_binary VSub`; same shape/type checks |
| `hivm.hir.vmul` | `Semantics.sem_binary VMul`; same shape/type checks |
| `hivm.hir.vdiv` | `Semantics.sem_binary VDiv`; numeric errors propagate |
| `hivm.hir.vexp` | `Semantics.sem_unary VExp`; typed numeric callback |
| `hivm.hir.vln` | `Semantics.sem_unary VLn`; typed numeric callback |
| `hivm.hir.vbrc` | Scalar fill with no axes; M×1 to M×N with `broadcast_dims=[1]` |
| `hivm.hir.vreduce` | Sum/max over `[1]`; M×N becomes M×1, preserving rank |
| `hivm.hir.vcast` | f32→f16 only; default signed cast, RINT |
| `hivm.hir.mmadL1` | f16×f16 to f32; optional B transpose, both init conditions |
| `arith.constant` | `Arith.sem_integer_constant`, `sem_float_constant`; i1/i32/i64/index and backend f32 literals including negative infinity |
| `arith.addi` | `Arith.sem_integer_binary`; modular addition without overflow flags |
| `arith.muli` | `Arith.sem_integer_binary`; modular multiplication without overflow flags |
| `arith.divsi` | Signed quotient truncated toward zero; zero divisor and MIN/-1 report `NumericFailure` |
| `arith.remsi` | Signed remainder; zero divisor reports `NumericFailure`; MIN%-1 is zero |
| `arith.extsi` | i32→i64 sign extension |
| `arith.index_cast` | i32/i64→index; this reference profile fixes index width to 64 bits |
| `tensor.empty` | `Semantics.sem_empty`; shape/type only, no initialized values |
| `tensor.expand_shape` | `Semantics.sem_reshape true`; checked ordered axis partition |
| `tensor.collapse_shape` | `Semantics.sem_reshape false`; same validation and element order |
| `memref.alloc` | Existing `HFusion.Semantics.Memory.sem_memref_alloc` |
| `memref.copy` | Existing logical-coordinate copy and non-overlap checks |
| `memref.reinterpret_cast` | Existing descriptor creation with offset/sizes/strides |
| `bufferization.to_tensor` | Existing live memref-backed tensor; materialize when consumed |
| `bufferization.materialize_in_destination` | Existing typed destination writeback, adapted by `Execution.write_result` |
| `func.func` | Function/argument metadata reused in stage syntax; no function runner in this milestone |
| `func.return` | Existing common return syntax; no function runner |
| `scf.for` | Existing common region/loop syntax; no control-flow execution in this milestone |

`scripts/check_hivm_scope.py` guards this inventory. It is a lexical operation
inventory, not a parser or proof that an arbitrary input belongs to this stage.
Module target resource declarations and HACC entry attributes are metadata;
they are not given allocation-capacity, launch or synchronization behavior here.
An integer constant with type i1 represents the artifact's `true`/`false`.
Untouched dynamic function arguments need no executable semantics in this
primitive-only milestone. A caller supplies actual runtime shapes and values.

## Semantics and numerical contract

`HIVM.Value` reuses the existing length-certified `Tensor.Model.tensor` for
defined values. `EmptyTensor` is distinct and may be used as the destination
of an overwriting operation without reading nonexistent cells. An input read,
writeback, or MMAD accumulation from an empty tensor reports `ReadUninitialized`.
Reshaping an empty tensor preserves its uninitialized status. Constructors are
metadata containers; the semantic functions validate their supported domain.

`HIVM.Numeric.Numeric` is separate from the old HFusion `ScalarOps`, preserving
that interface. It receives f32 elementwise/unary operations, reduction kinds
and element types, f32→f16 cast specifications, and f16 input/f32 accumulator
types for multiply-accumulate. Numeric failures become `NumericFailure`.
A production backend must supply IEEE exceptional values, rounding and the
chosen precision policy. In particular:

- Sum starts from zero; max starts from negative infinity. `vreduce` does not
  fold arbitrary old destination cells. Its max callback must propagate NaNs,
  unlike `arith.maxnumf`. The keep-dim output is M×1.
- `mmadL1` with init=true starts from zero, ignoring old destination values;
  init=false requires initialized destination values. B transpose changes
  indexing. Source f16 and accumulator f32 are passed to the MAC callback;
  products are not silently cast to a standalone f16 intermediate.
- This early-stage IR contains zero M/K/N placeholders. Their meaning is
  supported by the pinned HFusionToHIVM conversion code, not inferred as empty
  dimensions. Computation dimensions come from tensor shapes. Nonzero M/K/N
  values are rejected because their later-stage semantics is not implemented.
- Dot products and reductions use ascending row-major sequential folds. This
  is an explicit reference execution policy, not a hardware accumulation-order
  claim. The numeric backend can define fused MAC; this does not make the fold
  equivalent to every hardware reduction tree.
- Integer add/multiply wrap at the declared width. Signed quotient/remainder
  use two's-complement interpretation. Undefined division inputs are exposed
  as errors rather than represented by a general MLIR poison/UB model.

`Examples.HIVMCompute.test_numeric` is deliberately a **structural mock** over
integers. It uses sentinel offsets for exp/ln/cast and a finite max seed to test
dispatch and metadata forwarding. It is not a conforming f16/f32 backend and
must not be used to claim numerical attention results. Small integer matrix,
broadcast and sum results have hand-computed expectations. Additional tests
exercise NaN forwarding through a dedicated reduction-only backend.

## State boundary and proof obligations

Pure tensor functions do not access machine state. Memory effects reuse the
existing handler. `Execution.local_memory` checks both effect failures and an
inner semantic error before returning a successor state. `run_memory` uses
`HasMemory.memory_lens` and `zoom` to embed that local computation in any state
providing the component. Events are output observations, not instruction inputs.

Production state remains `memory_state`; no speculative pipeline/register/queue
fields are introduced. `Examples.HIVMMemory` alone supplies a larger test state
with an independent marker. The same view→copy→to_tensor→HIVM-add→writeback
computation runs over both states and leaves the marker and source buffer intact.

Checked properties include certified element count, successful binary/unary
shape/type preservation, reshape element-order preservation, generic independent
component preservation through the memory lens, and concrete success/error
examples. No hardware consistency, whole-attention correctness, or HFusion→HIVM
semantic-preservation theorem is claimed. The HFusion API and examples remain.

## Sources

The official snapshot is pinned at
`22e3d51df4642fb0f74060af36f5c5c80be80d08`; see `vendor/ascendnpu-ir/README.md`.
The artifact's compiler revision has not been recorded in its archive README;
these sources explain the implemented reference profile, not verified provenance
for the newly supplied IR dumps.

- [Official HIVM operation reference](https://ascendnpu-ir.gitcode.com/zh_cn/developer_guide/dialects/hivm_dialect.html).
- [Pinned vector definitions](https://github.com/Ascend/AscendNPU-IR/blob/22e3d51df4642fb0f74060af36f5c5c80be80d08/bishengir/include/bishengir/Dialect/HIVM/IR/HIVMVectorOps.td): cast defaults, reduction shape and NaN rules.
- [Pinned vector implementation](https://github.com/Ascend/AscendNPU-IR/blob/22e3d51df4642fb0f74060af36f5c5c80be80d08/bishengir/lib/Dialect/HIVM/IR/HIVMVectorOps.cpp): `VReduceOp::getInit` defines reduction identities.
- [Pinned matrix definitions](https://github.com/Ascend/AscendNPU-IR/blob/22e3d51df4642fb0f74060af36f5c5c80be80d08/bishengir/include/bishengir/Dialect/HIVM/IR/HIVMMacroOps.td): init condition and matrix operand contract.
- [Pinned HFusionToHIVM conversion](https://github.com/Ascend/AscendNPU-IR/blob/22e3d51df4642fb0f74060af36f5c5c80be80d08/bishengir/lib/Conversion/HFusionToHIVM/Matmul.cpp): zero M/K/N stubs and initialization/transpose handling.
- [MLIR arithmetic reference](https://mlir.llvm.org/docs/Dialects/ArithOps/): modular arithmetic, sign extension and signed division/remainder.
