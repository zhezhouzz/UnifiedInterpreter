module {
  func.func @test_cast_s322s8_1d_extra() attributes {hivm.disable_size_align_for_cast} {
    %alloc = memref.alloc() : memref<2xi32, #hivm.address_space<ub>>
    %alloc_0 = memref.alloc() : memref<2xi8, #hivm.address_space<ub>>
    hivm.hir.vcast ins(%alloc : memref<2xi32, #hivm.address_space<ub>>) outs(%alloc_0 : memref<2xi8, #hivm.address_space<ub>>) round_mode = <truncwithoverflow>
    return
  }
}

