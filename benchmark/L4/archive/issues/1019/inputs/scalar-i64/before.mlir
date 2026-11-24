module {
  func.func @choose_i64(%arg0: i1, %arg1: i64, %arg2: i64) -> i64 attributes {hivm.vector_function} {
    %0 = arith.select %arg0, %arg1, %arg2 : i64
    return %0 : i64
  }
  func.func @choose_i32(%arg0: i1, %arg1: i32, %arg2: i32) -> i32 attributes {hivm.vector_function} {
    %0 = arith.select %arg0, %arg1, %arg2 : i32
    return %0 : i32
  }
  func.func @choose_si64(%arg0: i1, %arg1: si64, %arg2: si64) -> si64 attributes {hivm.vector_function} {
    %0 = arith.select %arg0, %arg1, %arg2 : si64
    return %0 : si64
  }
  func.func @scalar_caller(%arg0: i1, %arg1: i64, %arg2: i64) -> i64 {
    %0 = arith.select %arg0, %arg1, %arg2 : i64
    return %0 : i64
  }
}

