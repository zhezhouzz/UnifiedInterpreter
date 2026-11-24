%w1 = scf.while (..., %acc = %init) ... do {
  %merged = scf.if %do_mmad {
    %next = hivm.hir.mmadL1 ins(...) outs(%acc)
    scf.yield %next
  } else {
    scf.yield %acc
  }
  scf.yield ..., %merged, ...
} attributes {normalized_in_L0C = [1]}

// 异常插入的中间搬运
%ub = hivm.hir.fixpipe ins(%w1#1) outs(...)
%w2 = scf.while (..., %acc = %ub) ... do {
  %next = hivm.hir.mmadL1 ins(...) outs(%acc)
  scf.yield ..., %next, ...
}
hivm.hir.fixpipe ins(%w2#1) outs(%output)
    dual_dst_mode = <ROW_SPLIT>
