func.func @test_cast_s162s8_2d_extra() attributes {hivm.disable_size_align_for_cast} {
  %s16 = memref.alloc() : memref<2x16xi16, #hivm.address_space<ub>>
  %s8 = memref.alloc() : memref<2x16xi8, #hivm.address_space<ub>>
  hivm.hir.vcast ins(%s16 : memref<2x16xi16, #hivm.address_space<ub>>)
                 outs(%s8 : memref<2x16xi8, #hivm.address_space<ub>>)
                 round_mode = #hivm.round_mode<truncwithoverflow>
  return
}
