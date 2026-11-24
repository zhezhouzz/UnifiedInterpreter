### Environment

Ascend960, AscendNPU-IR v2 pipeline, CANN 9.2.0.

### Reproduction and observed result

In the gated case of `inference/test_chunk_gated_delta_rule_fwd_kernel_hupdate_blockdim64.py`, a scalar initializer for a fresh AIV-private buffer also runs on the cube core. That extra store races with the vector-core scalar reload.

On the Rust simulator, removing only the private-input change put 5,480 of 24,576 output values outside `atol=rtol=0.05`. Restoring it gave zero mismatches on the same inputs (maximum absolute error 0.0319). The gated and ungated originals also passed on the CANN whole-device model with the combined build.

[Compiler comparison in !5337](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5337?ref=&did=6e72816ce34c7b074975918ed937bd3f874e7945#tid-202318585) · [Regression evidence (ZIP)](https://raw.gitcode.com/Ascend/AscendNPU-IR/attachment/uploads/0070f5d9-6337-4041-ad26-693808338f86/08-private-vector-input-b48ced476f.zip)