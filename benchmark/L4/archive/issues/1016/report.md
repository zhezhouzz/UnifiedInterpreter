### Environment

Ascend960, AscendNPU-IR v2 pipeline, CANN 9.2.0.

### Reproduction and observed result

Launch `inference/test_clear_ssm_states_kernel.py` with a logical grid larger than the physical core count. The v2 pipeline drops the blockify option, so programs beyond the first physical wave never clear their assigned states.

The original exact comparison fails on the pre-fix CANN model. With blockification enabled in the corrected pipeline, the same test passes. The regression in `hivm-v2-blockify.mlir` also covers the direct launch when the grid fits.

[Compiler comparison in !5330](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5330?ref=&did=7f80d296ec8c14c30cf946730bc9088f1e3a20ee#tid-202318048) · [Regression evidence (ZIP)](https://raw.gitcode.com/Ascend/AscendNPU-IR/attachment/uploads/264d7dce-3f84-4d11-b6ab-e339e644a49d/01-grid-e92e0083d7.zip)