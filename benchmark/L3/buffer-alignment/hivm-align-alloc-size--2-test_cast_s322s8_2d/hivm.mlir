module {
  func.func @test_cast_s322s8_2d() {
    %alloc = memref.alloc() : memref<2x16xi32, #hivm.address_space<ub>>
    %alloc_0 = memref.alloc() : memref<2x16xi8, #hivm.address_space<ub>>
    hivm.hir.vcast ins(%alloc : memref<2x16xi32, #hivm.address_space<ub>>) outs(%alloc_0 : memref<2x16xi8, #hivm.address_space<ub>>) round_mode = <truncwithoverflow>
    return
  }
}

