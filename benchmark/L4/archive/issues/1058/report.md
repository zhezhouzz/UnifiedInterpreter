### 环境信息
            
NA
### 🐛 问题描述
            
```
import torch
import triton
import triton.language as tl
import sys
import math
import pytest

# 数据范围字典
MIDDLE_RANGE_DICT = {
    'int8': [-4, 4],
    'int16': [-20, 20],
    'int32': [-100, 100],
    'int64': [-100, 100],
    'uint8': [0, 4],
    'uint16': [0, 20],
    'uint32': [0, 100],
    'uint64': [0, 100],
    'float16': [-10, 10],
    'float32': [-10, 10],
    'bfloat16': [-10, 10],
    'bool': [0, 1],
    'fp8e4m3': [-4, 4],
}


def get_tolerance(dtype_str):
    """根据不同的 dtype 获取对应的 atol 和 rtol 标准"""
    if dtype_str == 'float32':
        return 1e-3, 1e-3
    elif dtype_str in ['float16', 'bfloat16']:
        return 1e-2, 1e-2
    elif dtype_str == 'fp8e4m3':
        return 1e-1, 1e-1
    else:
        # 整型、无符号型和布尔型保持绝对精确匹配
        return 0.0, 0.0


def make_tensor(shape, dtype_name, low, high, device):
    """造数函数：针对 fp8e4m3、uint16/32/64 以及其他类型安全造数，先在 CPU 生成再 H2D 拷贝"""
    if dtype_name == 'fp8e4m3':
        torch_dtype = getattr(torch, 'float8_e4m3fn', torch.float32)
        # 规避 fp8 不支持直接 .uniform_ 的限制，先在 CPU 用 float32 生成再转换
        t_cpu = torch.empty(shape, dtype=torch.float32).uniform_(low, high).to(torch_dtype)
        return t_cpu.to(device)

    torch_dtype = getattr(torch, dtype_name)

    if dtype_name == 'bool':
        t_cpu = torch.randint(0, 2, shape, dtype=torch.bool)
        return t_cpu.to(device)

    if dtype_name.startswith('uint'):
        t_cpu = torch.randint(low, high, shape, dtype=torch.int64).to(torch_dtype)
        return t_cpu.to(device)

    if dtype_name.startswith('int'):
        t_cpu = torch.randint(low, high, shape, dtype=torch_dtype)
        return t_cpu.to(device)

    t_cpu = torch.empty(shape, dtype=torch_dtype).uniform_(low, high)
    return t_cpu.to(device)


def make_zeros(shape, dtype_name, device):
    """安全创建全零矩阵：先在 CPU 创建再 H2D 拷贝，规避 NPU 无符号及 fp8 类型零矩阵限制"""
    if dtype_name == 'fp8e4m3':
        torch_dtype = getattr(torch, 'float8_e4m3fn', torch.float32)
    else:
        torch_dtype = getattr(torch, dtype_name)

    t_cpu = torch.zeros(shape, dtype=torch_dtype)
    return t_cpu.to(device)


# ---------------------------------------------------------
# Triton 复合算子实现
# 组合算子场景：CV multibuffer event-id 跨循环复用
# 包含 3 层嵌套控制流 (scf.for > scf.if > scf.while)，链长 8 步，含 tl.dot
# ---------------------------------------------------------
@triton.jit
def complex_fused_kernel(
        X_ptr, W_ptr, Out_ptr,
        n_elements,
        BLOCK_SIZE: tl.constexpr,
):
    """
    Triton 内核函数：
    ScalarLoad -> ReductionMax -> scf.for{ ReductionMin -> tl.dot -> scf.if{ scf.while{ ElemWiseMax -> ElemWiseMin -> Clamp } } } -> ScatterStore
    """
    pid = tl.program_id(axis=0)
    block_start = pid * BLOCK_SIZE
    offsets = block_start + tl.arange(0, BLOCK_SIZE)
    mask = offsets < n_elements

    # 1. ScalarLoad (带其他默认值填充，保证越界安全)
    x = tl.load(X_ptr + offsets, mask=mask, other=0.0)
    w = tl.load(W_ptr + offsets, mask=mask, other=1.0)

    x_f = x.to(tl.float32)
    w_f = w.to(tl.float32)

    # 2. ReductionMax (块内局部规约最大值)
    max_val = tl.max(x_f, axis=0)
    acc = x_f

    # 固定 BLOCK_SIZE = 256，塑形为 16x16 矩阵以满足 tl.dot 2D 要求
    acc_2d = acc.reshape(16, 16)
    w_2d = w_f.reshape(16, 16)

    # 3. scf.for 外层循环
    for i in tl.range(0, 2):
        # ReductionMin (块内局部规约最小值)
        min_val = tl.min(acc, axis=0)

        # tl.dot 矩阵乘法，显式指定 input_precision="ieee"
        dot_res_2d = tl.dot(acc_2d.to(tl.float16), w_2d.to(tl.float16).trans(), input_precision="ieee")
        dot_res = dot_res_2d.to(tl.float32).reshape(BLOCK_SIZE)

        # scf.if 中层条件分支
        if max_val > min_val:
            # scf.while 内层循环
            counter = 0
            while counter < 3:
                # ElemWiseMax
                acc = tl.maximum(dot_res, acc)
                # ElemWiseMin
                acc = tl.minimum(acc, max_val + 1.0)
                # Clamp (边界截断)
                acc = tl.maximum(tl.minimum(acc, 10.0), -10.0)
                acc_2d = acc.reshape(16, 16)
                counter = counter + 1

    # 4. ScatterStore (仅在有效掩码范围内写回)
    out_val = acc.to(X_ptr.dtype.element_ty if hasattr(X_ptr, 'dtype') else x.dtype)
    tl.store(Out_ptr + offsets, out_val, mask=mask)


def reference_implementation(x, w):
    """
    严格对齐 Triton 块级并行网格（Block Grid）语义的 PyTorch 参考实现，
    确保局部 max/min 规约行为与 Triton 完全一致。
    """
    x_f = x.to(torch.float32)
    w_f = w.to(torch.float32)
    n_elements = x_f.numel()
    BLOCK_SIZE = 256

    out_list = []
    num_blocks = math.ceil(n_elements / BLOCK_SIZE)

    for pid in range(num_blocks):
        start_idx = pid * BLOCK_SIZE
        end_idx = min(start_idx + BLOCK_SIZE, n_elements)
        curr_len = end_idx - start_idx

        # 模拟 block 加载与掩码默认值填充（x 填 0.0，w 填 1.0）
        block_x = torch.zeros(BLOCK_SIZE, dtype=torch.float32, device=x.device)
        block_w = torch.ones(BLOCK_SIZE, dtype=torch.float32, device=x.device)

        block_x[:curr_len] = x_f[start_idx:end_idx]
        block_w[:curr_len] = w_f[start_idx:end_idx]

        max_val = torch.max(block_x)
        acc = block_x.clone()

        acc_2d = acc.view(16, 16)
        w_2d = block_w.view(16, 16)

        for i in range(2):
            min_val = torch.min(acc)
            dot_res_2d = torch.matmul(acc_2d.to(torch.float16), w_2d.to(torch.float16).T).to(torch.float32)
            dot_res = dot_res_2d.view(-1)

            if max_val > min_val:
                counter = 0
                while counter < 3:
                    acc = torch.maximum(dot_res, acc)
                    acc = torch.minimum(acc, max_val + 1.0)
                    acc = torch.clamp(acc, min=-10.0, max=10.0)
                    acc_2d = acc.view(16, 16)
                    counter += 1

        out_list.append(acc[:curr_len].to(x.dtype))

    return torch.cat(out_list)


# ---------------------------------------------------------
# 测试用例生成逻辑（1维到5维，覆盖对齐与非对齐场景）
# ---------------------------------------------------------
def get_test_cases():
    shapes_1d = [(64,), (65,), (256,), (257,)]
    shapes_2d = [(4, 64), (4, 65)]
    shapes_3d = [(2, 2, 64), (2, 2, 65)]
    shapes_4d = [(2, 2, 2, 32), (2, 2, 2, 33)]
    shapes_5d = [(1, 2, 2, 2, 16), (1, 2, 2, 2, 17)]

    all_shapes = shapes_1d + shapes_2d + shapes_3d + shapes_4d + shapes_5d

    test_cases = []
    for dtype_name, (low, high) in MIDDLE_RANGE_DICT.items():
        for shape in all_shapes:
            test_cases.append((dtype_name, shape, low, high))
    return test_cases


def run_single_test(dtype_name, shape, low, high, device):
    """执行单个 dtype 和 shape 的测试，并进行精度对比"""
    try:
        x = make_tensor(shape, dtype_name, low, high, device)
        w = make_tensor(shape, dtype_name, low, high, device)
        out = make_zeros(shape, dtype_name, device)

        n_elements = x.numel()
        BLOCK_SIZE = 256  # 统一使用 256 对应 16x16 矩阵计算
        grid = (triton.cdiv(n_elements, BLOCK_SIZE),)

        # 调用 Triton 算子
        complex_fused_kernel[grid](
            x, w, out,
            n_elements,
            BLOCK_SIZE=BLOCK_SIZE
        )

        # 获取参考结果
        x_flat = x.view(-1)
        w_flat = w.view(-1)
        ref_flat = reference_implementation(x_flat, w_flat)
        ref_out = ref_flat.view(shape)

        atol, rtol = get_tolerance(dtype_name)

        if dtype_name == 'bool':
            mismatch = (out != ref_out).sum().item()
            total = n_elements
            success = (mismatch == 0)
        else:
            out_f = out.to(torch.float32)
            ref_f = ref_out.to(torch.float32)
            diff = torch.abs(out_f - ref_f)
            tolerance_threshold = atol + rtol * torch.abs(ref_f)
            mismatches = (diff > tolerance_threshold).sum().item()
            total = n_elements
            success = (mismatches == 0)
            mismatch = mismatches

        mismatch_pct = (mismatch / total) * 100.0 if total > 0 else 0.0
        return True, success, mismatch, mismatch_pct, None
    except Exception as e:
        return False, False, 0, 0.0, str(e)


# ---------------------------------------------------------
# Pytest 集成测试入口
# ---------------------------------------------------------
@pytest.mark.parametrize("dtype_name, shape, low, high", get_test_cases())
def test_triton_operator_suite(dtype_name, shape, low, high):
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    if hasattr(torch, 'npu') and torch.npu.is_available():
        device = 'npu'

    executed, success, mismatch, mismatch_pct, err_msg = run_single_test(dtype_name, shape, low, high, device)
    if not executed:
        pytest.fail(f"Test execution raised exception for {dtype_name} with shape {shape}: {err_msg}")
    assert success, f"Accuracy check failed for {dtype_name} with shape {shape}. Mismatches: {mismatch} ({mismatch_pct:.2f}%)"


# ---------------------------------------------------------
# Python 直接执行主入口
# ---------------------------------------------------------
if __name__ == "__main__":
    print("=== 开始执行 Triton 组合算子多维度、全类型测试套件 ===")

    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    if hasattr(torch, 'npu') and torch.npu.is_available():
        device = 'npu'
    print(f"当前运行设备: {device}")

    test_cases = get_test_cases()
    success_count = 0
    fail_count = 0
    exception_count = 0

    total_cases = len(test_cases)
    print(f"总测试用例数: {total_cases}\n" + "-" * 60)

    for idx, (dtype_name, shape, low, high) in enumerate(test_cases, 1):
        executed, success, mismatch, mismatch_pct, err_msg = run_single_test(dtype_name, shape, low, high, device)

        if not executed:
            exception_count += 1
            fail_count += 1
            print(f"[{idx}/{total_cases}] Dtype: {dtype_name:<10} Shape: {str(shape):<20} -> 异常中断: {err_msg}")
        elif success:
            success_count += 1
            print(f"[{idx}/{total_cases}] Dtype: {dtype_name:<10} Shape: {str(shape):<20} -> 成功 (SUCCESS)")
        else:
            fail_count += 1
            print(
                f"[{idx}/{total_cases}] Dtype: {dtype_name:<10} Shape: {str(shape):<20} -> 失败 (FAIL) | Mismatches: {mismatch} ({mismatch_pct:.2f}%)")

    print("-" * 60)
    print(f"=== 测试汇总结果 ===")
    print(f"总用例数: {total_cases}")
    print(f"成功数: {success_count}")
    print(f"失败数: {fail_count} (含异常: {exception_count})")
    print(f"成功率: {(success_count / total_cases) * 100:.2f}%")
    print("=== 测试执行完毕 ===")
```
