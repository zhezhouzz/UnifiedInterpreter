scf.for %iv = %lb to %ub step %step {
  %local = memref.alloc()
      : memref<1024xf16, #hivm.address_space<ub>>

  hivm.hir.load
      ins(%input : memref<1024xf16, #hivm.address_space<gm>>)
      outs(%local : memref<1024xf16, #hivm.address_space<ub>>)

  %result = hivm.hir.vexp
      ins(%local : memref<1024xf16, #hivm.address_space<ub>>)
      outs(%output : memref<1024xf16, #hivm.address_space<ub>>)
}
