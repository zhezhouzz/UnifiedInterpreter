module attributes {hacc.target = #hacc.target<"Ascend950PR_950z">} {
  func.func @vf_a(%arg0: memref<64xf32, #hivm.address_space<ub>>, %arg1: memref<64xf32, #hivm.address_space<ub>>) attributes {hivm.vector_function, no_inline} {
    %c0 = arith.constant 0 : index
    %cst = arith.constant 0.000000e+00 : f32
    %0 = vector.transfer_read %arg0[%c0], %cst {in_bounds = [true]} : memref<64xf32, #hivm.address_space<ub>>, vector<64xf32>
    vector.transfer_write %0, %arg1[%c0] {in_bounds = [true]} : vector<64xf32>, memref<64xf32, #hivm.address_space<ub>>
    return
  }

  func.func @test_tightly_coupled_buffer_in_AIC(%arg0: memref<64xf32, #hivm.address_space<gm>>,
                              %arg1: memref<16x16xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc_2 = memref.alloc() {alignment = 64 : i64} : memref<64xf32, #hivm.address_space<cbuf>>
    annotation.mark %alloc_2 {hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<2>} : memref<64xf32, #hivm.address_space<cbuf>>
    hivm.hir.load ins(%arg0 : memref<64xf32, #hivm.address_space<gm>>) outs(%alloc_2 : memref<64xf32, #hivm.address_space<cbuf>>)
    hivm.hir.debug {debugtype = "print", hex = false, prefix = " %alloc_2: ", tcoretype = #hivm.tcore_type<CUBE_OR_VECTOR>} %alloc_2 : memref<64xf32, #hivm.address_space<cbuf>>
    return
  }

  func.func @test_tightly_coupled_buffer_in_AIV(%arg0: memref<64xf32, #hivm.address_space<gm>>,
                              %arg1: memref<16x16xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>}  {
    %c64 = arith.constant 64 : index
    %c0 = arith.constant 0 : index
    scf.for %arg2 = %c0 to %c64 step %c64 {
      %alloc = memref.alloc() {alignment = 64 : i64} : memref<64xf32, #hivm.address_space<ub>>
      hivm.hir.load ins(%arg0 : memref<64xf32, #hivm.address_space<gm>>) outs(%alloc : memref<64xf32, #hivm.address_space<ub>>)
      %alloc_1 = memref.alloc() {alignment = 64 : i64} : memref<64xf32, #hivm.address_space<ub>>
      func.call @vf_a(%alloc, %alloc_1) {hivm.vector_function, no_inline} : (memref<64xf32, #hivm.address_space<ub>>, memref<64xf32, #hivm.address_space<ub>>) -> ()
      %alloc_2 = memref.alloc() {alignment = 64 : i64} : memref<64xf32, #hivm.address_space<cbuf>>
      annotation.mark %alloc_2 {hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<2>} : memref<64xf32, #hivm.address_space<cbuf>>
      hivm.hir.copy ins(%alloc_1 : memref<64xf32, #hivm.address_space<ub>>) outs(%alloc_2 : memref<64xf32, #hivm.address_space<cbuf>>) {ub_to_l1}
    }
    return
  }
}
