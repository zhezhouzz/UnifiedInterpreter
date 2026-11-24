### Environment

Ascend960, AscendNPU-IR v2 pipeline, CANN 9.2.0.

### Reproduction and observed result

Run `training/test_chunk_global_cumsum.py` with the A6 v2 pipeline. Four specializations complete. CANN reports an LLVM out-of-memory error while compiling the reverse vector scan. Its descending address induction is the trigger for device auto-sync.

Traversing independent writes within each stage in ascending address order preserves the order of additions. With that change in the combined build, all five original numerical comparisons passed on the CANN model.

[Compiler comparison in !5332](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5332?ref=&did=e064430b960affeb19098cba9169b4cd8968dd9e#tid-202318222) · [Regression evidence (ZIP)](https://raw.gitcode.com/Ascend/AscendNPU-IR/attachment/uploads/e1cac99e-ec16-4a17-893a-6d6ebe596b27/03-reverse-cumsum-a153a0fea2.zip)