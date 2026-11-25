### Environment

Ascend960, AscendNPU-IR v2 pipeline, CANN 9.2.0.

### Reproduction and observed result

Compile `recommendation/test_fbgemm_grouped_gemm_fp8_rowwise.py` for A6. The cube template selects `mad_mx` for an ordinary FP8 pair even though the operation supplies no scales. The unscaled path should emit `mad`. Explicitly microscaled operations should emit `mad_mx`.

With only the FP8 change removed from the combined build, all 128 rowwise outputs failed the original CANN model comparison (maximum absolute error 0.543890, `atol=0.0003`, `rtol=0.003`). Both the rowwise and workspace originals passed with the fix present.

[Compiler comparison in !5331](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5331?ref=&did=07432d2a41403fb88082d972a93b9a732cc14ed5#tid-202318103) · [Regression evidence (ZIP)](https://raw.gitcode.com/Ascend/AscendNPU-IR/attachment/uploads/3dc95c36-5d6c-4fca-babb-199eae28f939/02-cube-fp8-5ba46fddf9.zip)