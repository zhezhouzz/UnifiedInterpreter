### Environment

Ascend960, AscendNPU-IR v2 pipeline, CANN 9.2.0.

### Reproduction and observed result

On the CANN model, `training/test_chunk_bwd_dqkwg_kernel_case1.py` stops at `RV_VSTAI` with `addr_tail < Ust.valid_data_size`. A packed predicate store writes beyond the active tail. In `training/test_causal_conv1d_bwd_kernel.py`, the input gradient passes but 60 of 64 weight gradients are infinite.

Both failures were reproduced with just the vector-store MR removed from the combined build. With the MR included, DQKWG passed both comparisons and causal convolution passed its input, weight and bias gradient checks. The fixtures exercise short predicate rows, transposed destinations and strided stores.

[Compiler comparison in !5335](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5335?ref=&did=5b0a421ebf57082bc9dac55e1e818d50d782b4c9#tid-202318459) · [Regression evidence (ZIP)](https://raw.gitcode.com/Ascend/AscendNPU-IR/attachment/uploads/1ac0238d-1486-47f5-938e-8486ffe19ba5/06-vector-stores-5a4c18f329.zip)