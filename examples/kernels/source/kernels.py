import triton
import triton.language as tl


@triton.jit
def add_kernel(X, Y, Z, n_elements, BLOCK_SIZE: tl.constexpr):
    offsets = tl.program_id(0) * BLOCK_SIZE + tl.arange(0, BLOCK_SIZE)
    mask = offsets < n_elements
    x = tl.load(X + offsets, mask=mask, other=0)
    y = tl.load(Y + offsets, mask=mask, other=0)
    tl.store(Z + offsets, x + y, mask=mask)


@triton.jit
def vector_add(a, b, out, BLOCK: tl.constexpr):
    for tile in tl.static_range(2):
        offsets = tile * BLOCK + tl.arange(0, BLOCK)
        left = tl.load(a + offsets)
        right = tl.load(b + offsets)
        tl.store(out + offsets, left + right)


@triton.jit
def row_sum(input, out, ROWS: tl.constexpr, COLS: tl.constexpr):
    columns = tl.arange(0, COLS)
    for row in tl.static_range(ROWS):
        offsets = row * COLS + tl.full((1,), 0, tl.int32)[:, None] + columns[None, :]
        values = tl.load(input + offsets)
        total = tl.sum(values, axis=1)
        tl.store(out + row + tl.full((1,), 0, tl.int32), total)
