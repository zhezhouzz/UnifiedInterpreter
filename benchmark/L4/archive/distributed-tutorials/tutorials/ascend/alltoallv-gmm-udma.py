# Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.

"""AllToAllV-GMM tutorial using Ascend 950 UDMA communication.

Remote UDMA writes directly into the symmetric expert-major grouped-input
buffer.  Each source owns disjoint source slots inside every target expert,
which permits one AIV program per peer while retaining the default single-QP
submission model. Per-source ready signals allow grouped GEMM to consume data
after dispatch completion without a receive-side staging pack.
The grouped GEMM then launches one bounded-persistent Cube grid per non-empty
local expert, so large M does not create one host launch or JIT specialization
per tile.

Run on a two-NPU Ascend 950 host:

    ASH_MASTER_PORT=28980 torchrun --standalone --nproc_per_node=2 \\
      tutorials/ascend/alltoallv-gmm-udma.py

Event timing for this example lives in python/triton_dist/test/ascend/alltoallv-gmm-udma.py.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass

import torch
import torch.distributed as dist
import torch_npu
import triton
import triton.language as tl
from triton.backends.ascend.driver import NPUUtils
from triton.compiler import ASTSource, compile as triton_compile
import triton_dist.language as dl
from triton_dist.language.extra.ascend import libaclshmem_device

import shmem as ash

# ACLSHMEM hands out symmetric memory in 2 MiB pages and needs head-room for
# allocator metadata; every capacity calculation uses these two constants.
SHMEM_PAGE_SIZE = 2 * 1024 * 1024
SHMEM_ALLOCATOR_MARGIN = 64 * 1024 * 1024


# Ascend 950 UDMA uses uint64 notify/wait slots. Eight elements preserve one
# 64-byte cache line per source rank and avoid signal false sharing.
SIGNAL_DTYPE = torch.uint64
SIGNAL_STRIDE = 8
SIGNAL_ZERO_BLOCK = 128


# Core counts are constant for the lifetime of a process, while constructing
# NPUUtils() costs roughly 0.3 ms on the host; cache them so the per-round
# launch path never pays that cost again.
_CORE_COUNTS: dict[str, int] = {}


def _aicore_num() -> int:
    """Return the Cube core count for this process."""
    if "aicore" not in _CORE_COUNTS:
        _CORE_COUNTS["aicore"] = NPUUtils().get_aicore_num()
    return _CORE_COUNTS["aicore"]


def _aivector_core_num() -> int:
    """Return the Vector core count for this process."""
    if "aivector" not in _CORE_COUNTS:
        _CORE_COUNTS["aivector"] = NPUUtils().get_aivector_core_num()
    return _CORE_COUNTS["aivector"]


def direct_grouped_input_offsets(
    token_counts: torch.Tensor,
    rank: int,
    world_size: int,
    experts_per_rank: int,
) -> tuple[list[int], list[int]]:
    """Build source and target offsets for direct expert-major UDMA writes."""
    total_experts = world_size * experts_per_rank
    local_counts = token_counts[rank]
    source_offsets = []
    running = 0
    for count in local_counts.tolist():
        source_offsets.append(running)
        running += int(count)
    direct_offsets = []
    for global_expert in range(total_experts):
        destination_rank = global_expert // experts_per_rank
        local_expert = global_expert % experts_per_rank
        expert_start = destination_rank * experts_per_rank
        expert_prefix = sum(
            int(token_counts[source_rank, expert_start + previous].item())
            for previous in range(local_expert)
            for source_rank in range(world_size)
        )
        source_prefix = sum(
            int(token_counts[source_rank, global_expert].item())
            for source_rank in range(rank)
        )
        direct_offsets.append(expert_prefix + source_prefix)
    return source_offsets, direct_offsets


def _effective_tiles(
    m: int,
    k: int,
    n: int,
) -> tuple[int, int, int, int, int]:
    """Return dispatch and grouped-GEMM tiles clamped to one input shape."""
    dispatch_block_m = min(int(os.environ.get("TRITON_DISPATCH_BLOCK_M", 128)), m)
    dispatch_block_k = min(int(os.environ.get("TRITON_DISPATCH_BLOCK_K", 256)), k)
    gmm_block_m = min(int(os.environ.get("TRITON_GMM_BLOCK_M", 128)), m)
    gmm_block_n = min(int(os.environ.get("TRITON_GMM_BLOCK_N", 256)), n)
    gmm_block_k = min(int(os.environ.get("TRITON_GMM_BLOCK_K", 256)), k)
    return dispatch_block_m, dispatch_block_k, gmm_block_m, gmm_block_n, gmm_block_k


def symmetric_memory_size(
    world_size: int,
    m: int,
    k: int,
    buffer_count: int = 1,
    extra_bytes: int = 0,
) -> int:
    """Return aligned ACLSHMEM capacity for all symmetric allocations."""
    dtype_bytes = torch.tensor([], dtype=torch.float16).element_size()
    required_bytes = (
        buffer_count * world_size * m * k * dtype_bytes
        + extra_bytes
        + SHMEM_ALLOCATOR_MARGIN
    )
    return ((required_bytes + SHMEM_PAGE_SIZE - 1) // SHMEM_PAGE_SIZE) * SHMEM_PAGE_SIZE


ROUTE_SEED = 20260828
ROUTE_MODES = ("random", "hot", "skewed", "static")


@dataclass(frozen=True)
class RouteSample:
    """One expert-major activation tensor and its global count matrix."""

    activations: torch.Tensor
    token_counts: torch.Tensor
    mode: str
    epoch: int


def _static_token_counts(
    m: int, world_size: int, experts_per_rank: int, sparse: bool
) -> torch.Tensor:
    """Build the fixed static route for one snapshot."""
    total_experts = world_size * experts_per_rank
    if not sparse:
        counts = torch.full(
            (world_size, total_experts), m // total_experts, dtype=torch.int32
        )
        for source_rank in range(world_size):
            for index in range(m % total_experts):
                counts[source_rank, (source_rank + index) % total_experts] += 1
        return counts
    counts = torch.zeros((world_size, total_experts), dtype=torch.int32)
    for source_rank in range(world_size):
        first = (source_rank * experts_per_rank + 1) % total_experts
        second = (first + 1) % total_experts
        counts[source_rank, first] = m // 2
        counts[source_rank, second] = m - m // 2
    return counts


def _expert_ids(
    m: int, total_experts: int, rank: int, epoch: int, mode: str
) -> torch.Tensor:
    """Generate a fixed-seed top-1 route with controllable skew."""
    generator = torch.Generator(device="cpu")
    generator.manual_seed(ROUTE_SEED + rank * 1000003 + epoch * 10007)
    if mode == "random":
        return torch.randint(
            total_experts, (m,), generator=generator, dtype=torch.int64
        )
    if mode == "hot":
        return torch.zeros((m,), dtype=torch.int64)
    if mode == "skewed":
        ids = torch.randint(total_experts, (m,), generator=generator, dtype=torch.int64)
        ids[: (m * 3) // 4] = 0
        return ids
    raise ValueError(f"unsupported dynamic route mode: {mode}")


def _exchange_counts(
    store, local_counts: torch.Tensor, epoch: int, rank: int, world_size: int
) -> torch.Tensor:
    """Exchange CPU count rows through the torchrun TCPStore."""
    key_prefix = f"alltoallv_gmm/route/{epoch}"
    store.set(f"{key_prefix}/{rank}", json.dumps(local_counts.tolist()))
    rows = [
        json.loads(store.get(f"{key_prefix}/{peer}").decode("utf-8"))
        for peer in range(world_size)
    ]
    return torch.tensor(rows, dtype=torch.int32)


def prepare_route(
    m: int,
    k: int,
    world_size: int,
    experts_per_rank: int,
    rank: int,
    epoch: int,
    mode: str,
    store,
    sparse: bool,
) -> RouteSample:
    """Create one route epoch and return expert-major activations plus global counts."""
    if mode not in ROUTE_MODES:
        raise ValueError(
            f"TRITON_ROUTE_MODES must contain only: {', '.join(ROUTE_MODES)}"
        )
    total_experts = world_size * experts_per_rank
    generator = torch.Generator(device="cpu")
    generator.manual_seed(ROUTE_SEED + rank * 1000003 + epoch * 10007 + 1)
    activations = torch.randn((m, k), generator=generator, dtype=torch.float16)
    if mode == "static":
        token_counts = _static_token_counts(m, world_size, experts_per_rank, sparse)
    else:
        expert_ids = _expert_ids(m, total_experts, rank, epoch, mode)
        order = torch.argsort(expert_ids, stable=True)
        activations = activations[order]
        local_counts = torch.bincount(expert_ids, minlength=total_experts).to(
            torch.int32
        )
        token_counts = _exchange_counts(store, local_counts, epoch, rank, world_size)
    if token_counts.shape != (world_size, total_experts) or torch.any(token_counts < 0):
        raise ValueError("invalid global token-count matrix")
    if not torch.equal(
        token_counts.sum(dim=1), torch.full((world_size,), m, dtype=torch.int32)
    ):
        raise ValueError("every source rank must route exactly M tokens")
    return RouteSample(
        activations=activations.npu(), token_counts=token_counts, mode=mode, epoch=epoch
    )


def _reference_output(
    activations: torch.Tensor,
    weights: torch.Tensor,
    token_counts: torch.Tensor,
    rank: int,
    world_size: int,
    experts_per_rank: int,
) -> torch.Tensor:
    """Build the torch golden output with all_to_all_single and a fused grouped GEMM."""
    counts = token_counts.to(torch.int64)
    local_expert_start = rank * experts_per_rank
    send_splits = counts[rank].reshape(world_size, experts_per_rank).sum(dim=1)
    receive_splits = counts[
        :, local_expert_start : local_expert_start + experts_per_rank
    ].sum(dim=1)
    received = torch.empty(
        (int(receive_splits.sum().item()), activations.shape[1]),
        dtype=activations.dtype,
        device=activations.device,
    )
    dist.all_to_all_single(
        received,
        activations,
        output_split_sizes=receive_splits.tolist(),
        input_split_sizes=send_splits.tolist(),
    )
    source_chunks = []
    source_offset = 0
    for source_rank in range(world_size):
        expert_offset = source_offset
        expert_chunks = []
        for local_expert in range(experts_per_rank):
            count = int(counts[source_rank, local_expert_start + local_expert].item())
            expert_chunks.append(received[expert_offset : expert_offset + count])
            expert_offset += count
        source_chunks.append(expert_chunks)
        source_offset += int(receive_splits[source_rank].item())
    x_list = []
    for local_expert in range(experts_per_rank):
        expert_input = torch.cat(
            [
                source_chunks[source_rank][local_expert]
                for source_rank in range(world_size)
            ],
            dim=0,
        )
        x_list.append(expert_input)
    out_list = torch_npu.npu_grouped_matmul(
        x=x_list,
        weight=[weights[local_expert] for local_expert in range(experts_per_rank)],
        group_type=0,
        split_item=2,
    )
    output = out_list[0]
    padded = torch.zeros(
        (world_size * activations.shape[0], weights.shape[-1]),
        dtype=output.dtype,
        device=output.device,
    )
    padded[: output.shape[0]] = output
    return padded


def host_store():
    """Return the torchrun TCPStore without submitting an HCCL operation."""
    from torch.distributed.distributed_c10d import _get_default_store

    return _get_default_store()


def compile_only_probe() -> None:
    """Compile representative UDMA kernels through the real Ascend backend."""
    from triton.runtime import driver

    target = driver.active.get_current_target()
    compile_shapes = (
        (1024, 1024, 1024, _effective_tiles(1024, 1024, 1024)),
        (10240, 10240, 10240, _effective_tiles(10240, 10240, 10240)),
    )
    dispatch_common = {"activations": "*fp16", "grouped_input": "*fp16", "k": "i32"}
    probe_signal_type = "*u64" if "950" in target.arch else "*i32"
    probe_signal_stride = 8 if probe_signal_type == "*u64" else 16
    for (
        max_m,
        k,
        _,
        (dispatch_block_m, dispatch_block_k, gmm_block_m, gmm_block_n, gmm_block_k),
    ) in compile_shapes:
        for world_size in (2, 4):
            triton_compile(
                ASTSource(
                    _udma_dispatch_kernel,
                    {
                        **dispatch_common,
                        "expert_source_offsets": "*i32",
                        "expert_direct_offsets": "*i32",
                        "expert_token_counts": "*i32",
                        "local_source_offsets": "*i32",
                        "local_direct_offsets": "*i32",
                        "local_token_counts": "*i32",
                        "local_tile_offsets": "*i32",
                        "ready_signals": probe_signal_type,
                        "rank_id": "i32",
                        "world_size": "i32",
                        "signal_stride": "i32",
                        "element_bytes": "i32",
                    },
                    constants={
                        "rank_id": 0,
                        "world_size": world_size,
                        "k": k,
                        "experts_per_rank": 2,
                        "signal_stride": probe_signal_stride,
                        "element_bytes": 2,
                        "local_program_start": max(1, world_size - 1),
                        "block_m": dispatch_block_m,
                        "block_k": dispatch_block_k,
                    },
                ),
                target=target,
            )
    triton_compile(
        ASTSource(
            _wait_remote_sources_ready_kernel,
            {
                "grouped_input": "*fp16",
                "ready_signals": probe_signal_type,
                "wait_source_ranks": "*i32",
                "wait_direct_offsets": "*i32",
                "k": "i32",
                "signal_stride": "i32",
            },
            constants={
                "k": 8,
                "signal_stride": probe_signal_stride,
            },
        ),
        target=target,
    )
    triton_compile(
        ASTSource(
            _zero_ready_signals_kernel,
            {
                "ready_signals": probe_signal_type,
                "signal_elements": "i32",
                "block": "i32",
            },
            constants={
                "signal_elements": probe_signal_stride * 4,
                "block": SIGNAL_ZERO_BLOCK,
            },
        ),
        target=target,
    )
    for max_m, k, n, (_, _, block_m, block_n, block_k) in compile_shapes:
        triton_compile(
            ASTSource(
                _zero_output_rows_kernel,
                {
                    "output": "*fp16",
                    "row_start": "i32",
                    "row_end": "i32",
                    "n": "i32",
                    "block_m": "i32",
                    "block_n": "i32",
                    "n_tiles": "i32",
                },
                constants={
                    "n": n,
                    "block_m": block_m,
                    "block_n": block_n,
                    "n_tiles": triton.cdiv(n, block_n),
                },
            ),
            target=target,
        )
        triton_compile(
            ASTSource(
                _expert_grouped_matmul_all_kernel,
                {
                    "grouped_input": "*fp16",
                    "weights": "*fp16",
                    "output": "*fp16",
                    "group_offsets": "*i32",
                    "group_tile_offsets": "*i32",
                    "k": "i32",
                    "n": "i32",
                    "block_m": "i32",
                    "block_n": "i32",
                    "block_k": "i32",
                    "num_n_tiles": "i32",
                },
                constants={
                    "experts_per_rank": 2,
                    "k": k,
                    "n": n,
                    "block_m": block_m,
                    "block_n": block_n,
                    "block_k": block_k,
                    "num_n_tiles": triton.cdiv(n, block_n),
                },
            ),
            target=target,
            options={"enable_dynamic_cv_pipeline": False},
        )
    print(f"UDMA_COMPILE_ONLY_OK target={target.arch}", flush=True)


@triton.jit
def _udma_dispatch_kernel(
    activations,
    grouped_input,
    expert_source_offsets,
    expert_direct_offsets,
    expert_token_counts,
    local_source_offsets,
    local_direct_offsets,
    local_token_counts,
    local_tile_offsets,
    ready_signals,
    rank_id: tl.constexpr,
    world_size: tl.constexpr,
    experts_per_rank: tl.constexpr,
    k: tl.constexpr,
    signal_stride: tl.constexpr,
    element_bytes: tl.constexpr,
    local_program_start: tl.constexpr,
    block_m: tl.constexpr,
    block_k: tl.constexpr,
):
    """Send remote peers' segments and copy local self segments in one launch."""
    program = tl.program_id(axis=0)
    if program < local_program_start:
        peer_index = program
        destination_rank = peer_index + (peer_index >= rank_id)
        if destination_rank < world_size:
            expert_start = destination_rank * experts_per_rank
            peer_rows = 0
            for local_expert in tl.static_range(experts_per_rank):
                global_expert = expert_start + local_expert
                rows = tl.load(expert_token_counts + global_expert)
                peer_rows += rows
                if rows > 0:
                    source_offset = tl.load(expert_source_offsets + global_expert)
                    direct_offset = tl.load(expert_direct_offsets + global_expert)
                    libaclshmem_device.putmem(
                        grouped_input + direct_offset * k,
                        activations + source_offset * k,
                        rows * k * element_bytes,
                        destination_rank,
                    )
            if peer_rows > 0:
                # Complete all asynchronous puts before publishing one peer signal.
                # A fence orders writes but does not wait for remote landing.
                libaclshmem_device.quiet()
                dl.notify(
                    ready_signals + rank_id * signal_stride,
                    destination_rank.to(tl.int32),
                )
    else:
        local_program = program - local_program_start
        k_block = local_program % tl.cdiv(k, block_k)
        tile_id = local_program // tl.cdiv(k, block_k)
        expert = 0
        for index in tl.static_range(1, experts_per_rank + 1):
            expert += tl.where(tl.load(local_tile_offsets + index) <= tile_id, 1, 0)
        expert = tl.minimum(expert, experts_per_rank - 1)
        local_tile_m = tile_id - tl.load(local_tile_offsets + expert)
        source_offset = tl.load(local_source_offsets + expert)
        direct_offset = tl.load(local_direct_offsets + expert)
        token_count = tl.load(local_token_counts + expert)
        rows = local_tile_m * block_m + tl.arange(0, block_m)
        columns = k_block * block_k + tl.arange(0, block_k)
        offsets = rows[:, None] * k + columns[None, :]
        mask = (rows[:, None] < token_count) & (columns[None, :] < k)
        values = tl.load(
            activations + source_offset * k + offsets,
            mask=mask,
            other=0.0,
        )
        tl.store(grouped_input + direct_offset * k + offsets, values, mask=mask)


@triton.jit
def _wait_remote_sources_ready_kernel(
    grouped_input,
    ready_signals,
    wait_source_ranks,
    wait_direct_offsets,
    k: tl.constexpr,
    signal_stride: tl.constexpr,
):
    """Wait for every remote source payload in parallel and preserve dependencies."""
    program = tl.program_id(axis=0)
    source_rank = tl.load(wait_source_ranks + program)
    direct_offset = tl.load(wait_direct_offsets + program)
    signal = ready_signals + source_rank * signal_stride
    token = dl.wait(signal, 1, "gpu", "acquire")
    source = dl.consume_token(grouped_input + direct_offset * k, token)
    value = tl.load(source)
    tl.store(source, value)


@triton.jit
def _zero_ready_signals_kernel(
    ready_signals,
    signal_elements: tl.constexpr,
    block: tl.constexpr,
):
    """Clear ACLSHMEM signal slots without invoking an unsupported ACLNN op."""
    offsets = tl.program_id(axis=0) * block + tl.arange(0, block)
    tl.store(ready_signals + offsets, 0, mask=offsets < signal_elements)


def _clear_ready_signals(ready_signals: torch.Tensor) -> None:
    """Clear the symmetric ready slots through a pure Vector Triton kernel."""
    signal_elements = ready_signals.numel()
    _zero_ready_signals_kernel[(triton.cdiv(signal_elements, SIGNAL_ZERO_BLOCK),)](
        ready_signals,
        signal_elements=signal_elements,
        block=SIGNAL_ZERO_BLOCK,
    )


@triton.jit
def _zero_output_rows_kernel(
    output,
    row_start,
    row_end,
    n: tl.constexpr,
    block_m: tl.constexpr,
    block_n: tl.constexpr,
    n_tiles: tl.constexpr,
):
    """Zero the output row band [row_start, row_end) with a persistent Vector grid."""
    pid = tl.program_id(axis=0)
    ncore = tl.num_programs(axis=0)
    band_tiles = tl.cdiv(row_end - row_start, block_m)
    for task in range(pid, band_tiles * n_tiles, ncore):
        tile_m = task // n_tiles
        tile_n = task % n_tiles
        rows = row_start + tile_m * block_m + tl.arange(0, block_m)
        columns = tile_n * block_n + tl.arange(0, block_n)
        tl.store(
            output + rows[:, None] * n + columns[None, :],
            tl.zeros((block_m, block_n), dtype=output.dtype.element_ty),
            mask=(rows[:, None] < row_end) & (columns[None, :] < n),
        )


def _clear_output_rows(
    output: torch.Tensor,
    row_start: int,
    row_end: int,
    block_m: int,
    block_n: int,
) -> None:
    """Zero output rows [row_start, row_end); skip the launch for an empty band."""
    if row_end <= row_start:
        return
    _, n = output.shape
    n_tiles = triton.cdiv(n, block_n)
    band_tiles = triton.cdiv(row_end - row_start, block_m)
    _zero_output_rows_kernel[(min(_aivector_core_num(), band_tiles * n_tiles),)](
        output,
        row_start,
        row_end,
        n=n,
        block_m=block_m,
        block_n=block_n,
        n_tiles=n_tiles,
    )


@dataclass
class OutputTailGuard:
    """Keep the unused output tail zero while avoiding per-round clear launches.

    ``valid_rows`` is the row count written by the previous invocation and every
    row at or beyond it is guaranteed to be zero.  Only a shrinking route makes
    rows dirty, so a fixed-route benchmark issues no clear launch at all.
    """

    capacity_rows: int
    valid_rows: int

    @classmethod
    def create(cls, capacity_rows: int) -> "OutputTailGuard":
        """Start with the whole buffer treated as tail so the first round clears it."""
        return cls(capacity_rows=capacity_rows, valid_rows=capacity_rows)


def _maintain_output_tail(
    output: torch.Tensor,
    valid_rows: int,
    tail_guard: OutputTailGuard,
    block_m: int,
    block_n: int,
) -> None:
    """Zero the dirty tail band after a shrinking route, then advance the watermark."""
    if valid_rows > tail_guard.capacity_rows:
        raise ValueError(
            f"valid rows {valid_rows} exceed output capacity {tail_guard.capacity_rows}"
        )
    if valid_rows < tail_guard.valid_rows:
        _clear_output_rows(output, valid_rows, tail_guard.valid_rows, block_m, block_n)
    tail_guard.valid_rows = valid_rows


def gather_timings(
    store, tag: str, timings: list[float], rank: int, world_size: int
) -> list[list[float]]:
    """Gather timing vectors through TCPStore instead of an HCCL collective."""
    key_prefix = f"alltoallv_gmm_udma/{tag}"
    store.set(f"{key_prefix}/{rank}", json.dumps(timings))
    gathered = [
        json.loads(store.get(f"{key_prefix}/{peer}").decode("utf-8"))
        for peer in range(world_size)
    ]
    return [
        [float(gathered[peer][index]) for peer in range(world_size)]
        for index in range(len(timings))
    ]


@triton.jit
def _expert_grouped_matmul_all_kernel(
    grouped_input,
    weights,
    output,
    group_offsets,
    group_tile_offsets,
    experts_per_rank: tl.constexpr,
    k: tl.constexpr,
    n: tl.constexpr,
    block_m: tl.constexpr,
    block_n: tl.constexpr,
    block_k: tl.constexpr,
    num_n_tiles: tl.constexpr,
):
    """Compute every local expert in one bounded-persistent grid."""
    tile_idx = tl.program_id(axis=0)
    num_programs = tl.num_programs(axis=0)
    total_tiles = tl.load(group_tile_offsets + experts_per_rank) * num_n_tiles
    while tile_idx < total_tiles:
        tile_m = tile_idx // num_n_tiles
        tile_n = tile_idx % num_n_tiles
        expert = 0
        for index in tl.static_range(1, experts_per_rank + 1):
            expert += tl.where(tl.load(group_tile_offsets + index) <= tile_m, 1, 0)
        expert = tl.minimum(expert, experts_per_rank - 1)
        local_tile_m = tile_m - tl.load(group_tile_offsets + expert)
        group_start = tl.load(group_offsets + expert)
        group_end = tl.load(group_offsets + expert + 1)
        rows = local_tile_m * block_m + tl.arange(0, block_m)
        columns = tile_n * block_n + tl.arange(0, block_n)
        accumulator = tl.zeros((block_m, block_n), dtype=tl.float32)
        for k_tile in range(tl.cdiv(k, block_k)):
            k_offsets = k_tile * block_k + tl.arange(0, block_k)
            lhs_ptrs = (
                grouped_input + (group_start + rows[:, None]) * k + k_offsets[None, :]
            )
            rhs_ptrs = (
                weights + expert * k * n + k_offsets[:, None] * n + columns[None, :]
            )
            tl.multiple_of(lhs_ptrs, [16, 16])
            tl.multiple_of(rhs_ptrs, [16, 16])
            lhs = tl.load(
                lhs_ptrs,
                mask=(rows[:, None] < group_end - group_start)
                & (k_offsets[None, :] < k),
                other=0.0,
            )
            rhs = tl.load(
                rhs_ptrs,
                mask=(k_offsets[:, None] < k) & (columns[None, :] < n),
                other=0.0,
            )
            accumulator += tl.dot(lhs, rhs)
        tl.store(
            output + (group_start + rows[:, None]) * n + columns[None, :],
            accumulator.to(output.dtype.element_ty),
            mask=(rows[:, None] < group_end - group_start) & (columns[None, :] < n),
        )
        tile_idx += num_programs


def _build_grouped_gmm_routes(
    token_counts: torch.Tensor,
    rank: int,
    world_size: int,
    experts_per_rank: int,
) -> tuple[list[tuple[int, int, int]], list[tuple[int, int, int]]]:
    """Build source routes and contiguous local-expert groups for one route snapshot."""
    local_expert_start = rank * experts_per_rank
    routes = []
    output_offset = 0
    expert_groups = []
    for local_expert in range(experts_per_rank):
        group_offset = output_offset
        group_token_count = 0
        for source_rank in range(world_size):
            global_expert = local_expert_start + local_expert
            token_count = int(token_counts[source_rank, global_expert].item())
            if token_count:
                routes.append((source_rank, output_offset, token_count))
                output_offset += token_count
                group_token_count += token_count
        if group_token_count:
            expert_groups.append((local_expert, group_offset, group_token_count))
    return routes, expert_groups


def _build_remote_wait_routes(
    rank: int,
    experts_per_rank: int,
    gmm_routes: list[tuple[int, int, int]],
    expert_groups: list[tuple[int, int, int]],
    dispatch_routes: DispatchRoutes,
) -> RemoteWaitRoutes:
    """Build one parallel wait launch for every remote source that this rank consumes."""
    source_ranks = []
    direct_offsets = []
    ready_sources = {rank}
    for local_expert, group_offset, token_count in expert_groups:
        group_end = group_offset + token_count
        for source_rank, output_offset, source_token_count in gmm_routes:
            if not group_offset <= output_offset < group_end:
                continue
            if source_rank != rank and source_rank not in ready_sources:
                source_ranks.append(source_rank)
                direct_offsets.append(
                    dispatch_routes.direct_offsets_by_source[source_rank][
                        rank * experts_per_rank + local_expert
                    ]
                )
                ready_sources.add(source_rank)
    return RemoteWaitRoutes(
        source_ranks=torch.tensor(source_ranks, dtype=torch.int32).npu(),
        direct_offsets=torch.tensor(direct_offsets, dtype=torch.int32).npu(),
        count=len(source_ranks),
    )


def _build_merged_gmm_metadata(
    token_counts: torch.Tensor,
    rank: int,
    world_size: int,
    experts_per_rank: int,
    gmm_block_m: int,
    dispatch_block_m: int,
    routes: DispatchRoutes,
) -> tuple[
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    int,
    torch.Tensor,
    torch.Tensor,
    int,
    int,
]:
    """Build metadata for the dispatch launch, the merged GMM, and the output tail.

    The local self-copy tiles follow ``dispatch_block_m`` while the grouped GEMM tiles follow
    ``gmm_block_m``; the two tilings are independent on purpose so both knobs stay effective.
    """
    local_expert_start = rank * experts_per_rank
    group_sizes = token_counts[
        :, local_expert_start : local_expert_start + experts_per_rank
    ].sum(dim=0)
    group_offsets = torch.empty(experts_per_rank + 1, dtype=torch.int32)
    group_offsets[0] = 0
    group_offsets[1:] = torch.cumsum(group_sizes, dim=0)
    group_tile_offsets = torch.empty(experts_per_rank + 1, dtype=torch.int32)
    group_tile_offsets[0] = 0
    group_tile_offsets[1:] = torch.cumsum(
        (group_sizes + gmm_block_m - 1) // gmm_block_m, dim=0
    )
    local_counts = token_counts[
        rank, local_expert_start : local_expert_start + experts_per_rank
    ]
    local_source_offsets = torch.empty(experts_per_rank, dtype=torch.int32)
    local_direct_offsets = torch.empty(experts_per_rank, dtype=torch.int32)
    local_token_counts = torch.empty(experts_per_rank, dtype=torch.int32)
    local_tile_offsets = torch.empty(experts_per_rank + 1, dtype=torch.int32)
    local_tile_offsets[0] = 0
    for local_expert in range(experts_per_rank):
        global_expert = local_expert_start + local_expert
        local_source_offsets[local_expert] = routes.expert_source_offsets_host[
            global_expert
        ]
        local_direct_offsets[local_expert] = routes.expert_direct_offsets_host[
            global_expert
        ]
        local_token_counts[local_expert] = int(local_counts[local_expert].item())
    local_tile_offsets[1:] = torch.cumsum(
        (local_counts + dispatch_block_m - 1) // dispatch_block_m, dim=0
    )
    return (
        local_source_offsets.npu(),
        local_direct_offsets.npu(),
        local_token_counts.npu(),
        local_tile_offsets.npu(),
        int(local_tile_offsets[-1].item()),
        group_offsets.npu(),
        group_tile_offsets.npu(),
        int(group_tile_offsets[-1].item()),
        int(group_sizes.sum().item()),
    )


def host_barrier(store, tag: str, rank: int, world_size: int) -> None:
    """Synchronize ranks through TCPStore after ACLSHMEM UDMA starts.

    HCCL collectives submit ``HcclLaunchAicpuKernel`` tasks.  Do not use them
    after ACLSHMEM UDMA has begun because their AICPU communication state is
    not composable in this runtime.
    """
    key_prefix = f"alltoallv_gmm_udma/{tag}"
    store.set(f"{key_prefix}/{rank}", "1")
    for peer in range(world_size):
        store.get(f"{key_prefix}/{peer}")


def validate_against_torch_npu(
    store,
    tag: str,
    actual: torch.Tensor,
    expected: torch.Tensor,
    rank: int,
    world_size: int,
) -> None:
    """Validate all ranks without an HCCL all-reduce after UDMA has started."""
    error = ""
    try:
        torch.testing.assert_close(actual, expected, rtol=2**-8, atol=2**-8)
    except AssertionError as exception:
        difference = (actual.float() - expected.float()).abs()
        flat_index = int(difference.argmax().item())
        row, column = divmod(flat_index, actual.shape[-1])
        error = (
            f"{exception}; first_max_error=({row}, {column}) "
            f"actual={float(actual[row, column].item()):.6g} "
            f"expected={float(expected[row, column].item()):.6g} "
            f"max_abs_error={float(difference.max().item()):.6g}"
        )
    key_prefix = f"alltoallv_gmm_udma/{tag}"
    store.set(f"{key_prefix}/{rank}", error)
    errors = [
        store.get(f"{key_prefix}/{peer}").decode("utf-8") for peer in range(world_size)
    ]
    if any(errors):
        details = "; ".join(
            f"rank{peer}: {message}" for peer, message in enumerate(errors) if message
        )
        print(f"UDMA_VALIDATION_MISMATCH {details}", flush=True)
        raise AssertionError(
            f"Triton output does not match torch_npu on rank(s): {details}"
        )


@dataclass(frozen=True)
class DispatchRoutes:
    """Host and device metadata for one UDMA all-to-allv dispatch snapshot."""

    expert_source_offsets: torch.Tensor
    expert_direct_offsets: torch.Tensor
    expert_token_counts: torch.Tensor
    expert_direct_offsets_host: tuple[int, ...]
    direct_offsets_by_source: tuple[tuple[int, ...], ...]
    expert_source_offsets_host: tuple[int, ...]


@dataclass(frozen=True)
class RemoteWaitRoutes:
    """Device arrays for one parallel launch that waits for every remote source."""

    source_ranks: torch.Tensor
    direct_offsets: torch.Tensor
    count: int


def _build_dispatch_routes(
    host_token_counts: torch.Tensor,
    rank: int,
    world_size: int,
    experts_per_rank: int,
) -> DispatchRoutes:
    """Build direct expert-major dispatch metadata for one route snapshot.

    The snapshot is built once before validation or benchmarking and reused for
    all invocations in that epoch, avoiding per-iteration CPU copies and loops.
    """
    local_counts = host_token_counts[rank]
    expert_source_offsets, expert_direct_offsets = direct_grouped_input_offsets(
        host_token_counts, rank, world_size, experts_per_rank
    )
    direct_offsets_by_source = tuple(
        tuple(
            direct_grouped_input_offsets(
                host_token_counts, source, world_size, experts_per_rank
            )[1]
        )
        for source in range(world_size)
    )
    return DispatchRoutes(
        expert_source_offsets=torch.tensor(
            expert_source_offsets, dtype=torch.int32
        ).npu(),
        expert_direct_offsets=torch.tensor(
            expert_direct_offsets, dtype=torch.int32
        ).npu(),
        expert_token_counts=local_counts.to(dtype=torch.int32).npu(),
        expert_direct_offsets_host=tuple(expert_direct_offsets),
        direct_offsets_by_source=direct_offsets_by_source,
        expert_source_offsets_host=tuple(expert_source_offsets),
    )


def _launch_udma_dispatch(
    activations: torch.Tensor,
    grouped_input: torch.Tensor,
    ready_signals: torch.Tensor,
    rank: int,
    world_size: int,
    experts_per_rank: int,
    routes: DispatchRoutes,
    local_source_offsets: torch.Tensor,
    local_direct_offsets: torch.Tensor,
    local_token_counts: torch.Tensor,
    local_tile_offsets: torch.Tensor,
    local_m_tiles: int,
    dispatch_block_m: int,
    dispatch_block_k: int,
) -> None:
    """Submit one launch that sends remote peers and copies local self segments.

    ``local_tile_offsets``/``local_m_tiles`` must be built with ``dispatch_block_m`` so the local
    copy tiling stays consistent with the grid below.
    """
    _, k = activations.shape
    local_program_start = max(1, world_size - 1)
    program_count = local_program_start + local_m_tiles * triton.cdiv(
        k, dispatch_block_k
    )
    _udma_dispatch_kernel[(program_count,)](
        activations,
        grouped_input,
        routes.expert_source_offsets,
        routes.expert_direct_offsets,
        routes.expert_token_counts,
        local_source_offsets,
        local_direct_offsets,
        local_token_counts,
        local_tile_offsets,
        ready_signals,
        rank_id=rank,
        world_size=world_size,
        experts_per_rank=experts_per_rank,
        k=k,
        signal_stride=SIGNAL_STRIDE,
        element_bytes=activations.element_size(),
        local_program_start=local_program_start,
        block_m=dispatch_block_m,
        block_k=dispatch_block_k,
    )


def _launch_gmm(
    ready_signals: torch.Tensor,
    grouped_input: torch.Tensor,
    weights: torch.Tensor,
    output: torch.Tensor,
    block_m: int,
    block_n: int,
    block_k: int,
    experts_per_rank: int,
    remote_wait: RemoteWaitRoutes,
    group_offsets: torch.Tensor,
    group_tile_offsets: torch.Tensor,
    total_m_tiles: int,
) -> None:
    """Wait for every remote source in one launch, then run one merged GMM."""
    k = grouped_input.shape[-1]
    n = output.shape[-1]
    if remote_wait.count:
        _wait_remote_sources_ready_kernel[(remote_wait.count,)](
            grouped_input,
            ready_signals,
            remote_wait.source_ranks,
            remote_wait.direct_offsets,
            k=k,
            signal_stride=SIGNAL_STRIDE,
        )
    num_n_tiles = triton.cdiv(n, block_n)
    total_tiles = total_m_tiles * num_n_tiles
    num_programs = max(1, min(_aicore_num(), total_tiles))
    _expert_grouped_matmul_all_kernel[(num_programs,)](
        grouped_input,
        weights,
        output,
        group_offsets,
        group_tile_offsets,
        experts_per_rank=experts_per_rank,
        k=k,
        n=n,
        block_m=block_m,
        block_n=block_n,
        block_k=block_k,
        num_n_tiles=num_n_tiles,
        enable_dynamic_cv_pipeline=False,
    )


def launch_alltoallv_gmm_udma(
    activations: torch.Tensor,
    weights: torch.Tensor,
    ready_signals: torch.Tensor,
    grouped_input: torch.Tensor,
    output: torch.Tensor,
    rank: int,
    world_size: int,
    dispatch_block_m: int,
    dispatch_block_k: int,
    gmm_block_m: int,
    gmm_block_n: int,
    gmm_block_k: int,
    routes: DispatchRoutes,
    remote_wait: RemoteWaitRoutes,
    tail_guard: OutputTailGuard,
    merged_metadata: tuple[
        torch.Tensor,
        torch.Tensor,
        torch.Tensor,
        torch.Tensor,
        int,
        torch.Tensor,
        torch.Tensor,
        int,
        int,
    ],
) -> None:
    """Maintain the output tail, then run one fused dispatch/copy, waits, and one GMM.

    The caller must establish a cross-rank completion boundary (for example a
    TCPStore barrier plus ``torch.npu.synchronize``) before every round so the
    single grouped-input buffer is not overwritten while a slower rank is still
    reading the previous round.
    """
    if activations.dtype != torch.float16 or weights.dtype != torch.float16:
        raise TypeError(
            "the UDMA tutorial currently supports float16 activations and weights only"
        )
    (
        local_source_offsets,
        local_direct_offsets,
        local_token_counts,
        local_tile_offsets,
        local_m_tiles,
        group_offsets,
        group_tile_offsets,
        total_m_tiles,
        valid_rows,
    ) = merged_metadata
    # Grouped GEMM only rewrites the valid prefix, so rows left behind by a
    # longer previous route must be zeroed before this round's result is read.
    _maintain_output_tail(output, valid_rows, tail_guard, gmm_block_m, gmm_block_n)
    _launch_udma_dispatch(
        activations=activations,
        grouped_input=grouped_input,
        ready_signals=ready_signals,
        rank=rank,
        world_size=world_size,
        experts_per_rank=routes.expert_token_counts.numel() // world_size,
        routes=routes,
        local_source_offsets=local_source_offsets,
        local_direct_offsets=local_direct_offsets,
        local_token_counts=local_token_counts,
        local_tile_offsets=local_tile_offsets,
        local_m_tiles=local_m_tiles,
        dispatch_block_m=dispatch_block_m,
        dispatch_block_k=dispatch_block_k,
    )
    # Establish a global visibility frontier before grouped GEMM reads the
    # direct-write buffer.  The ready notify/wait protocol already orders the
    # remote payload stores; the same stream orders the local copy, so the
    # dispatch-side collective barrier is redundant and is skipped.
    _launch_gmm(
        ready_signals,
        grouped_input,
        weights,
        output,
        gmm_block_m,
        gmm_block_n,
        gmm_block_k,
        routes.expert_token_counts.numel() // world_size,
        remote_wait,
        group_offsets,
        group_tile_offsets,
        total_m_tiles,
    )


def require_udma_device(local_rank: int) -> None:
    """Reject non-950 systems instead of silently running an unsupported path."""
    name = os.environ.get("ASCEND_SOC_VERSION", "")
    get_device_name = getattr(torch.npu, "get_device_name", None)
    if get_device_name is not None:
        name = str(get_device_name(local_rank)) or name
    if "950" not in name:
        raise RuntimeError(
            "AllToAllV-GMM UDMA requires Ascend 950; detected "
            f"{name or 'an unknown SoC'}. Use Tutorial 10 for the MTE path."
        )


def run() -> None:
    """Initialize distributed state and run the fixed-seed correctness self-test."""
    if os.environ.get("TRITON_COMPILE_ONLY", "0") == "1":
        compile_only_probe()
        return
    local_rank = int(os.environ.get("LOCAL_RANK", "0"))
    torch.npu.set_device(local_rank)
    os.environ.setdefault("HCCL_NPU_SOCKET_PORT_RANGE", "auto")
    require_udma_device(local_rank)
    dist.init_process_group("hccl")
    rank = dist.get_rank()
    world_size = dist.get_world_size()
    # Create the HCCL communicator before ACLSHMEM.  No HCCL collective may be
    # submitted after ACLSHMEM UDMA begins.
    dist.barrier(device_ids=[local_rank])
    store = host_store()
    m = int(os.environ.get("TRITON_M", 64))
    k = int(os.environ.get("TRITON_K", 128))
    n = int(os.environ.get("TRITON_N", 128))
    experts_per_rank = int(os.environ.get("TRITON_EXPERTS_PER_RANK", 2))
    dispatch_block_m, dispatch_block_k, gmm_block_m, gmm_block_n, gmm_block_k = (
        _effective_tiles(m, k, n)
    )
    validation_iterations = int(os.environ.get("TRITON_VALIDATION_ITERS", 1))
    sparse = os.environ.get("TRITON_SPARSE", "1") == "1"
    route_modes = tuple(
        value.strip()
        for value in os.environ.get("TRITON_ROUTE_MODES", "random").split(",")
        if value.strip()
    )
    if len(route_modes) != 1:
        raise ValueError(
            "TRITON_ROUTE_MODES must contain exactly one mode when running the tutorial script"
        )
    route_mode = route_modes[0]
    if (
        min(
            m,
            k,
            n,
            experts_per_rank,
            dispatch_block_m,
            dispatch_block_k,
            gmm_block_m,
            gmm_block_n,
            gmm_block_k,
        )
        <= 0
    ):
        raise ValueError("shape and block-size variables must be positive")
    if validation_iterations < 0:
        raise ValueError("TRITON_VALIDATION_ITERS must be non-negative")

    grouped_input: torch.Tensor | None = None
    ready_signals: torch.Tensor | None = None
    try:
        seed = 20260811
        torch.manual_seed(seed + rank)
        weights = torch.randn((experts_per_rank, k, n), dtype=torch.float16).npu()

        def prepare_invocation(
            epoch: int,
        ) -> tuple[
            RouteSample,
            DispatchRoutes,
            RemoteWaitRoutes,
            tuple[
                torch.Tensor,
                torch.Tensor,
                torch.Tensor,
                torch.Tensor,
                int,
                torch.Tensor,
                torch.Tensor,
                int,
                int,
            ],
        ]:
            sample = prepare_route(
                m,
                k,
                world_size,
                experts_per_rank,
                rank,
                epoch,
                route_mode,
                store,
                sparse,
            )
            dispatch_routes = _build_dispatch_routes(
                sample.token_counts, rank, world_size, experts_per_rank
            )
            gmm_routes, expert_groups = _build_grouped_gmm_routes(
                sample.token_counts, rank, world_size, experts_per_rank
            )
            remote_wait = _build_remote_wait_routes(
                rank, experts_per_rank, gmm_routes, expert_groups, dispatch_routes
            )
            merged_metadata = _build_merged_gmm_metadata(
                sample.token_counts,
                rank,
                world_size,
                experts_per_rank,
                gmm_block_m,
                dispatch_block_m,
                dispatch_routes,
            )
            return sample, dispatch_routes, remote_wait, merged_metadata

        validation_samples = []
        if validation_iterations:
            for iteration in range(validation_iterations):
                sample, dispatch_routes, remote_wait, merged_metadata = (
                    prepare_invocation(iteration)
                )
                expected = _reference_output(
                    sample.activations,
                    weights,
                    sample.token_counts,
                    rank,
                    world_size,
                    experts_per_rank,
                )
                validation_samples.append(
                    (sample, dispatch_routes, remote_wait, merged_metadata, expected)
                )
            torch.npu.synchronize()

        if ash.set_conf_store_tls(False, "") != 0:
            raise RuntimeError("aclshmem set_conf_store_tls failed")
        attributes = ash.InitAttr()
        attributes.my_rank = rank
        attributes.n_ranks = world_size
        ready_signal_bytes = (
            world_size
            * SIGNAL_STRIDE
            * torch.tensor([], dtype=SIGNAL_DTYPE).element_size()
        )
        attributes.local_mem_size = symmetric_memory_size(
            world_size, m, k, extra_bytes=ready_signal_bytes
        )
        address = os.environ.get("ASH_MASTER_ADDR", "") or os.environ.get(
            "MASTER_ADDR", "127.0.0.1"
        )
        port = os.environ.get("ASH_MASTER_PORT", "28980")
        attributes.ip_port = f"tcp://{address}:{port}"
        attributes.option_attr.data_op_engine_type = ash.OpEngineType.UDMA
        if rank == 0:
            print(
                f"ALLTOALLV_GMM_LOCAL_MEM_SIZE_BYTES={attributes.local_mem_size}",
                flush=True,
            )
        if ash.aclshmem_init(attributes) != 0:
            raise RuntimeError("aclshmem_init failed for UDMA")
        grouped_input = ash.aclshmem_create_tensor(
            [world_size * m, k], dtype=torch.float16, device_id=local_rank
        )
        ready_signals = ash.aclshmem_create_tensor(
            [world_size * SIGNAL_STRIDE], dtype=SIGNAL_DTYPE, device_id=local_rank
        )
        output = torch.empty((world_size * m, n), dtype=torch.float16).npu()
        tail_guard = OutputTailGuard.create(world_size * m)

        def invoke(
            activations: torch.Tensor,
            dispatch_routes: DispatchRoutes,
            remote_wait: RemoteWaitRoutes,
            merged_metadata: tuple[
                torch.Tensor,
                torch.Tensor,
                torch.Tensor,
                torch.Tensor,
                int,
                torch.Tensor,
                torch.Tensor,
                int,
                int,
            ],
        ) -> torch.Tensor:
            launch_alltoallv_gmm_udma(
                activations,
                weights,
                ready_signals,
                grouped_input,
                output,
                rank,
                world_size,
                dispatch_block_m,
                dispatch_block_k,
                gmm_block_m,
                gmm_block_n,
                gmm_block_k,
                routes=dispatch_routes,
                remote_wait=remote_wait,
                tail_guard=tail_guard,
                merged_metadata=merged_metadata,
            )
            return output

        def reset_ready_signals() -> None:
            if ready_signals is None:
                raise RuntimeError("ready signal buffer is unavailable")
            _clear_ready_signals(ready_signals)
            torch.npu.synchronize()

        if validation_iterations:
            for iteration, (
                sample,
                dispatch_routes,
                remote_wait,
                merged_metadata,
                expected,
            ) in enumerate(validation_samples):
                reset_ready_signals()
                host_barrier(
                    store,
                    f"ready_signal_reset_validation_{iteration}",
                    rank,
                    world_size,
                )
                actual = invoke(
                    sample.activations, dispatch_routes, remote_wait, merged_metadata
                )
                torch.npu.synchronize()
                if expected is None:
                    raise RuntimeError("torch_npu reference output is unavailable")
                validate_against_torch_npu(
                    store, f"validation_{iteration}", actual, expected, rank, world_size
                )
                host_barrier(store, f"validation_done_{iteration}", rank, world_size)
                if rank == 0:
                    print(
                        f"AllToAllV-GMM UDMA tutorial iteration {iteration + 1}/{validation_iterations} passed",
                        flush=True,
                    )
    finally:
        if ready_signals is not None:
            ash.aclshmem_free_tensor(ready_signals)
        if grouped_input is not None:
            ash.aclshmem_free_tensor(grouped_input)
        ash.aclshmem_finalize()
        if dist.is_initialized():
            dist.destroy_process_group()


if __name__ == "__main__":
    run()
