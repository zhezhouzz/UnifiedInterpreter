# HFusion Instruction Scope for FlashAttention

## Scope

The first milestone is not a generic implementation of every HFusion or NPU
operation. It is a faithful executable semantics for
`artifacts/flash_attention/ir/hfusion_level.mlir`, followed by controlled
generalization. This artifact is already large enough to exercise indexing,
strided views, buffer/tensor boundaries, matrix multiplication, reductions,
transcendentals, and precision-changing casts.

## Operations Required by the Artifact

### Function and control flow

- `func.func` and `return`: function arguments, results, and entry metadata.
- `scf.for`: signed `i32` induction variable, lower/upper/step semantics, and
  loop-carried state through memory effects.

### Scalar and index arithmetic

- `arith.constant` for integers, index values, zero, negative one, and negative
  infinity.
- `arith.addi`, `arith.muli`, `arith.divsi`, and `arith.remsi`.
- `arith.extsi` and `arith.index_cast`.
- `arith.addf` and `arith.maxnumf`, including NaN and signed-zero behavior.

Signed division/remainder and index conversion must be specified explicitly;
using the host language's operators without checking edge cases is insufficient.

### Memrefs and storage

- `memref.reinterpret_cast`: construct a view from a base allocation, dynamic
  offset, sizes, and strides without copying.
- `memref.alloc`: fresh allocation with element type and shape.
- `memref.copy`: elementwise copy between contiguous and strided views, with
  overlap behavior stated explicitly.

This requires separate allocation storage and memref descriptors. Treating a
memref as just a flat OCaml array would lose the aliasing and offset semantics
needed to validate address calculation.

### Tensor and bufferization boundary

- `tensor.empty`: uninitialized destination value, not a zero-filled tensor.
- `tensor.expand_shape` and `tensor.collapse_shape`: shape reassociation with
  element order preserved.
- `bufferization.to_tensor ... restrict writable`: define whether the
  interpreter models an aliasing view or a snapshot and enforce the operation's
  aliasing promises.
- `bufferization.materialize_in_destination`: write a tensor result into the
  destination memref, including its offset and strides.

The bufferization operations are crucial for mixed-IR interpretation: they are
the semantic bridge between value-like tensor code and stateful memory code.

### Structured tensor computation

- `linalg.fill`.
- `linalg.transpose` with its permutation.
- `linalg.matmul` with destination/accumulator semantics.
- `linalg.reduce` with a region containing `arith.maxnumf` or `arith.addf`, and
  `linalg.yield`.
- `linalg.broadcast` with explicit broadcast dimensions.
- `linalg.elemwise_unary` for `exp` and `log`.
- `linalg.elemwise_binary` for `add`, `sub`, `mul`, and `div`, including
  scalar-tensor broadcasting.

The interpreter must preserve destination-passing semantics. An `outs` operand
is not merely a shape annotation: for `matmul` and reductions it supplies the
initial accumulator and can affect the result.

### HFusion-specific operation

- `hfusion.cast` with `cast_signed` and `round_mode = rint`, specifically the
  `f32 -> f16` conversions in this artifact.

This is the first dialect-specific numerical boundary and should produce a
trace event recording input type, output type, rounding mode, and a summary of
changed values.

## Numerical Semantics That Must Be Parameters

The artifact exposes the likely precision-debugging boundaries:

- `linalg.matmul {input_precison = "ieee"}`: product precision, accumulator
  precision, accumulation order, and whether multiply-add is fused;
- max and sum reductions: tree/serial order and intermediate precision;
- `arith.maxnumf`: NaN selection and signed-zero behavior;
- `exp` and `log`: correctly rounded versus device approximation profile;
- floating division: host IEEE behavior versus target approximation;
- `hfusion.cast`: ties, overflow, subnormals, infinities, and NaNs.

These choices should live in a `NumericProfile`, not be hidden in operator
implementations. The exact profile is a claim to validate against Ascend
hardware and compiler behavior.

## State Capabilities

Most linalg/tensor operators are pure and need only typed values plus a numeric
profile. Stateful operations can be factored into small interfaces:

```text
memref.alloc                 : Allocator * Memory -> descriptor * Allocator * Memory
memref.reinterpret_cast      : DescriptorStore -> descriptor * DescriptorStore
memref.copy                  : DescriptorStore * Memory -> unit * Memory * events
materialize_in_destination   : DescriptorStore * Memory -> unit * Memory * events
```

A unified HFusion state can combine these components through lawful lenses or
type-class capabilities. Each instruction implementation declares the
components it reads and writes, allowing the same semantics to run in a larger
future HIVM state without modification.

## Events at This Level

Events are useful but mostly observational at HFusion:

- function and loop iteration boundaries;
- allocation and descriptor creation;
- memory read/write ranges and view metadata;
- matmul and reduction boundaries, including accumulator policy;
- transcendental and cast precision boundaries;
- source-location/provenance links where compiler metadata is available.

The history is not needed to determine ordinary HFusion arithmetic. It is
needed to explain the first point where two executions diverge and to connect
that value to a lowering decision.

## Deliberately Deferred to HIVM

The current artifact does not justify implementing the following as HFusion
semantics:

- physical GM/UB/L1 address spaces and capacity constraints;
- asynchronous DMA issue/completion and pipeline queues;
- flags, waits, barriers, and cross-core synchronization;
- weak-memory or nondeterministic scheduling behavior;
- instruction timing and overlap.

The presence of entry arguments for a sync block lock and workspace does not by
itself imply that this specialized function uses their low-level semantics.
These features belong in the next HIVM milestone, where event order becomes
part of the execution semantics rather than only a debugging trace.

## Implementation Order

1. **P0: exact artifact.** Parse or adapt all operations above, execute the
   fixed `f16`, non-causal `128 x 128` instance, and compare both output and
   log-sum-exp with a trusted reference.
2. **P1: source variants.** Generalize shapes and element types and add causal masking,
   which will require the corresponding selection/slicing operations emitted
   by the compiler.
3. **P2: broader HFusion.** Inventory the official dialect definition and add
   operations only with a sourced kernel or compiler artifact as a test.

P0 is complete only when a report can identify the first differing operation
under alternative matmul, reduction, transcendental, and cast profiles. A final
numeric match without intermediate attribution is not sufficient for the
precision-debugging use case.
