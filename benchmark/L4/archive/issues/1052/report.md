Related Triton-Ascend issue: [triton-lang/triton-ascend#2646](https://github.com/triton-lang/triton-ascend/issues/2646)

[Feature]: Can FP32 reduce_sum on Ascend 910B4 match PyTorch eager more closely for row-weight gradients?

## Describe the issue

DeepSpeed's `row_weighting` backward kernel computes one weight gradient per row. For a row of 2,048 elements, it converts the BF16 or FP16 inputs to FP32, multiplies them, and reduces the products in two kernel launches. The first writes one FP32 partial sum per 512 elements. The second sums the four partials. PyTorch eager computes `(upstream.float() * rows.float()).sum(dim=-1, keepdim=True)` over the whole row.

On 910B4, the maximum absolute difference across 4,096 rows is `2.288818e-5` for BF16 input and `3.051758e-5` for FP16 input. The upstream reporter observed agreement on CUDA and asked whether Ascend's reduction order could be improved. The figures below are from our 910B4 run. [Triton-Ascend #2646](https://github.com/triton-lang/triton-ascend/issues/2646)

**Request.** With the two kernel launches and the four FP32 partials retained, is there an existing NPU-IR option or a feasible change to the SIMD reduction that would bring `max(abs(fused - eager))` to **≤ 1e-5 on these fixed inputs**? This is a proposed target for this case. If agreement also requires changing how the caller splits the row, we'd like to know which grouping the caller should use. A candidate can be evaluated on the same inputs against both eager and CPU FP64.

## Minimal reproduction

In a fresh working directory, save the following as `repro_2646.py`. It includes both kernels, keeps the upstream random draw order (rows, weights, upstream gradient), and uses logical device `npu:0`. On a 910B4 with the CANN environment loaded, run `python3 repro_2646.py`. It prints all four test cases and writes the compiler inputs and device binaries for the large shape into `ir_2646/`.

<details>
<summary>Complete single-file Python reproducer</summary>

```python
import math
from pathlib import Path

import torch
import torch_npu
import triton
import triton.language as tl


@triton.jit
def _bwd_partial(grad_out_ptr, rows_ptr, weights_ptr, grad_rows_ptr, partials_ptr, hidden,
                 grad_out_stride, rows_stride, weights_stride, grad_rows_stride,
                 num_hidden_blocks: tl.constexpr, BLOCK_H: tl.constexpr):
    row = tl.program_id(0).to(tl.int64)
    hidden_block = tl.program_id(1)
    hidden_offsets = hidden_block * BLOCK_H + tl.arange(0, BLOCK_H)
    hidden_mask = hidden_offsets < hidden

    upstream = tl.load(grad_out_ptr + row * grad_out_stride + hidden_offsets,
                       mask=hidden_mask, other=0.0).to(tl.float32)
    values = tl.load(rows_ptr + row * rows_stride + hidden_offsets,
                     mask=hidden_mask, other=0.0).to(tl.float32)
    weight = tl.load(weights_ptr + row * weights_stride).to(tl.float32)

    tl.store(grad_rows_ptr + row * grad_rows_stride + hidden_offsets,
             (upstream * weight).to(grad_rows_ptr.dtype.element_ty), mask=hidden_mask)
    partial = tl.sum(upstream * values, axis=0)
    tl.store(partials_ptr + row * num_hidden_blocks + hidden_block, partial)


@triton.jit
def _bwd_reduce(partials_ptr, grad_weights_ptr, grad_weights_stride,
                NUM_HIDDEN_BLOCKS: tl.constexpr, BLOCK_B: tl.constexpr):
    row = tl.program_id(0).to(tl.int64)
    offsets = tl.arange(0, BLOCK_B)
    mask = offsets < NUM_HIDDEN_BLOCKS
    partials = tl.load(partials_ptr + row * NUM_HIDDEN_BLOCKS + offsets, mask=mask, other=0.0)
    grad_weight = tl.sum(partials, axis=0)
    tl.store(grad_weights_ptr + row * grad_weights_stride, grad_weight)


def fused_grad(rows, weights, upstream):
    n_rows, hidden = rows.shape
    block_hidden = 512
    num_hidden_blocks = triton.cdiv(hidden, block_hidden)
    grad_rows = torch.empty_like(rows)
    partials = torch.empty((n_rows, num_hidden_blocks), dtype=torch.float32, device=rows.device)
    grad_weights = torch.empty_like(weights)
    first = _bwd_partial[(n_rows, num_hidden_blocks)](
        upstream, rows, weights, grad_rows, partials, hidden,
        upstream.stride(0), rows.stride(0), weights.stride(0), grad_rows.stride(0),
        num_hidden_blocks=num_hidden_blocks, BLOCK_H=block_hidden)
    last = _bwd_reduce[(n_rows,)](partials, grad_weights, grad_weights.stride(0),
                           NUM_HIDDEN_BLOCKS=num_hidden_blocks, BLOCK_B=num_hidden_blocks)
    return grad_weights, partials, first, last


def export_kernel(name, kernel):
    out = Path("ir_2646")
    out.mkdir(exist_ok=True)
    for stage in ("bcmlir", "npubin"):
        data = kernel.asm[stage]
        (out / f"{name}.{stage}").write_bytes(data.encode() if isinstance(data, str) else bytes(data))


def replay_tree(products):
    # The measured 910B4 tree for a row with four 512-element blocks.
    x = products.float().reshape(-1, 512)
    for stride in (256, 128, 64):
        x = x[:, :stride] + x[:, stride:]
    for _ in range(6):
        x = x[:, 0::2] + x[:, 1::2]
    parts = x.reshape(-1, 4)
    total = (parts[:, 0] + parts[:, 1]) + (parts[:, 2] + parts[:, 3])
    return parts, total[:, None]


def bit_matches(a, b):
    return (a.contiguous().view(torch.int32) == b.contiguous().view(torch.int32)).sum().item()


def run(n_rows, hidden, dtype):
    device = "npu:0"
    gen = torch.Generator(device=device).manual_seed(97 + hidden)
    rows = torch.randn(n_rows, hidden, device=device, generator=gen).to(dtype)
    weights = torch.rand(n_rows, 1, device=device, generator=gen)
    upstream = torch.randn(n_rows, hidden, device=device, generator=gen).to(dtype)

    eager = (upstream.float() * rows.float()).sum(dim=-1, keepdim=True)
    fused, partials, first, last = fused_grad(rows, weights, upstream)
    torch.npu.synchronize()
    fused, eager = fused.cpu(), eager.cpu()
    products = upstream.cpu().double() * rows.cpu().double()
    reference = products.sum(dim=-1, keepdim=True)
    fe = (fused.double() - reference).abs()
    ee = (eager.double() - reference).abs()
    depth = math.ceil(math.log2(hidden)) + 2
    bound = depth * torch.finfo(torch.float32).eps * products.abs().sum(-1, keepdim=True)
    checks = [bool((fe <= bound).all()), bool(fe.max() <= 2 * ee.max() + 1e-12),
              bool(fe.median() <= 2 * ee.median() + 1e-12)]
    print(n_rows, hidden, dtype, "max_gap", (fused - eager).abs().max().item(),
          "max_errors", fe.max().item(), ee.max().item(), "checks", checks)

    if hidden == 2048:
        p, g = replay_tree(products)
        print("tree_matches", bit_matches(p, partials.cpu()), "/", p.numel(),
              bit_matches(g, fused), "/", g.numel())
        export_kernel("bf16-first" if dtype == torch.bfloat16 else "fp16-first", first)
        if dtype == torch.bfloat16:
            export_kernel("last", last)


if __name__ == "__main__":
    torch.set_num_threads(2)
    for shape in ((4096, 2048), (257, 256)):
        for dtype in (torch.bfloat16, torch.float16):
            run(*shape, dtype)
```

</details>

### Reproduce the NPU-IR lowering

The first-stage TA output contains an FP32 multiply followed by `linalg.reduce` on `tensor<512xf32>`. The second-stage TA output reduces `tensor<4xf32>`. Both reductions have a zero FP32 initial value and an `arith.addf` body. For the large case on the tested build, all three modules (two input dtypes and their shared final stage) lower to `enablevc_reduce_sum_r_float` in optimized HIVM. The template folds the 512-element block to 64 FP32 values before the final vector sum. [ReduceR.cpp](https://gitcode.com/Ascend/AscendNPU-IR/blob/bcc1c294b61314ea6223a93514e10ba2b8f97cdf/bishengir/lib/Template/lib/Vector/Reduction/ReduceR.cpp#L161) · [ReduceARImpl.h](https://gitcode.com/Ascend/AscendNPU-IR/blob/bcc1c294b61314ea6223a93514e10ba2b8f97cdf/bishengir/lib/Template/include/Vector/Reduction/ReduceARImpl.h#L364)

The Python run above generates everything needed to replay both stages. **To inspect only the four-element stage on a compiler host without an NPU or Triton**, start instead with the following captured input in a fresh working directory.

<details>
<summary>Standalone NPU-IR input for the four-partial final stage</summary>

```bash
mkdir -p ir_2646
cat > ir_2646/last.bcmlir <<'MLIR'
module attributes {hacc.target = #hacc.target<"Ascend910B4">} {
  func.func @_bwd_reduce(%arg0: memref<?xi8>, %arg1: memref<?xi8>, %arg2: memref<?xf32> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xf32> {tt.tensor_kind = 1 : i32}, %arg4: i32, %arg5: i32, %arg6: i32, %arg7: i32, %arg8: i32, %arg9: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, global_kernel = "local", mix_mode = "aiv", parallel_mode = "simd"} {
    %c0 = arith.constant 0 : index
    %cst = arith.constant 0.000000e+00 : f32
    %c4_i64 = arith.constant 4 : i64
    %0 = arith.extsi %arg7 : i32 to i64
    %1 = arith.muli %0, %c4_i64 : i64
    %2 = arith.index_cast %1 : i64 to index
    %reinterpret_cast = memref.reinterpret_cast %arg2 to offset: [%2], sizes: [4], strides: [1] : memref<?xf32> to memref<4xf32, strided<[1], offset: ?>>
    %alloc = memref.alloc() : memref<4xf32>
    memref.copy %reinterpret_cast, %alloc : memref<4xf32, strided<[1], offset: ?>> to memref<4xf32>
    %3 = bufferization.to_tensor %alloc restrict writable : memref<4xf32>
    %4 = bufferization.alloc_tensor() : tensor<f32>
    %5 = linalg.fill ins(%cst : f32) outs(%4 : tensor<f32>) -> tensor<f32>
    %reduced = linalg.reduce ins(%3 : tensor<4xf32>) outs(%5 : tensor<f32>) dimensions = [0]
      (%in: f32, %init: f32) {
        %8 = arith.addf %in, %init : f32
        linalg.yield %8 : f32
      }
    %extracted = tensor.extract %reduced[] : tensor<f32>
    %6 = tensor.empty() : tensor<1xf32>
    %inserted = tensor.insert %extracted into %6[%c0] : tensor<1xf32>
    %7 = arith.index_cast %arg7 : i32 to index
    %reinterpret_cast_0 = memref.reinterpret_cast %arg3 to offset: [%7], sizes: [1], strides: [1] : memref<?xf32> to memref<1xf32, strided<[1], offset: ?>>
    bufferization.materialize_in_destination %inserted in writable %reinterpret_cast_0 : (tensor<1xf32>, memref<1xf32, strided<[1], offset: ?>>) -> ()
    return
  }
}
MLIR
```

</details>

Use a Bash shell with CANN loaded, `bishengir-compile` on `PATH`, and its libraries on `LD_LIBRARY_PATH`. To select the compiler from the tested Triton-Ascend wheel, run the following.

```bash
tools_dir=$(python3 -c 'from pathlib import Path; import triton; print(Path(triton.__file__).resolve().parent / "backends/ascend/bishengir")')
export PATH="$tools_dir/bin:$PATH"
export LD_LIBRARY_PATH="$tools_dir/lib:${LD_LIBRARY_PATH:-}"
```

Run the block below in the directory containing `ir_2646/`. It prints the reduction call for each input. When a device binary is present, it also compares both ELF `.text` sections. On the tested compiler all three comparisons produced an empty diff.

```bash
set -e
ir_dir="$PWD/ir_2646"
bishengir-compile --version

for input in "$ir_dir"/*.bcmlir; do
  name=$(basename "$input" .bcmlir)
  (
    work="$ir_dir/replay/$name"
    mkdir -p "$work/temps"
    cd "$work"
    bishengir-compile "$ir_dir/$name.bcmlir" --target=Ascend910B4 \
      --enable-auto-multi-buffer=True --enable-auto-bind-sub-block=True \
      --enable-optimized-metaop=false --enable-auto-blockify-loop \
      --enable-hfusion-compile=true --enable-hivm-compile=true \
      --enable-triton-kernel-compile=true --save-temps="$work/temps" -o "$work/kernel"
    grep -F 'call @enablevc_reduce_sum_r_float' temps/module.hivm.opt.mlir
    if [[ -f "$ir_dir/$name.npubin" ]]; then
      diff <(readelf -x .text "$ir_dir/$name.npubin") <(readelf -x .text kernel.o)
    fi
  )
done
```

## Observed results

All columns are maximum absolute differences over rows. The CPU reference uses the same quantized input values copied from the NPU, then multiplies and sums in FP64.

| Shape | Input dtype | Fused vs eager | Fused vs CPU FP64 | Eager vs CPU FP64 |
| --- | --- | ---: | ---: | ---: |
| 4096 × 2048 | BF16 | 2.288818e-5 | 1.530349e-5 | 1.362339e-5 |
| 4096 × 2048 | FP16 | 3.051758e-5 | 1.525925e-5 | 1.727132e-5 |
| 257 × 256 | BF16 | 0 | 3.349036e-6 | 3.349036e-6 |
| 257 × 256 | FP16 | 0 | 3.011432e-6 | 3.011432e-6 |

**How the difference arises.** For each group of 512 products, an FP32 CPU replay first adds corresponding elements across the two halves at strides 256, 128 and 64. It then adds adjacent pairs for six rounds. The final stage combines the partials as `(p0 + p1) + (p2 + p3)`. For **each** input dtype, this reproduces **16,384 of 16,384 partial sums** and **4,096 of 4,096 final gradients** bit for bit. This identifies an addition order consistent with the actual device output. The internal addition order used by eager is still open.

**How to interpret the accuracy checks.** With CPU FP64 as the reference, all four cases pass DeepSpeed's per-row depth-based rounding bound and both checks on the maximum and median errors. For the large FP16 case, fused is slightly closer to FP64 by maximum error, even though its difference from eager exceeds the proposed target. On our `torch_npu` build, calling `.double()` directly on an NPU tensor returned FP32, so the script copies inputs to the CPU before converting. [DeepSpeed's test](https://github.com/deepspeedai/DeepSpeed/blob/2c4ead4bdbf750366c3bc700e7d9cdc61ab25a81/tests/unit/v1/ops/triton_ops/test_autoep_fused_token_ops.py#L215-L225)

### Environment details

- Ascend 910B4 with CANN 9.1.0
- Triton-Ascend 3.6.0, NPU-IR 2.0.0 at `bcc1c294b613`, LLVM 19.1.7 at `06913395ef8a`
- PyTorch 2.10.0+cpu, torch_npu 2.10.0.post7.dev20261018 at `45741955`
- Random seeds were `2145` for `4096 × 2048` and `353` for `257 × 256`

The original report used torch_npu `51c843bd`. Both large-shape maxima reproduced at `45741955`. The measurements and generated-code observations above apply to the listed NPU-IR revision.
