### Environment

Ascend960, AscendNPU-IR v2 pipeline, CANN 9.2.0.

### Reproduction and observed result

Two rejection-sampling kernels exercise separate device-codegen failures. `inference/test_rejection_random_sample_kernel.py` emits an unsupported scalar i64 select in a vector function. `inference/test_rejection_greedy_sample_spec_len_1_triton.py` emits an integer shuffle declaration with a suffix that does not match the CANN intrinsic.

Removing the respective change reproduces each compilation failure independently. On the combined build, both original tests compiled and passed their accept and reject comparisons on the CANN model.

[Compiler comparison in !5333](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5333?ref=&did=bfcadd943baebb078ba3365dc581dafb4be0bf83#tid-202318299) · [Regression evidence (ZIP)](https://raw.gitcode.com/Ascend/AscendNPU-IR/attachment/uploads/f74405d7-6e12-452d-9831-04b01474b3d0/04-integer-codegen-072e232418.zip)