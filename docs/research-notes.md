# Research Discussion Archive

## Objective

The project aims to give AscendNPU IR an executable semantic model that can run
mixed-stage programs on a CPU. A program may explicitly place regions beneath
different handlers, so high-level operations can be interpreted by lowering
them while an adjacent region is already low-level IR. The immediate target is
the HFusion output of FlashAttention; HIVM is the next stage.

The intended H1-H5 model is a nested, non-overlapping handler stack. A handler
owns only the operations of its stage. Operations belonging to a lower stage
escape outward, while lowering a high-level operation may itself issue effects
that are handled by a lower stage. This makes each high-level handler a small,
dynamic compiler and leaves H5 as the final machine interpreter.

## Semantic Shape

The base design is state-based small-step execution. During the current
HFusion milestone, instructions cannot inspect an event history:

```text
(instruction, local state) -> success(result, updated local state) | fault
```

An atomic fault exposes no partially updated state. At HFusion, most computation
is deterministic tensor and buffer state transformation. A future observer may
record provenance, allocation, reads, and writes, but that observation is not
part of instruction input. At HIVM, asynchronous copies, queues, waits, and
barriers will first be represented as explicit machine state; an emitted trace
can then record their externally observable order.

## Composable State in Rocq

Avoid defining every instruction directly over one ever-growing record.
Instruction semantics should instead require small capabilities, such as a
memory store, descriptor store, allocator, queue state, or numerical profile.
A unified machine state supplies lawful getter/setter lenses for those
capabilities, and generic lifting embeds a local transition into that state.

The engineering obligations are as important as the getters:

- get-after-put and put-after-get laws;
- independence laws for disjoint components;
- explicit read and write sets for each instruction;
- preservation of untouched state (a frame property);
- separation of executable state from ghost/proof-only state.

This is component-level engineering modularity, not Iris-style ownership or a
separation logic. Within memory, dynamic allocations and descriptors use stdpp
finite maps. Lookup/insert locality theorems state directly that updating one
allocation does not affect a different key. A resource algebra should only be
introduced later if ownership transfer or concurrent frame reasoning actually
requires it.

## Lessons from Related Implementations

- Kuiper uses F*/Pulse resources to modularize ownership and separates ghost
  reasoning from extracted runtime code. Its restrictions warn us not to make
  the executable semantics depend on one proof logic's expressiveness.
- SIMT-Step uses executable TLA+ global states and selectable model profiles.
  Its frontend-generated program modules are a useful validation pattern.
- Tensor-core SMT work represents competing numerical behaviors as solver
  models, then generates inputs that distinguish those models on hardware.
- Weft reduces GPU synchronization to a sliced operational model, showing that
  a purpose-specific semantics need not model unrelated hardware detail.
- GPUCSL and the PTX memory-model work show two different roles for proof
  assistants: program logic on top of a semantics, and mechanization of a
  candidate hardware model discovered through litmus tests.

## Validation Strategy

The semantic model should be treated as a hypothesis about hardware, not as
correct merely because it is formal. Validate pure numerical operators with
differential tests against PyTorch, Triton-Ascend, and hardware results. Use
litmus-style kernels to distinguish ordering and synchronization alternatives.
For imprecise arithmetic, use SMT-generated discriminating inputs where useful.
Every archived compiler artifact must record its source, compiler revision,
shape, element type, and launch configuration.
