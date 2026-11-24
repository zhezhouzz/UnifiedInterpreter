### 环境信息
            
```
例如：
- Operating system: <OS and version>
- Ascend hardware information: Ascend950PR_9579 (regbase)
- CANN software version: <CANN version>
- bishengir-compile: <version / commit>
```

### 🐛 问题描述
            
### Summary

`hivm.hir.custom` operations that lower the atomic intrinsics (`__builtin_indirect_atomic`, including its `_soft_`, `_block_` and `_cas` library variants) mutate a GM buffer that is passed as a **regular input operand**, not as a DPS init/output. As a result these ops do not honour Destination-Passing Style: their `DestinationStyleOpInterface` contract claims that only the declared `outs` operands are written, while the actually mutated GM buffer is one of the `ins` operands.

Any analysis that derives read/written memory from `DestinationStyleOpInterface` therefore classifies the atomic destination as **read-only** and misses the write. Dependencies before and after the atomic operation are dropped, which produces under-synchronized (incorrect) code.

### Affected scenario

A Triton kernel that performs an indirect atomic add on a GM buffer and later reloads the same buffer. The atomic destination `%atomic_dst` is forwarded to the `hivm.hir.custom` op as its first input, and its index is recorded in the `gm_addr_args_indices` attribute (here `{0}`), which is how the compiler tracks the GM address arguments of builtin CustomOps.

The most visible consequence is in GraphSyncSolver: it emits no pipe event between the atomic add and the following load of `%atomic_dst`, so the load can observe stale data.

### Minimal reproducible example

`repro.mlir` (reduced from `bishengir/test/Dialect/HIVM/SyncSolver/hivm-gss-indirect-atomic-add.mlir`):

```mlir
module attributes {hacc.target = #hacc.target<"Ascend950PR_9579">} {
  func.func @indirect_atomic_add_read_modify_write(
      %src: memref<16xf32, #hivm.address_space<gm>>,
      %atomic_dst: memref<16xf32, #hivm.address_space<gm>>,
      %offsets: memref<16xi64, #hivm.address_space<ub>>,
      %mask: memref<16xi8, #hivm.address_space<ub>>,
      %result: memref<16xf32, #hivm.address_space<gm>>)
      attributes {hacc.entry,
                  hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %c0_i64 = arith.constant 0 : i64
    %value = hivm.hir.pointer_cast(%c0_i64) :
      memref<16xf32, #hivm.address_space<ub>>
    %atomic_out = hivm.hir.pointer_cast(%c0_i64) :
      memref<16xf32, #hivm.address_space<ub>>
    %reloaded = hivm.hir.pointer_cast(%c0_i64) :
      memref<16xf32, #hivm.address_space<ub>>

    hivm.hir.load ins(%src : memref<16xf32, #hivm.address_space<gm>>)
      outs(%value : memref<16xf32, #hivm.address_space<ub>>)

    hivm.hir.custom {extra_attr = "operate=add",
                     gm_addr_args_indices = array<i32: 0>,
                     hivm.pipe = #hivm.pipe<PIPE_V>,
                     hivm.tcore_type = #hivm.tcore_type<VECTOR>,
                     hivm.vf_mode = #hivm.vf_mode<SIMT>,
                     symbol = "__builtin_indirect_atomic"}
        "__builtin_indirect_atomic"
        ins(%atomic_dst, %offsets, %value, %mask :
            memref<16xf32, #hivm.address_space<gm>>,
            memref<16xi64, #hivm.address_space<ub>>,
            memref<16xf32, #hivm.address_space<ub>>,
            memref<16xi8, #hivm.address_space<ub>>)
        outs(%atomic_out : memref<16xf32, #hivm.address_space<ub>>)

    hivm.hir.load ins(%atomic_dst : memref<16xf32, #hivm.address_space<gm>>)
      outs(%reloaded : memref<16xf32, #hivm.address_space<ub>>)

    hivm.hir.store ins(%reloaded : memref<16xf32, #hivm.address_space<ub>>)
      outs(%result : memref<16xf32, #hivm.address_space<gm>>)
    return
  }
}
```

Reproduce with:

```bash
bishengir-opt -hivm-graph-sync-solver=solver-version=v1 repro.mlir
bishengir-opt -hivm-graph-sync-solver=solver-version=v2 repro.mlir
```

### Actual behavior

`%atomic_dst` is treated as read-only by the solver. No synchronization is inserted between the atomic add and the subsequent `hivm.hir.load`, so the load may read the buffer before the atomic write has landed:

```mlir
hivm.hir.custom {gm_addr_args_indices = array<i32: 0>, ...}
    "__builtin_indirect_atomic"
    ins(%atomic_dst, %offsets, %value, %mask : ...)
    outs(%atomic_out : memref<16xf32, #hivm.address_space<ub>>)

// Incorrect: no set_flag / wait_flag here

hivm.hir.load ins(%atomic_dst : memref<16xf32, #hivm.address_space<gm>>)
  outs(%reloaded : memref<16xf32, #hivm.address_space<ub>>)
```

### Expected behavior

The atomic destination must be modelled as a **read-modify-write** memory operand. Synchronization must be emitted both before and after the atomic operation:

```mlir
hivm.hir.load ins(%src : memref<16xf32, #hivm.address_space<gm>>)
  outs(%value : memref<16xf32, #hivm.address_space<ub>>)

hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]

hivm.hir.custom {gm_addr_args_indices = array<i32: 0>, ...}
    "__builtin_indirect_atomic"
    ins(%atomic_dst, %offsets, %value, %mask : ...)
    outs(%atomic_out : memref<16xf32, #hivm.address_space<ub>>)

hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]

hivm.hir.load ins(%atomic_dst : memref<16xf32, #hivm.address_space<gm>>)
  outs(%reloaded : memref<16xf32, #hivm.address_space<ub>>)
```

### Root cause

`hivm::CustomOp` implements `DestinationStyleOpInterface` by mapping its DPS inits to the declared outputs:

```cpp
// bishengir/include/bishengir/Dialect/HIVM/IR/HIVMOps.td
::mlir::MutableOperandRange getDpsInitsMutable() {
    return getOutputsMutable();
}
```

For an atomic builtin, the mutated GM buffer is `inputs[0]` (as recorded by `gm_addr_args_indices = array<i32: 0>`), while the `outs` operand (`%atomic_out`) is a separate UB buffer. The interface therefore reports:

- DPS inputs (reads): `%atomic_dst`, `%offsets`, `%value`, `%mask`
- DPS inits (writes): `%atomic_out`

which is wrong for `%atomic_dst` — the atomic add updates `atomic_dst[offset]`. `gm_addr_args_indices` is currently the only place that records the real GM destination, but it is an op-specific attribute, not part of the DPS contract, so generic DPS consumers do not see it.

Consumers known to be affected:

- `IRTranslator::getReadWriteMemoryOps`   (`GraphSyncSolver/SyncSolverIRTranslator.cpp`), which builds the read/write   sets used for pipe-event inference.
- Bufferization (`BufferizableOpInterfaceImpl.cpp`), which derives in-place   input/output bindings from DPS.
- Any side-effect, alias or scheduling analysis that assumes DPS `outs` are the only written buffers.

### Current workaround (incomplete)

Commit `6cc093bb` (merge request !3512) patches a single consumer:
`IRTranslator::getReadWriteMemoryOps()` now special-cases `__builtin_indirect_atomic` and adds the `gm_addr_args_indices` operands to the write set:

```cpp
if (auto customOp = dyn_cast<hivm::CustomOp>(op);
    customOp &&
    customOp.getName() == hivm::CustomOp::kBuiltinIndirectAtomicName) {
  if (auto gmAddrArgsIndices = customOp.getGMAddrArgsIndices()) {
    // ... add inputs listed by gm_addr_args_indices to writeMemVals ...
  }
}
```

This fixes GraphSyncSolver only. The IR remains DPS-incorrect, so every other DPS-based analysis still misclassifies the atomic destination, and the workaround has to be duplicated for each new atomic builtin and each new consumer.

### Suggested fix

Model the atomic destination as a first-class read-write operand instead of relying on `gm_addr_args_indices`:

- Represent the mutated GM buffer as a DPS init/output (or as an explicit in-place binding via `inplace_outs`) so that `DestinationStyleOpInterface` describes the real write, **or**
- Introduce a proper interface/attribute (e.g. a read-write operand interface) that DPS-based analyses can query generically, and make all consumers use it.

Once the IR describes the read-modify-write correctly, the local `SyncSolverIRTranslator` special case can be removed.

### Testing

`bishengir/test/Dialect/HIVM/SyncSolver/hivm-gss-indirect-atomic-add.mlir` covers the workaround for both solver V1 and V2. A proper fix should extend it to the other atomic variants (`_soft_`, `_block_`, `_cas`) and add coverage for the other DPS-based consumers.

---

Welcome to the community, and thank you for your contribution to the community 🎉!
