// 异构组合（6 组白名单，累加器 f32）
hivm.mmad_l1 %a, %b, %c, ... :
  (A: f16|bf16 × B: int8|fp8_e4m3 | A/B: fp8_e4m3×fp8_e5m2 双向) -> C: f32

// packed s4（enable_I4，B 以 i8 载体承载，存储 K 折半）
hivm.mmad_l1 %a, %b_packed_i8, %c, ... { enable_I4 } :
  (A: f16|bf16 -> C: f32 | A: i8 -> C: i32)
