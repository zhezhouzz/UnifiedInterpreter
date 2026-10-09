# AscendNPU-IR Reference Snapshot

This is a selective, revision-pinned archive from
<https://github.com/Ascend/AscendNPU-IR> at commit
`22e3d51df4642fb0f74060af36f5c5c80be80d08` (2026-10-09).

The snapshot contains:

- all Chinese documentation under `docs/source/zh_cn`;
- architecture and developer-guide images referenced by that documentation;
- TableGen/YAML definitions for the HACC, HFusion, and HIVM dialects;
- pass and pipeline declarations for those three stages.

Files retain their upstream paths beneath `upstream/`. This is reference
material, not vendored build input. Update it only by choosing a new explicit
upstream commit and regenerating the snapshot and checksums.

Useful starting points:

- `upstream/docs/source/zh_cn/introduction/architecture.md`
- `upstream/docs/source/zh_cn/developer_guide/dialects/hfusion_dialect.md`
- `upstream/docs/source/zh_cn/developer_guide/dialects/hivm_dialect.md`
- `upstream/docs/source/zh_cn/developer_guide/features/hfusion_auto_schedule.md`
- `upstream/bishengir/include/bishengir/Dialect/HFusion/IR/HFusionOps.td`
- `upstream/bishengir/include/bishengir/Dialect/HIVM/IR/HIVMSynchronizationOps.td`

`SHA256SUMS` covers every file beneath `upstream/`.
