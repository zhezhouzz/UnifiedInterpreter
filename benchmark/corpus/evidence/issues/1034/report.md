### Observed behavior

An FP32 matmul kernel fails to compile for A5 (`Ascend950PR_9579`) with layout optimization enabled. On revision `d3ae45dad769`, memory planning reports `read before first write`.

A channel-split Fixpipe consumes a converted matmul accumulator, and the `else` branch of an `scf.if` yields that same value. Layout propagation leaves the conditional result in ND layout. The remaining conversions lower to vector transposes. After the cube/vector split, the cube-side output Fixpipe reads a buffer with no writer.

### Reproduce the layout mismatch

Download the fixture and run the following command with `bishengir-opt` built from `d3ae45dad769`. [MLIR fixture](https://gitcode.com/hocky/AscendNPU-IR/blob/cc7eb3c361c739d8973fbc143f97cf153a7aac03/bishengir/test/Dialect/HIVM/propagate-convert-layout-shared-if-yield.mlir)

```sh
bishengir-opt propagate-convert-layout-shared-if-yield.mlir --hivm-propagate-convert-layout
```

In `@shared_accumulator`, the `scf.if` returns `tensor<16x16xf32>` in ND layout.

### Expected behavior

Both branches should yield the fractal accumulator (`tensor<1x1x16x16xf32>` in the fixture). The channel-split Fixpipe should keep its existing input, and the compiler should fold the conversion after the merge into the output Fixpipe. The captured kernel compiles to a binary with the fix in [!5289](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5289). [Compare the pass output](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5289?ref=&did=35f4659b5fddbbc13df34224dd476eac9fd23894#tid-202111661)