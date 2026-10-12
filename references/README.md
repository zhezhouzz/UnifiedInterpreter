# Paper Archive

This directory archives the papers that motivated the UnifiedInterpreter
design discussion. `papers/SHA256SUMS` records the exact local copies.

| Local file | Work | Why it is here |
| --- | --- | --- |
| `papers/reynolds-definitional-interpreters.pdf` | Reynolds, *Definitional Interpreters for Higher-Order Programming Languages* | Interpreters as semantic definitions; the historical starting point for deriving evaluators. |
| `papers/futamura-projections.pdf` | Futamura projections survey/material | Relates interpreters, specialization, compilers, and compiler generators. |
| `papers/kuiper-pldi2026.pdf` | *Kuiper* | A recent GPU verification design using modular resources and F*/Pulse; useful for understanding both expressiveness limits and proof engineering. |
| `papers/weft-producer-consumer-pldi2015.pdf` | *Weft* | Operational reasoning for GPU producer-consumer synchronization and named barriers. |
| `papers/simt-step-pldi2026.pdf` | *SIMT-Step* | Executable state-machine models and hardware validation for modern SIMT behavior. |
| `papers/tensor-core-smt-nfm2025.pdf` | Tensor-core SMT modeling | Builds candidate numerical models and distinguishes them with generated inputs and hardware observations. |
| `papers/gpucsl-coq-2016.pdf` | GPUCSL | Coq formalization of GPU program reasoning. |
| `papers/simt-correctness-2012.pdf` | SIMT correctness | Earlier formal account of SIMT execution. |
| `papers/ptx-memory-model-asplos2019.pdf` | PTX memory consistency model | Litmus tests, Alloy exploration, and mechanized reasoning for GPU memory ordering. |
| `papers/gpu-ila-iccad2018.pdf` | GPU ILA | Instruction-level abstraction for GPU hardware semantics and validation. |
| `papers/vellvm-popl2012.pdf` | Zhao et al., *Formalizing the LLVM Intermediate Representation for Verified Program Transformations* | The original Vellvm design: mechanized LLVM syntax, static and dynamic semantics, executable validation, and verified SSA transformations. |

The archive was assembled on 2026-10-09. It is a research snapshot, not a
claim that these are the latest available revisions.

For Vellvm, the archived paper describes the original 2012 development.  The
modern project has since moved to interaction/choice trees, layered event
handlers, and a refinement proof from its executable interpreter to an
abstract nondeterministic specification.  See `docs/vellvm-lessons.md` for the
version distinction and its relevance to this project.
