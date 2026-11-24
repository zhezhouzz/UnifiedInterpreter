## Problem

The HIVM v2 pipeline runs the intra-core and cross-core graph synchronization solvers with default settings. As a result, the compiler driver's auto-sync controls are ignored.

## Expected behavior

The v2 pipeline should honor the driver's independent intra-core and cross-core disable flags, solver version, intra-core unit-flag mode, and barrier-all and block-all modes. Disable flags should take precedence over the corresponding all-sync modes. Cross-core synchronization should run once before kernel splitting.

## Validation

PR #5074 reports that the focused v2 tests passed. Regression coverage includes driver and pipeline option propagation and emitted IR for the default and all-sync modes and disable-flag precedence.

Resolved by [AscendNPU-IR PR #5074](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5074).
