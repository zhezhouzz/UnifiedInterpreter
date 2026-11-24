### Environment

Ascend960, AscendNPU-IR v2 pipeline, CANN 9.2.0.

### Reproduction and observed result

Run `training/test_chunk_gated_delta_rule_bwd_dhu_kernel_case2.py` on the CANN model. On master `6674d03a8d`, 512 of 1,024 `dh` values are infinite. The incoming loop buffer and a newly filled destination both receive UB offset 34816 before the final read of the incoming value.

The first difference in the IR after each pass is local PlanMemory (dump 449). With only commit `7240264d51` added to master, the incoming buffer moves to offset 51200. The new contents are copied after the final old-value read and before the yield. All three original comparisons pass with `atol=rtol=0.01`.

[Compiler comparison in !5336](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5336?ref=&did=37784934ddae66e3c56e7c4024a7a500e35f582c#tid-202319596) · [Regression evidence (ZIP)](https://raw.gitcode.com/Ascend/AscendNPU-IR/attachment/uploads/7501f4a8-8c8b-4aac-9a90-44d2fc741b19/07-plan-memory-7240264d51.zip)