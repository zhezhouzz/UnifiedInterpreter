## 中文

### 需求

A2 和 A3 同属 `Dav_C220` 架构。编译器应根据 Cube 与 Vector 是否分核，为这两类设备上受支持的矩阵乘默认启用 Cube 布局优化。用户仍可通过 `--enable-layout-optimization=false` 关闭优化。

基于内存的流水线应先按 ND 布局对矩阵乘分块，再转换 A、B 的布局。连续 MMAD 复用累加结果时，应将其保留在 L0C。A5 的现有 pass 顺序作为回归对照。

### 验收

验证 A2 在默认和显式关闭两种设置下均可编译，在 A3 真机上验证对应的数值结果，并对照 A5 的 pass 顺序和生成的设备代码。

模块跟踪 #605。A3 普通矩阵乘的布局转换见 #627。本 issue 跟踪 A2 和 A3 的默认启用及验证。实现见 [!5285](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5285)。

## English

### Request

A2 and A3 share the `Dav_C220` architecture. The compiler should use the target’s separate Cube and Vector cores to select packed layouts by default for supported matmuls. Users can opt out with `--enable-layout-optimization=false`.

The memory-based pipeline should tile matmuls in ND before packing operands A and B. Consecutive MMADs that reuse an accumulator should keep it in L0C. The existing A5 pass order provides a regression control.

### Acceptance criteria

Compile for A2 with the default and with layout optimization disabled. Check numerical results on physical A3 and compare the A5 pass order and generated device code against the baseline.

The module tracker is #605. Issue #627 covers layout conversion for ordinary A3 matmuls. This issue tracks enabling and validating the default on A2 and A3. [Implementation !5285](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5285)