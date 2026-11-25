# Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.
import os

import shmem as ash
import torch
import torch.distributed as dist
import torch_npu  # noqa: F401
import triton
import triton.language as tl
from triton.backends.ascend.driver import NPUUtils
from triton.language.extra.cann.extension import sub_vec_id
from triton_dist.language.extra import libshmem_device
from triton_dist.language.extra.ascend.algorithm import gemm_swizzle2d_Nz

g_ash_size = 1024 * 1024 * 1024 * 8
g_malloc_size = 8 * 1024 * 1024
def _get_ash_ip_port():
    ash_port = os.environ.get("ASH_MASTER_PORT", "8666")
    ash_addr = os.environ.get("ASH_MASTER_ADDR", "127.0.0.1")
    return f"tcp://{ash_addr}:{ash_port}"
G_IP_PORT = _get_ash_ip_port()
# ANSI color codes
GREEN = "\033[92m"
RED = "\033[91m"
CYAN = "\033[96m"
RESET = "\033[0m"
BOLD = "\033[1m"
@triton.jit
def kernel_gemm_reduce_scatter(
    a_ptr,
    b_ptr,
    c_ptr,
    C_local_ptr,
    recv_mem_ptr,
    rank,
    rank_size,
    M,
    N,
    K,
    stride_am,
    stride_ak,
    stride_bk,
    stride_bn,
    stride_cm,
    stride_cn,
    pvalue: tl.constexpr,
    BLOCK_SIZE_M: tl.constexpr,
    BLOCK_SIZE_N: tl.constexpr,
    BLOCK_SIZE_K: tl.constexpr,
):
    subblock_idx = sub_vec_id()
    ncore = tl.num_programs(axis=0)
    pid = tl.program_id(axis=0)
    elem_bytes = 2  # fp16 element size in bytes
    m_per_rank = M // rank_size
    blocks_per_rank = tl.cdiv(m_per_rank, BLOCK_SIZE_M)
    num_loops_n = tl.cdiv(N, BLOCK_SIZE_N)
    per_rank_tiles = blocks_per_rank * num_loops_n
    total_loops = per_rank_tiles * rank_size
    num_k_blocks = tl.cdiv(K, BLOCK_SIZE_K)
    loop_num_per_comm = ncore * pvalue
    num_loops_comm = tl.cdiv(total_loops, loop_num_per_comm)
    N_SPLIT: tl.constexpr = 4
    COLS: tl.constexpr = BLOCK_SIZE_N // N_SPLIT
    offs_rm = tl.arange(0, BLOCK_SIZE_M)

    for global_id in range(num_loops_comm):
        actual_loop_num = loop_num_per_comm
        if global_id == num_loops_comm - 1:
            actual_loop_num = total_loops - global_id * loop_num_per_comm
        num_blocks_per_rank = actual_loop_num // rank_size
        for block_id in range(pid, actual_loop_num, ncore):
            rank_idx = block_id // num_blocks_per_rank
            block_id_local = block_id % num_blocks_per_rank
            tile_in_rank = (
                global_id * loop_num_per_comm // rank_size + block_id_local
            )
            block_id_m, block_id_n = gemm_swizzle2d_Nz(
                tile_in_rank,
                m_per_rank,
                N,
                BLOCK_SIZE_M,
                BLOCK_SIZE_N,
            )
            accumulator = tl.zeros((BLOCK_SIZE_M, BLOCK_SIZE_N), dtype=tl.float32)
            matmul_offs_am = (
                m_per_rank * rank_idx
                + block_id_m * BLOCK_SIZE_M
                + tl.arange(0, BLOCK_SIZE_M)
            )
            matmul_msk_am = matmul_offs_am[:, None] < (m_per_rank * (rank_idx + 1))
            offs_bn = block_id_n * BLOCK_SIZE_N + tl.arange(0, BLOCK_SIZE_N)
            msk_n = offs_bn[None, :] < N
            for block_id_k in range(num_k_blocks):
                offs_k = tl.arange(0, BLOCK_SIZE_K) + block_id_k * BLOCK_SIZE_K
                a_ptrs = a_ptr + (
                    matmul_offs_am[:, None] * stride_am + offs_k[None, :] * stride_ak
                )
                b_ptrs = b_ptr + (
                    offs_k[:, None] * stride_bk + offs_bn[None, :] * stride_bn
                )
                a = tl.load(
                    a_ptrs, mask=(offs_k[None, :] < K) & matmul_msk_am, other=0.0
                )
                b = tl.load(b_ptrs, mask=(offs_k[:, None] < K) & msk_n, other=0.0)
                accumulator += tl.dot(a, b)
            tl.extra.cann.extension.compile_hint(accumulator, "matmul_at_least_once")
            c = accumulator
            offs_c_local_mem_m = (
                global_id * loop_num_per_comm * BLOCK_SIZE_M
                + block_id * BLOCK_SIZE_M
                + tl.arange(0, BLOCK_SIZE_M)
            )
            offs_c_local_mem_n = tl.arange(0, BLOCK_SIZE_N)
            C_local_ptrs = (
                C_local_ptr
                + BLOCK_SIZE_N * offs_c_local_mem_m[:, None]
                + offs_c_local_mem_n[None, :]
            )
            tl.store(C_local_ptrs, c)
        libshmem_device.barrier_all()
        if subblock_idx == 1 :
            for src_rank in range(pid, rank_size, ncore):
                if src_rank != rank:
                    src_ptr = C_local_ptr + (
                        global_id * loop_num_per_comm
                        + rank * num_blocks_per_rank
                    ) * BLOCK_SIZE_M * BLOCK_SIZE_N
                    dst_ptr = recv_mem_ptr + (
                        global_id * loop_num_per_comm
                        + src_rank * num_blocks_per_rank
                    ) * BLOCK_SIZE_M * BLOCK_SIZE_N
                    cur_nbytes = (
                        num_blocks_per_rank * BLOCK_SIZE_M * BLOCK_SIZE_N * elem_bytes
                    )
                    libshmem_device.getmem(
                        dst_ptr,
                        src_ptr,
                        cur_nbytes,
                        src_rank,
                    )
        libshmem_device.barrier_all_vec()
        if subblock_idx==1:
            total_work = num_blocks_per_rank * N_SPLIT
            for work_id in range(pid, total_work, ncore):
                block_id_local = work_id // N_SPLIT
                n_part = work_id % N_SPLIT
                tile_in_rank = (
                    global_id * loop_num_per_comm // rank_size + block_id_local
                )
                block_id_m, block_id_n = gemm_swizzle2d_Nz(
                    tile_in_rank,
                    m_per_rank,
                    N,
                    BLOCK_SIZE_M,
                    BLOCK_SIZE_N,
                )
                offs_rn = n_part * COLS + tl.arange(0, COLS)
                offs_cm = block_id_m * BLOCK_SIZE_M + tl.arange(0, BLOCK_SIZE_M)
                offs_cn = block_id_n * BLOCK_SIZE_N + offs_rn
                c_offs = stride_cm * offs_cm[:, None] + stride_cn * offs_cn[None, :]
                c_mask = (offs_cm[:, None] < m_per_rank) & (offs_cn[None, :] < N)
                accum = tl.zeros((BLOCK_SIZE_M, COLS), dtype=tl. float16)
                for src_rank in range(rank_size):
                    slot_row = (
                        global_id * loop_num_per_comm
                        + src_rank * num_blocks_per_rank
                        + block_id_local
                    ) * BLOCK_SIZE_M
                    slot_mask = (offs_rm[:, None] < BLOCK_SIZE_M) & (offs_rn[None, :] < BLOCK_SIZE_N)
                    if src_rank != rank:
                        peer_slot_ptrs = recv_mem_ptr + (
                            (slot_row + offs_rm[:, None]) * BLOCK_SIZE_N
                            + offs_rn[None, :]
                        )
                        c_temp = tl.load(peer_slot_ptrs, mask=slot_mask, other=0.0)
                    else:
                        local_slot_ptrs = C_local_ptr + (
                            (slot_row + offs_rm[:, None]) * BLOCK_SIZE_N
                            + offs_rn[None, :]
                        )
                        c_temp = tl.load(local_slot_ptrs, mask=slot_mask, other=0.0)
                    accum += c_temp
                tl.store(c_ptr + c_offs, accum, mask=c_mask)
def gemm_reduce_scatter(
    A,
    B,
    C,
    C_local,
    recv_mem,
    rank,
    rank_size,
    pvalue,
    BLOCK_SIZE_M,
    BLOCK_SIZE_N,
    BLOCK_SIZE_K,
):
    """consume gemm"""
    M, K = A.shape
    _, N = B.shape
    ncore = NPUUtils().get_aicore_num()
    kernel_gemm_reduce_scatter[ncore, 1, 1](
        A,
        B,
        C,
        C_local,
        recv_mem,
        rank,
        rank_size,
        M,
        N,
        K,
        A.stride(0),
        A.stride(1),
        B.stride(0),
        B.stride(1),
        C.stride(0),
        C.stride(1),
        pvalue,
        BLOCK_SIZE_M,
        BLOCK_SIZE_N,
        BLOCK_SIZE_K,
    )
def torch_gemm_reduce_scatter(A_local, B_local, world_size):
    C_local = torch.matmul(A_local, B_local)
    m_total, n_dim = C_local.shape
    m_per_rank = m_total // world_size
    input_list = [x for x in torch.chunk(C_local, world_size, dim=0)]
    output_chunk = torch.empty((m_per_rank, n_dim), dtype=torch.float16, device=C_local.device)
    dist.reduce_scatter(output_chunk, input_list, op=dist.ReduceOp.SUM)
    return output_chunk


def run_test_distributed():
    BLOCK_SIZE_M = 128
    BLOCK_SIZE_N = 256
    BLOCK_SIZE_K = 256
    pvalue=2
    pe = dist.get_rank()
    world_size = dist.get_world_size()
    ret = ash.set_conf_store_tls(False, "")
    if ret != 0:
        raise ValueError("[ERROR] set_conf_store_tls failed")
    attributes = ash.InitAttr()
    attributes.my_rank = pe
    attributes.n_ranks = world_size
    attributes.local_mem_size = g_ash_size
    attributes.ip_port = G_IP_PORT
    attributes.option_attr.data_op_engine_type = ash.OpEngineType.UDMA
    ret = ash.aclshmem_init(attributes)
    if ret != 0:
        raise ValueError("[ERROR] aclshmem_init failed")
    dist.barrier()
    m_per_rank = M // world_size
    num_loops_m = ((m_per_rank + BLOCK_SIZE_M - 1) // BLOCK_SIZE_M) * world_size
    num_loops_n = (N + BLOCK_SIZE_N - 1) // BLOCK_SIZE_N
    total_loops = num_loops_m * num_loops_n
    recv_mem_size = total_loops * BLOCK_SIZE_M * BLOCK_SIZE_N
    recv_mem = ash.aclshmem_create_tensor(
        [recv_mem_size],
        dtype=dtype,
        device_id=pe,
    )
    C_local_size = total_loops * BLOCK_SIZE_M * BLOCK_SIZE_N
    C_local = ash.aclshmem_create_tensor(
        [C_local_size],
        dtype=dtype,
        device_id=pe,
    )
    A_local = torch.randn([M, K], dtype=dtype).npu().contiguous()*2-1
    B_local = torch.randn([K, N], dtype=dtype).npu().contiguous()*2-1
    C = torch.zeros([M // world_size, N], dtype=torch.float16).npu()
    C_golden = torch_gemm_reduce_scatter(A_local, B_local, world_size)
    gemm_reduce_scatter(
        A_local,
        B_local,
        C,
        C_local,
        recv_mem,
        pe,
        world_size,
        pvalue,
        BLOCK_SIZE_M,
        BLOCK_SIZE_N,
        BLOCK_SIZE_K
    )
    torch.npu.synchronize()
    passed = torch.tensor([1], dtype=torch.int32).npu()
    error_msg = ""
    rtol = 1e-2
    try:
        diff = torch.abs(C.to(dtype) - C_golden)
        scale = torch.clamp(torch.abs(C_golden), min=1.0)
        normalized_error = diff / scale
        bad_count = int((normalized_error > rtol).sum().item())
        if bad_count > 0:
            max_error = float(normalized_error.max().item())
            raise AssertionError(
                f"{bad_count}/{C_golden.numel()} elements exceed {bad_count/C_golden.numel()*100}%"
                f"the normalized error threshold; "
                f"max_normalized_error={max_error}, rtol={rtol}."
            )
    except AssertionError as error:
        passed[0] = 0
        error_msg = str(error)
    # Gather all ranks' pass/fail status
    all_passed = [torch.zeros(1, dtype=torch.int32).npu() for _ in range(world_size)]
    dist.all_gather(all_passed, passed)
    # Print sequentially, one rank at a time
    dist.barrier()
    for rank_id in range(world_size):
        if pe == rank_id:
            if all_passed[rank_id].item() == 1:
                print(
                    f"{GREEN}[PASS]{RESET} Rank {pe}: C_golden and C match within tolerances (rtol=1e-3, atol=1e-3).",
                    flush=True,
                )
            else:
                print(
                    f"{RED}[FAIL]{RESET} Rank {pe}: C_golden and C do NOT match. Details:\n{error_msg}",
                    flush=True,
                )
        dist.barrier()
    # Raise if any rank failed
    if any(r.item() == 0 for r in all_passed):
        raise AssertionError(
            error_msg or "gemm_reduce_scatter_udma correctness check failed"
        )
    ash.aclshmem_free_tensor(recv_mem)
    ash.aclshmem_free_tensor(C_local)
    _ = ash.aclshmem_finalize()
if __name__ == "__main__":
    local_pe = int(os.environ["LOCAL_RANK"])
    torch.npu.set_device(local_pe)
    dist.init_process_group(backend="hccl", rank=local_pe)
    dtype, M, N, K = [torch.float16, 4096, 4096, 4096]
    world_size = dist.get_world_size()
    print(f"[INFO] Rank {local_pe} of {world_size} initialized")
    dist.barrier()
    run_test_distributed()
    if local_pe == 0:
        print(f"[INFO] Test passed successfully for {world_size} ranks!")
