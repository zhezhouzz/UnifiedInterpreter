module {
  func.func @test_cast_s162s8_2d_extra() attributes {hivm.disable_size_align_for_cast} {
    %alloc = memref.alloc() : memref<2x16xi16, #hivm.address_space<ub>>
    %alloc_0 = memref.alloc() : memref<2x16xi8, #hivm.address_space<ub>>
    hivm.hir.vcast ins(%alloc : memref<2x16xi16, #hivm.address_space<ub>>) outs(%alloc_0 : memref<2x16xi8, #hivm.address_space<ub>>) round_mode = <truncwithoverflow>
    return
  }
}

