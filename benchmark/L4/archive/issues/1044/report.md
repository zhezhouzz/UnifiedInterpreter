### 环境信息
            
```
$ uv pip list
...
torch             2.7.1+cpu
torch-npu         2.7.1.post9.dev20260827
triton-ascend     3.6.0+dev20260827215900
```
```
$ bishengir-compile --version
bishengir-compile 2.0.0 (https://nikitasyu:...@gitcode.com/Ascend/AscendNPU-IR.git 6674d03a8d18 2026-11-21) 
llvm 19.1.7 57b2ed73d65a
Release build with assertions.
```
### 🐛 问题描述
            
#1. Reproduction:
---------------------
```
$ git clone https://github.com/triton-lang/triton-ascend.git
$ cd triton-ascend
$ python3 -m pytest   third_party/ascend/unittest/pytest_ut/test_index_select_mod.py::test_index_select_extension[src_shape7-0-indice_shape7-float32] -sv
# test will not fail but incorrect usage of template library call of load_gm_to_ubuf_1d_code will present, see bellow
# get the dumps
```
or
<a href="https://gitcode.com/user-attachments/files/7494336/338e2aad46bb458cb929a3ba7d977ad3.txt" target="_blank">kernel_index_bug.mlir.txt</a>
```
$ /home/n00499118/bisheng/AscendNPU-IR/build/bin/bishengir-compile kernel_index_bug.mlir.txt --target=Ascend950PR_9579 --enable-auto-multi-buffer=True --enable-auto-bind-sub-block=True --disable-ffts --limit-auto-multi-buffer-of-local-buffer=no-limit --enable-auto-blockify-loop --enable-hfusion-compile=true  --enable-triton-kernel-compile=true --enable-vf-merge-level=1  --mlir-disable-threading --print-pass-id --mlir-print-ir-after-all >& dump.txt
```
#2. IR steps (only related subset)
---------------------
first after triton_ascend (AppendTargetDeviceSpec (hacc-append-device-spec))
```
[INFO] Using merged native A5 regbase pipeline
[PassID] hacc-append-device-spec/module/0
// -----// IR Dump After AppendTargetDeviceSpec (hacc-append-device-spec) //----- //
...
      %alloc_2 = memref.alloc() : memref<142x37xf32>
      scf.for %arg12 = %c0 to %c142 step %c1 {
        %subview_6 = memref.subview %alloc_2[%arg12, 0] [1, 37] [1, 1] : memref<142x37xf32> to memref<1x37xf32, strided<[37, 1], offset: ?>>
        annotation.mark %subview_6 {hfusion.stride_align_dims = array<i32: 0>, hfusion.stride_align_value_in_byte = array<i32: 32>} : memref<1x37xf32, strided<[37, 1], offset: ?>>
        memref.copy %subview_5, %subview_6 : memref<1x37xf32, strided<[37, 1], offset: ?>> to memref<1x37xf32, strided<[37, 1], offset: ?>>
      } {hivm.parallel_loop}
```
So, here dense 142x37xf32 tensor (in UB) alloced and fully loaded in loop in dense manner loading 37 elements (37=32+5, so if start address aligned then last 32B block will contain 5 elemens from current row and 3 elements from the next one)\
From the beginning `annotation.mark` is present wchich says (as I understand) that rows should (or must?) be aligned by 32B (so the each row's last 32B block will not contain elements of the next row)

// -----// IR Dump After HFusionFoldUnitDims (hfusion-fold-unit-dims) //----- //
```
    %alloc_2 = memref.alloc() : memref<142x37xf32>
    scf.for %arg12 = %c0 to %c142 step %c1 {
      %subview_6 = memref.subview %alloc_2[%arg12, 0] [1, 37] [1, 1] : memref<142x37xf32> to memref<1x37xf32, strided<[37, 1], offset: ?>>
      annotation.mark %subview_6 {hfusion.stride_align_dims = array<i32: 0>, hfusion.stride_align_value_in_byte = array<i32: 32>} : memref<1x37xf32, strided<[37, 1], offset: ?>>
      %collapse_shape_7 = memref.collapse_shape %subview_6 [[0, 1]] : memref<1x37xf32, strided<[37, 1], offset: ?>> into memref<37xf32, strided<[1], offset: ?>>
      memref.copy %collapse_shape, %collapse_shape_7 : memref<37xf32, strided<[1], offset: ?>> to memref<37xf32, strided<[1], offset: ?>>
    } {hivm.parallel_loop}
```
After the 2d `%subview_6` with ` annotation.mark ` created dims collapse and load became dense 1d


// -----// IR Dump After FlattenOps (hfusion-flatten-ops) //----- //
```
    %alloc_6 = memref.alloc() : memref<142x37xf32>
    %collapse_shape_7 = memref.collapse_shape %alloc_6 [[0, 1]] : memref<142x37xf32> into memref<5254xf32>
    scf.for %arg12 = %c0 to %c142 step %c1 {
      %c0_14 = arith.constant 0 : index
      %c37_15 = arith.constant 37 : index
      %22 = arith.muli %arg12, %c37_15 : index
      %23 = arith.addi %c0_14, %22 : index
      %subview_16 = memref.subview %collapse_shape_7[%23] [37] [1] : memref<5254xf32> to memref<37xf32, strided<[1], offset: ?>>
      annotation.mark %subview_16 {hfusion.stride_align_dims = array<i32: 0>, hfusion.stride_align_value_in_byte = array<i32: 32>} : memref<37xf32, strided<[1], offset: ?>>
      memref.copy %subview_13, %subview_16 : memref<37xf32, strided<[1], offset: ?>> to memref<37xf32, strided<[1], offset: ?>>
    } {hivm.parallel_loop}
```
FlattenOps makes `%subview_16` with `annotation.mark` 1d, load is 1d as before.
Here `annotation.mark` is obvious became none-sense for me, because is says that dim0 of the 1d tensor sould be aligned, but the essence of the annotation that aligned should be continguous 37-elems blocks is completelly lost already.

Then passes work as if that annotation just not exist:

// -----// IR Dump After ConvertToHIVMOp (convert-to-hivm-op) //----- //
```
      %alloc_2 = memref.alloc() : memref<5254xf32>
      scf.for %arg9 = %c0 to %c142 step %c1 {
        %23 = arith.muli %arg9, %c37 : index
        %subview_7 = memref.subview %alloc_2[%23] [37] [1] : memref<5254xf32> to memref<37xf32, strided<[1], offset: ?>>
        annotation.mark %subview_7 {hivm.stride_align_dims = array<i32: 0>, hivm.stride_align_value_in_byte = array<i32: 32>} : memref<37xf32, strided<[1], offset: ?>>
        %24 = arith.remui %23, %c8 : index
        hivm.hir.load ins(%subview_6 : memref<37xf32, strided<[1], offset: ?>>) outs(%subview_7 : memref<37xf32, strided<[1], offset: ?>>) left_padding_num = %24 : index eviction_policy = <EvictFirst>
      } {hivm.parallel_loop}
```
ConvertToHIVMOp created `hivm.hir.load` with `left_padding_num` which overlaps previous row elements if current row not aligned (almost all)

// -----// IR Dump After EnableStrideAlign (hivm-enable-stride-align) //----- //
```
        %alloc_2 = memref.alloc() : memref<5254xf32, #hivm.address_space<ub>>
        scf.for %arg10 = %c0 to %c142 step %c1 {
          %21 = affine.apply #map4()[%arg10]
          %subview_8 = memref.subview %alloc_2[%21] [37] [1] : memref<5254xf32, #hivm.address_space<ub>> to memref<37xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
          %22 = arith.remui %21, %c8 : index
          hivm.hir.load ins(%subview_7 : memref<37xf32, strided<[1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_8 : memref<37xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>) left_padding_num = %22 : index eviction_policy = <EvictFirst> core_type = <VECTOR>
        } {hivm.parallel_loop}
```
Just deletes `annotation.mark`...

// -----// IR Dump After ConvertHIVMToStandard (convert-hivm-to-std) //----- //
```
    %0 = hivm.hir.pointer_cast(%c576_i64) : memref<5254xf32, #hivm.address_space<ub>>
    %1 = hivm.hir.pointer_cast(%c22176_i64) : memref<5254xf32, #hivm.address_space<ub>>
    ...
        %15 = arith.select %14, %1, %0 : memref<5254xf32, #hivm.address_space<ub>>
        ...
        scf.for %arg10 = %c0 to %c142 step %c1 {
          %35 = affine.apply #map3()[%arg10]
          %subview_10 = memref.subview %15[%35] [37] [1] : memref<5254xf32, #hivm.address_space<ub>> to memref<37xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
          %36 = arith.remui %35, %c8 : index
          %cast_12 = memref.cast %subview_10 : memref<37xf32, strided<[1], offset: ?>, #hivm.address_space<ub>> to memref<?xf32, strided<[?], offset: ?>, #hivm.address_space<ub>>
          func.call @load_gm_to_ubuf_1d_float(%cast_11, %cast_12, %c0_i32, %cst, %36, %c0, %c0_i32) : (memref<?xf32, strided<[?], offset: ?>, #hivm.address_space<gm>>, memref<?xf32, strided<[?], offset: ?>, #hivm.address_space<ub>>, i32, f32, index, index, i32) -> ()
        } {hivm.parallel_loop}
```
So at the end `hivm.hir.load` becames the template library call, which called in the loop in dense manner with incorrect `left_padding_num`:

#3. What is the problem
---------------------
There are 2, they both prevent to implement in template library normal logic for extensive usage of DMA/NDDMA, for exmample it prevents to fix 1d cases similar to 2d described in https://gitcode.com/Ascend/AscendNPU-IR/issues/531:
1. left padding area ovelaps with previous row for most rows so actual elemets from the previous row rewrites by padding value.
2. template library may use DMA for aligned rows and writes padding elements beyond the right border up to aligned 32B boundary - that may lead to race conditions if next unaligned row loaded via NDDMA, for exaple first (aligned) row and the secod unaligned row: border 32B block contains 5 elemets from the first row (which are loaded via DMA) and 3 elemets from the second row (if load row via NDDMA (same MTE2 pipe will be used) then with small probabily (what I observed on local runs) possible that NDDMA executes before DMA and that last 3 elemens in the 32B block will contain padding values in the end instead of valid data from the second row)

the following stub in `load_gm_to_ubuf_1d_core` serves as workaroud:
```
  auto dst_ptr2 = dst->aligned + dst->offset;
  if (!isAddress32ByteAligned(dst_ptr2)) {
    INTRINSIC(pipe_barrier, PIPE_MTE2);
    load_gm_to_ubuf_nd_by_nddma_or_scalar<T, 1, DisableDCache>(
        src, dst, pad_mode, pad_value, /*left_padding_num*/0, right_padding_num,
        l2_cache_ctl);
    return;
  }
```
But it should be deleted after the given issue will be fixed.
  
  

