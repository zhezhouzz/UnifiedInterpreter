## Problem

The HIVM v2 compiler pipeline can abort during cross-core graph synchronization when a scalar load from global memory has no unambiguous core type. This prevents affected A6 mixed-core kernels from compiling.

## Trigger

In an A6 mixed-core kernel, read a scalar from a global-memory buffer with `memref.load` through a `memref.reinterpret_cast`. Use the result only in core-neutral operations, such as a loop bound, an `scf.if` condition, or a subview extent. Compile the kernel with the HIVM v2 pipeline.

## Actual behavior

The load can reach `hivm-cross-core-gss` with core type `CUBE_OR_VECTOR`. The sync solver's IR translator aborts on the assertion `coreType.value() != hivm::TCoreType::CUBE_OR_VECTOR`.

## Expected behavior

Cross-core synchronization should handle scalar global-memory loads used by core-neutral operations and let compilation continue without an assertion.
