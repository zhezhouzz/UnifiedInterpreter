module {
  func.func @slices(%input: memref<8xf32>, %out: memref<2xf32>) {
    %one = arith.constant 1 : index
    %two = arith.constant 2 : index
    %three = arith.constant 3 : index
    %seven = arith.constant 7.0 : f32
    %zero = arith.constant 0.0 : f32
    %view = memref.subview %input[%one] [%three] [2] : memref<8xf32> to memref<?xf32, strided<[2], offset: ?>>
    %nested = memref.subview %view[%one] [%two] [1] : memref<?xf32, strided<[2], offset: ?>> to memref<?xf32, strided<[2], offset: ?>>
    %tensor = bufferization.to_tensor %nested restrict writable : memref<?xf32, strided<[2], offset: ?>>
    %slice = tensor.extract_slice %tensor[0] [%two] [1] : tensor<?xf32> to tensor<?xf32>
    %yes = arith.cmpi slt, %one, %two : index
    scf.if %yes {
      linalg.fill ins(%seven : f32) outs(%out : memref<2xf32>)
    } else {
      linalg.fill ins(%zero : f32) outs(%out : memref<2xf32>)
    }
    %no = arith.cmpi slt, %two, %one : index
    scf.if %no {
      linalg.fill ins(%zero : f32) outs(%out : memref<2xf32>)
    } else {
      bufferization.materialize_in_destination %slice in writable %out : (tensor<?xf32>, memref<2xf32>) -> ()
    }
    return
  }
}
