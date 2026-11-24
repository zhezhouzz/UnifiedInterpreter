### 💻 需求背景、当前现状、期望实现的功能内容、具体的设计方案、以及测试方案
            
## 1. Background and Scope

BISHENG-CCE already provides HiFloat8 types and hardware support in the target toolchain. This proposal extends the upper layers of Triton Ascend and AscendNPU-IR, using the existing E4M3 FP8 path as a reference, so that HiFloat8 can flow through the DSL, MLIR, and native LLVM IR to an Ascend binary.

The scope covers a distinct data type, load/store/copy, floating-point conversions, RTA/Hybrid rounding, and dot operations with HiFloat8 inputs and FP32 accumulation.

## 2. Architecture

```text
Triton DSL: tl.hifloat8
          |
triton-ascend + frontend LLVM/MLIR
          | MLIR: f8HIF
AscendNPU-IR + backend LLVM/MLIR
          | Native LLVM IR: hifloat8
BISHENG-CCE
          |
Ascend binary
```

Compilation proceeds from top to bottom. Implementation proceeds from bottom to top: establish the lower-level type and operation support first, then expose the DSL entry points.

## 3. Bottom-Up Implementation Order

| Step | Layer | Main Work | Capability Provided to the Upper Layer |
|---|---|---|---|
| 1 | CCE interface contract | Confirm the existing type, conversion, rounding, and matrix interfaces | The type and operation contracts that upper layers must follow |
| 2A | Native types in backend LLVM | Add HiFloat8 types, storage size and alignment rules, LLVM IR text/bitcode support, and target interface definitions | Native HiFloat8 LLVM IR that CCE can consume |
| 2B | Types in backend MLIR | Define `f8HIF`, type constraints, and mappings to native LLVM types | A distinct HiFloat8 type for AscendNPU-IR |
| 3 | AscendNPU-IR operations | Build on step 2 to support data movement, casts, dot, templates, and the required optimization rules | Lowering of HiFloat8 tensor operations to the CCE interfaces |
| 4 | Types in frontend LLVM/MLIR | Define frontend `f8HIF` and preserve compatible types and attributes across the tool boundary | HiFloat8 MLIR that Triton can construct and pass to the backend |
| 5 | triton-ascend | Build on step 4 to expose the dtype, signatures, and DSL semantics, and generate operations supported by step 3 | HiFloat8 support in Triton kernels |

## 4. Key Design Principles

- **Distinct numerical semantics:** preserve HiFloat8 as an independent type rather than interpreting its values as E4M3 or integers.
- **Reuse existing lower-level support:** use CCE conversion and matrix interfaces; upper layers handle type integration, semantic mapping, and operation lowering.
- **Preserve conversion semantics:** map rounding modes explicitly, distinguish bitwise transfers from numerical conversions, and prevent optimizations from incorrectly removing target conversions.

## 5. Core Design

### 5.1 Types and Cross-Layer Representation

Use `tl.hifloat8` in the DSL, `f8HIF` in MLIR, and `hifloat8` in native LLVM IR. Both frontend and backend need type definitions and mappings. Compatible text or bytecode serialization must preserve the types and operation attributes across their boundary.

### 5.2 Numerical Conversions

The initial implementation uses FP32 as the common conversion path to reduce the number of distinct upper-layer lowering paths.

| Type Pair | Conversion Path |
|---|---|
| HiFloat8 ↔ FP32 | Use CCE conversions directly |
| HiFloat8 ↔ FP16 | Initially via FP32; prioritize the existing direct CCE interfaces as a follow-up |
| HiFloat8 ↔ BF16, E4M3FN, E5M2 | Via FP32 |
| HiFloat8 → HiFloat8 | Identity |

The FP32 intermediate for FP16 is an initial implementation choice, not a hardware restriction. Direct CCE FP16↔HiFloat8 interfaces can reduce intermediate conversions and temporary values. They require additional upper-layer lowering and checks for rounding, saturation, and special values; this direct path is not yet integrated and validated in the upper layers of the experiment.

Conversions to HiFloat8 default to RTA (Round to Nearest, Ties Away from Zero), with explicit RTA and Hybrid rounding also supported. Hybrid uses hardware-defined threshold rules to determine whether to round up the retained magnitude. Rounding attributes are mapped explicitly across layers, and invalid combinations are rejected by the frontend.

### 5.3 Data Movement and Constants

Reuse 8-bit storage paths for load/store, copy, and required layout transformations while preserving the HiFloat8 bit patterns. Construct tensor constants in FP32 before converting them to HiFloat8. Use the corresponding zero bit pattern for zero padding, and avoid unsupported software floating-point folding or scalarization.

### 5.4 Matrix Operations

Dot takes two native HiFloat8 inputs and accumulates and produces results in FP32. Upper layers provide the type constraints, input layouts, and template selection needed to use the existing CCE HiFloat8 matrix interfaces.

## 6. Existing CCE Interfaces and Key ISA Definitions

### 6.1 Existing Capabilities

| Capability | Definition and Integration |
|---|---|
| Distinct type | CCE provides the builtin type `__hif8` and its alias `hifloat8_t`; native LLVM IR uses `hifloat8`. Its numerical encoding differs from E4M3/E5M2. |
| Numerical conversions | FP32↔HiFloat8 and FP16↔HiFloat8 vector interfaces already exist. The initial implementation reuses the FP32 path, with direct FP16 conversion planned as a follow-up. |
| Rounding on conversion to HiFloat8 | The CCE FP32→HiFloat8 vector conversion interface uses the `rnd` rounding-mode parameter: `rnd=1` for RTA and `rnd=6` for Hybrid. Upper layers must map these values explicitly. |
| Data movement and quantization | 8-bit input loading is supported. FIXPIPE output quantization has separate rounding and layout rules and is handled separately from ordinary vector casts and stores. |

### 6.2 Dot Input and Output Formats

| Item | Format |
|---|---|
| Matrix A/B inputs | Native HiFloat8, loaded into L0A/L0B with their original bit patterns |
| Accumulation and output | FP32, with the result in L0C |

The CCE HiFloat8 matrix interface makes the Cube unit interpret the inputs as HiFloat8. It does not require converting those inputs to another floating-point format before matrix multiplication.

## 7. Estimated Change Scope

| Item | Estimate or Main Differences |
|---|---|
| E4M3 FP8 reference footprint | Within the reviewed integration scope, **70 files already contain E4M3-related implementations**, spanning types, IR, lowering, and templates. |
| Main differences for HiFloat8 | A distinct numerical encoding and native type; RTA/Hybrid rounding mappings; no general HiFloat8 APFloat implementation in the initial design, requiring safeguards for constant folding and optimization paths; a HiFloat8 mode for matrix operations. |
| Estimated HiFloat8 changes | Assuming existing CCE support and separate frontend/backend LLVM/MLIR dependencies, approximately **70–90 functional source files**, covering types, data movement, casts, rounding, and dot. |

## 8. Additional Context: The Two LLVM/MLIR Dependencies

| Component | Version in the Current Setup | User and Responsibility |
|---|---|---|
| Frontend LLVM/MLIR | LLVM 22 | Used by triton-ascend for frontend types and IR infrastructure, producing MLIR containing `f8HIF` |
| Backend LLVM/MLIR | Ascend LLVM 19 | Used by AscendNPU-IR for backend lowering and generation of native LLVM IR containing `hifloat8` |
| CCE compiler | Provided with CANN | Consumes the lower-level input and performs target instruction selection and machine-code generation |

Both frontend and backend contain LLVM and MLIR and link against their own libraries, so both must support `f8HIF`. The two versions reflect the current dependency setup rather than an inherent requirement of HiFloat8. Final machine code is generated by CCE.
### 替代方案
            

### 补充说明
            

