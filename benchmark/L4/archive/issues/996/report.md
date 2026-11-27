A tensor load shared by batch matmul and device printing can abort compilation in the V1 layout path. The same 4096 BF16 values are viewed as `4x32x32` for the Cube operand and `2x2x32x32` for printing. The print is classified as an L1 read and reaches a debug transfer that accepts only rank 2 or 3.

Related fix: [MR !4950](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/4950).

**Environment**

- Target: A5 `Ascend950PR_9579`; compilation was reproduced on CPU, without executing an NPU kernel.
- Build: Ubuntu 22 userspace, LLVM 19.1.7, assertions enabled.
- Failing baseline: `2740480f32`, with only the optional SDK build guard and HIR-only stop-option wiring applied. No print-routing, reshape, or alignment fixes were applied to that baseline.
- Layout mode: `--enable-layout-optimization=false`.

**Reproduction**

Save the following input as `batch.mlir`. It is the batch section of the [MR's regression fixture](https://gitcode.com/hocky/AscendNPU-IR/blob/246a97177c4c0f7e8a85c499f0e7eeaada574986/bishengir/test/bishengir-compile/triton/device-debug/mixed-layout-print.mlir).

<details>
<summary>Complete MLIR reproducer</summary>

```mlir
module {
  func.func private @triton_print(tensor<2x2x32x32xbf16>) attributes {hex = false, prefix = " x: "}
  func.func private @triton_print_0(tensor<2x2x32x32xbf16>) attributes {hex = false, prefix = " y: "}
  func.func private @triton_print_1(tensor<2x2x32x32xf32>) attributes {hex = false, prefix = " z: "}
  func.func @kernel(%arg0: memref<?xi8>, %arg1: memref<?xi8>, %arg2: memref<?xbf16> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xbf16> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xf32> {tt.tensor_kind = 1 : i32}, %arg5: i32, %arg6: i32, %arg7: i32, %arg8: i32, %arg9: i32, %arg10: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, global_kernel = "local", mix_mode = "mix", parallel_mode = "simd"} {
    %cst = arith.constant dense<4096> : tensor<1xi64>
    %cst_0 = arith.constant dense<[4, 32, 32]> : tensor<3xi64>
    %cst_1 = arith.constant dense<[2, 2, 32, 32]> : tensor<4xi64>
    %cst_2 = arith.constant 0.000000e+00 : f32
    %0 = tensor.empty() : tensor<4x32x32xf32>
    %1 = linalg.fill ins(%cst_2 : f32) outs(%0 : tensor<4x32x32xf32>) -> tensor<4x32x32xf32>
    %reinterpret_cast = memref.reinterpret_cast %arg2 to offset: [0], sizes: [4096], strides: [1] : memref<?xbf16> to memref<4096xbf16, strided<[1]>>
    %alloc = memref.alloc() : memref<4096xbf16>
    memref.copy %reinterpret_cast, %alloc : memref<4096xbf16, strided<[1]>> to memref<4096xbf16>
    %2 = bufferization.to_tensor %alloc restrict writable : memref<4096xbf16>
    %reshape = tensor.reshape %2(%cst_1) : (tensor<4096xbf16>, tensor<4xi64>) -> tensor<2x2x32x32xbf16>
    %reinterpret_cast_3 = memref.reinterpret_cast %arg3 to offset: [0], sizes: [4096], strides: [1] : memref<?xbf16> to memref<4096xbf16, strided<[1]>>
    %alloc_4 = memref.alloc() : memref<4096xbf16>
    memref.copy %reinterpret_cast_3, %alloc_4 : memref<4096xbf16, strided<[1]>> to memref<4096xbf16>
    %3 = bufferization.to_tensor %alloc_4 restrict writable : memref<4096xbf16>
    %reshape_5 = tensor.reshape %3(%cst_1) : (tensor<4096xbf16>, tensor<4xi64>) -> tensor<2x2x32x32xbf16>
    %reshape_6 = tensor.reshape %2(%cst_0) : (tensor<4096xbf16>, tensor<3xi64>) -> tensor<4x32x32xbf16>
    %reshape_7 = tensor.reshape %3(%cst_0) : (tensor<4096xbf16>, tensor<3xi64>) -> tensor<4x32x32xbf16>
    %4 = linalg.batch_matmul {input_precision = "ieee"} ins(%reshape_6, %reshape_7 : tensor<4x32x32xbf16>, tensor<4x32x32xbf16>) outs(%1 : tensor<4x32x32xf32>) -> tensor<4x32x32xf32>
    %reshape_8 = tensor.reshape %4(%cst_1) : (tensor<4x32x32xf32>, tensor<4xi64>) -> tensor<2x2x32x32xf32>
    call @triton_print(%reshape) : (tensor<2x2x32x32xbf16>) -> ()
    call @triton_print_0(%reshape_5) : (tensor<2x2x32x32xbf16>) -> ()
    call @triton_print_1(%reshape_8) : (tensor<2x2x32x32xf32>) -> ()
    %reinterpret_cast_9 = memref.reinterpret_cast %arg4 to offset: [0], sizes: [4096], strides: [1] : memref<?xf32> to memref<4096xf32, strided<[1]>>
    %reshape_10 = tensor.reshape %4(%cst) : (tensor<4x32x32xf32>, tensor<1xi64>) -> tensor<4096xf32>
    bufferization.materialize_in_destination %reshape_10 in writable %reinterpret_cast_9 : (tensor<4096xf32>, memref<4096xf32, strided<[1]>>) -> ()
    return
  }
}
```

</details>

Run:

```bash
bishengir-compile batch.mlir \
  --target=Ascend950PR_9579 \
  --enable-hfusion-compile=true \
  --enable-triton-kernel-compile=true \
  --enable-tuning-mode=true \
  --only-run-hivm-pipeline=true \
  --enable-layout-optimization=false \
  -o batch.out.mlir
```

**Observed result**

Compilation aborts with SIGABRT in `InsertL12UBForDebug.cpp:135`:

```text
Assertion `shape.size() == 2 || shape.size() == 3' failed.
```

<details>
<summary>Full captured compiler traceback (local paths normalized)</summary>

```text
[INFO] Using merged native A5 regbase pipeline
warning: warning: --enable-preload=true overrides --enablecv-pipeline-mode; forcing 'Skew'.
bishengir-compile: bishengir/lib/Dialect/HIVM/Transforms/InsertL12UBForDebug.cpp:135: virtual llvm::LogicalResult (anonymous namespace)::InsertL12UBForDebugOpPattern::matchAndRewrite(hivm::DebugOp, mlir::PatternRewriter &) const: Assertion `shape.size() == 2 || shape.size() == 3' failed.
PLEASE submit a bug report to https://github.com/llvm/llvm-project/issues/ and include the crash backtrace.
Stack dump:
0.	Program arguments: bishengir-compile batch.mlir --target=Ascend950PR_9579 --enable-hfusion-compile=true --enable-triton-kernel-compile=true --enable-tuning-mode=true --only-run-hivm-pipeline=true --enable-layout-optimization=false -o batch.out.mlir
 #0 0x000055a77feead67 llvm::sys::PrintStackTrace(llvm::raw_ostream&, int) (bishengir-compile+0x9879d67)
 #1 0x000055a77fee896e llvm::sys::RunSignalHandlers() (bishengir-compile+0x987796e)
 #2 0x000055a77feeb43a SignalHandler(int) Signals.cpp:0:0
 #3 0x00007f8c725f3fb0 __restore_rt (/lib64/libc.so.6+0x19fb0)
 #4 0x00007f8c7264ed0c __pthread_kill_implementation (/lib64/libc.so.6+0x74d0c)
 #5 0x00007f8c725f3e8e gsignal (/lib64/libc.so.6+0x19e8e)
 #6 0x00007f8c725db7b3 abort (/lib64/libc.so.6+0x17b3)
 #7 0x00007f8c725dc804 _IO_peekc_locked.cold (/lib64/libc.so.6+0x2804)
 #8 0x00007f8c725ebd45 __assert_fail (/lib64/libc.so.6+0x11d45)
 #9 0x000055a77bbd6882 (anonymous namespace)::InsertL12UBForDebugOpPattern::matchAndRewrite(mlir::hivm::DebugOp, mlir::PatternRewriter&) const InsertL12UBForDebug.cpp:0:0
#10 0x000055a77ed22f89 void llvm::function_ref<void ()>::callback_fn<mlir::PatternApplicator::matchAndRewrite(mlir::Operation*, mlir::PatternRewriter&, llvm::function_ref<bool (mlir::Pattern const&)>, llvm::function_ref<void (mlir::Pattern const&)>, llvm::function_ref<llvm::LogicalResult (mlir::Pattern const&)>)::$_2>(long) PatternApplicator.cpp:0:0
#11 0x000055a77fdf9058 mlir::MLIRContext::executeActionInternal(llvm::function_ref<void ()>, mlir::tracing::Action const&) (bishengir-compile+0x9788058)
#12 0x000055a77ed229c9 void mlir::MLIRContext::executeActionInternal<mlir::ApplyPatternAction, mlir::Pattern const&>(llvm::function_ref<void ()>, llvm::ArrayRef<mlir::IRUnit>, mlir::Pattern const&) PatternApplicator.cpp:0:0
#13 0x000055a77ed1f8ce mlir::PatternApplicator::matchAndRewrite(mlir::Operation*, mlir::PatternRewriter&, llvm::function_ref<bool (mlir::Pattern const&)>, llvm::function_ref<void (mlir::Pattern const&)>, llvm::function_ref<llvm::LogicalResult (mlir::Pattern const&)>) (bishengir-compile+0x86ae8ce)
#14 0x000055a77ecfdda6 (anonymous namespace)::GreedyPatternRewriteDriver::processWorklist() GreedyPatternRewriteDriver.cpp:0:0
#15 0x000055a77ecfcb43 void llvm::function_ref<void ()>::callback_fn<(anonymous namespace)::RegionPatternRewriteDriver::simplify(bool*) &&::$_8>(long) GreedyPatternRewriteDriver.cpp:0:0
#16 0x000055a77fdf9058 mlir::MLIRContext::executeActionInternal(llvm::function_ref<void ()>, mlir::tracing::Action const&) (bishengir-compile+0x9788058)
#17 0x000055a77ecfca62 void mlir::MLIRContext::executeActionInternal<(anonymous namespace)::GreedyPatternRewriteIteration, long&>(llvm::function_ref<void ()>, llvm::ArrayRef<mlir::IRUnit>, long&) GreedyPatternRewriteDriver.cpp:0:0
#18 0x000055a77ecfa745 mlir::applyPatternsGreedily(mlir::Region&, mlir::FrozenRewritePatternSet const&, mlir::GreedyRewriteConfig, bool*) (bishengir-compile+0x8689745)
#19 0x000055a77bbd5c98 (anonymous namespace)::InsertL12UBForDebug::runOnOperation() InsertL12UBForDebug.cpp:0:0
#20 0x000055a77ee15249 void llvm::function_ref<void ()>::callback_fn<mlir::detail::OpToOpPassAdaptor::run(mlir::Pass*, mlir::Operation*, mlir::AnalysisManager, bool, unsigned int)::$_7>(long) Pass.cpp:0:0
#21 0x000055a77903ddea bishengir::BiShengIRPassManager::initializeActionHandler(mlir::MLIRContext*)::$_0::operator()(llvm::function_ref<void ()>, mlir::tracing::Action const&) const::'lambda'()::operator()() const PassManager.cpp:0:0
#22 0x000055a77903d7dc std::_Function_handler<void (llvm::function_ref<void ()>, mlir::tracing::Action const&), bishengir::BiShengIRPassManager::initializeActionHandler(mlir::MLIRContext*)::$_0>::_M_invoke(std::_Any_data const&, llvm::function_ref<void ()>&&, mlir::tracing::Action const&) PassManager.cpp:0:0
#23 0x000055a77fdf9058 mlir::MLIRContext::executeActionInternal(llvm::function_ref<void ()>, mlir::tracing::Action const&) (bishengir-compile+0x9788058)
#24 0x000055a77ee151fb void mlir::MLIRContext::executeActionInternal<mlir::PassExecutionAction, mlir::Pass&>(llvm::function_ref<void ()>, llvm::ArrayRef<mlir::IRUnit>, mlir::Pass&) Pass.cpp:0:0
#25 0x000055a77ee108cd mlir::detail::OpToOpPassAdaptor::run(mlir::Pass*, mlir::Operation*, mlir::AnalysisManager, bool, unsigned int) (bishengir-compile+0x879f8cd)
#26 0x000055a77ee10b71 mlir::detail::OpToOpPassAdaptor::runPipeline(mlir::OpPassManager&, mlir::Operation*, mlir::AnalysisManager, bool, unsigned int, mlir::PassInstrumentor*, mlir::PassInstrumentation::PipelineParentInfo const*) (bishengir-compile+0x879fb71)
#27 0x000055a77ee130c2 mlir::PassManager::run(mlir::Operation*) (bishengir-compile+0x87a20c2)
#28 0x000055a7790ab35f bishengir::RetriablePassManager::runOnce(mlir::ModuleOp, std::function<void (mlir::PassManager&)> const&, llvm::StringRef) (bishengir-compile+0x2a3a35f)
#29 0x000055a7790b1ef7 bishengir::runPipeline(mlir::ModuleOp, std::function<void (mlir::PassManager&)> const&, bishengir::BiShengIRCompileMainConfig&, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char>> const&) (bishengir-compile+0x2a40ef7)
#30 0x000055a779097df9 (anonymous namespace)::runModulePipeline(mlir::ModuleOp, std::function<void (mlir::PassManager&, bishengir::BiShengIRCompileMainConfig const&)> const&, bishengir::BiShengIRCompileMainConfig&, llvm::StringRef) BiShengIRCompileMain.cpp:0:0
#31 0x000055a7790954a4 bishengir::regbase::runRegBasePipeline(mlir::ModuleOp, bishengir::BiShengIRCompileMainConfig, bishengir::BishengAsyncRuntime*) (bishengir-compile+0x2a244a4)
#32 0x000055a7790a23bc bishengir::regbase::runRegBaseCompile(mlir::ModuleOp, bishengir::BiShengIRCompileMainConfig, llvm::ArrayRef<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char>>>, bishengir::BishengAsyncRuntime*) (bishengir-compile+0x2a313bc)
#33 0x000055a778f39d5f main (bishengir-compile+0x28c8d5f)
#34 0x00007f8c725dd681 __libc_start_call_main (/lib64/libc.so.6+0x3681)
#35 0x00007f8c725dd798 __libc_start_main@GLIBC_2.2.5 (/lib64/libc.so.6+0x3798)
#36 0x000055a778f387e5 _start (bishengir-compile+0x28c77e5)
```

</details>

**Expected result and fix direction**

Compilation should succeed, with device printing observing the logical tensor values while the matmul retains its required Cube representation. Give unassigned tensor prints a Vector/UB requirement and keep print-only load views separate from Cube views. Any extra snapshot copy must stay at the original transfer point so intervening GM writes cannot change the printed values.

**Validation**

The same print reproducer fails on the baseline and compiles with !4950 (`1813edca0a`). After rebasing the MR to `18fd6805ee`, head `246a97177c` builds successfully and passes 66 focused lit tests plus five scalar/Vector/Cube print controls; three tests are unsupported in that build. NPU execution and numerical print-output validation have not been performed.

This issue tracks the print-enabled shared-load failure. The supplied `test_core.py::test_dot_multidim` without device-print calls compiled successfully before and after the fix in all 20 parameter combinations on each of A3 and A5, so its separately reported LLVM error is not identified by this reproduction.