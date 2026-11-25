func.func @test_cast_s322s8_1d() {
  %s32 = memref.alloc() : memref<2xi32, #hivm.address_space<ub>>
  %s8 = memref.alloc() : memref<2xi8, #hivm.address_space<ub>>
  hivm.hir.vcast ins(%s32 : memref<2xi32, #hivm.address_space<ub>>)
                outs(%s8 : memref<2xi8, #hivm.address_space<ub>>)
                round_mode = #hivm.round_mode<truncwithoverflow>
  return
}
