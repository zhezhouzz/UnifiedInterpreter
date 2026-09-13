(* Sourced examples and test-case metadata. No interpreter logic lives here. *)

open Language

type source_kind = TritonAscend | MlirToy

type source = {
  kind : source_kind;
  title : string;
  url : string;
  note : string;
}

type case = {
  id : string;
  title : string;
  source : source;
  command : top_command;
  inputs : (string * Tensor.t) list;
  output : string;
  route_expectations : (string * string) list;
}

  let triton_source title url note = { kind = TritonAscend; title; url; note }

  let cases () =
    [
      {
        id = "vector-add";
        title = "Vector Add";
        source =
          triton_source "Triton-Ascend Vector Addition"
            "https://triton-ascend.readthedocs.io/zh-cn/latest/examples/01_vector_add_example.html"
            "Uses program_id, arange offsets, masked tl.load, and masked tl.store.";
        command = Vector_add { x = "x"; y = "y"; out = "out"; n = 10; block = 4 };
        inputs =
          [
            ("x", Tensor.of_array1 [| 0.; 1.; 2.; 3.; 4.; 5.; 6.; 7.; 8.; 9. |]);
            ("y", Tensor.of_array1 [| 9.; 8.; 7.; 6.; 5.; 4.; 3.; 2.; 1.; 0. |]);
          ];
        output = "out";
        route_expectations =
          [
            ("triton", "Native source route; CPU interpreter if Triton is installed.");
            ("mlir", "Equivalent tensor/memref subset can be checked, but not Triton SPMD syntax.");
            ("xdsl", "Equivalent arith/memref loop subset can be interpreted if xDSL is installed.");
            ("emitc", "Scalarized C route is possible for this subset.");
          ];
      };
      {
        id = "fused-softmax";
        title = "Fused Softmax";
        source =
          triton_source "Triton-Ascend Fused Softmax"
            "https://triton-ascend.readthedocs.io/zh-cn/latest/examples/02_fused_softmax_example.html"
            "Uses one program per row, power-of-two block padding, max/exp/sum reductions.";
        command = Fused_softmax { x = "x"; out = "out"; rows = 3; cols = 5; block = 8 };
        inputs =
          [
            ( "x",
              Tensor.of_array2
                [|
                  [| 1.; 2.; 3.; 4.; 5. |];
                  [| 1.; 1.; 2.; 3.; 5. |];
                  [| -2.; -1.; 0.; 1.; 2. |];
                |] );
          ];
        output = "out";
        route_expectations =
          [
            ("triton", "Native route; exp/reduction supported except backend-specific gaps.");
            ("mlir", "Equivalent math/arith/memref route is possible, not Triton padding syntax.");
            ("xdsl", "Depends on math.exp and vector/reduction support.");
            ("emitc", "Scalarized C route is possible.");
          ];
      };
      {
        id = "layer-norm";
        title = "LayerNorm";
        source =
          triton_source "Triton-Ascend Layer Normalization"
            "https://triton-ascend.readthedocs.io/zh-cn/latest/examples/03_layer_norm_example.html"
            "Uses mean/variance reductions, sqrt, affine scale/bias, and dtype-sensitive tests.";
        command =
          Layer_norm
            {
              x = "x";
              weight = "weight";
              bias = "bias";
              out = "out";
              rows = 2;
              cols = 4;
              eps = 1e-5;
              dtype = BF16ish;
            };
        inputs =
          [
            ("x", Tensor.of_array2 [| [| 1.; 2.; 3.; 4. |]; [| 2.; 4.; 6.; 8. |] |]);
            ("weight", Tensor.of_array1 [| 1.; 1.5; 0.5; 2. |]);
            ("bias", Tensor.of_array1 [| 0.; 0.1; -0.2; 0.3 |]);
          ];
        output = "out";
        route_expectations =
          [
            ("triton", "Native route, but Triton interpreter documents bfloat16 limitations.");
            ("mlir", "Equivalent math/arith/memref route is possible after scalarization.");
            ("xdsl", "Depends on math.sqrt and reduction support.");
            ("emitc", "Scalarized C route is possible.");
          ];
      };
      {
        id = "matmul-bias";
        title = "MatMul + Bias";
        source =
          triton_source "Triton-Ascend Matrix Multiplication"
            "https://triton-ascend.readthedocs.io/zh-cn/latest/examples/05_matrix_multiplication_example.html"
            "Computes output = x @ y + z using tl.dot and tiled/broadcasted indices.";
        command =
          Matmul_bias
            {
              a = "a";
              b = "b";
              z = "z";
              out = "out";
              m = 4;
              n = 4;
              k = 4;
              block_m = 2;
              block_n = 2;
            };
        inputs =
          [
            ( "a",
              Tensor.of_array2
                [|
                  [| 1.; 2.; 3.; 4. |];
                  [| 2.; 1.; 0.; 1. |];
                  [| 0.; 1.; 2.; 3. |];
                  [| 3.; 1.; 1.; 0. |];
                |] );
            ( "b",
              Tensor.of_array2
                [|
                  [| 1.; 0.; 2.; 1. |];
                  [| 0.; 1.; 1.; 0. |];
                  [| 2.; 1.; 0.; 1. |];
                  [| 1.; 2.; 1.; 0. |];
                |] );
            ("z", Tensor.of_array1 [| 0.5; -1.; 1.5; 0. |]);
          ];
        output = "out";
        route_expectations =
          [
            ("triton", "Native tl.dot route if Triton/Triton-Ascend is installed.");
            ("mlir", "Scalar/vector lowerable subset can run on CPU.");
            ("xdsl", "Equivalent linalg/memref/vector shape is a natural xDSL target.");
            ("emitc", "Scalarized C route is possible.");
          ];
      };
      {
        id = "toy-transpose-mul";
        title = "Toy Transpose + Mul";
        source =
          {
            kind = MlirToy;
            title = "MLIR Toy Tutorial Chapter 5";
            url = "https://mlir.llvm.org/docs/Tutorials/Toy/Ch-5/";
            note =
              "Shows partial lowering of toy.transpose and toy.mul into affine/arith/func/memref.";
          };
        command =
          Toy_transpose_mul { a = "a"; b = "b"; out = "out"; rows = 2; cols = 3 };
        inputs =
          [
            ("a", Tensor.of_array2 [| [| 1.; 2.; 3. |]; [| 4.; 5.; 6. |] |]);
            ("b", Tensor.of_array2 [| [| 6.; 5.; 4. |]; [| 3.; 2.; 1. |] |]);
          ];
        output = "out";
        route_expectations =
          [
            ("triton", "Not a Triton source; only equivalent tensor code would apply.");
            ("mlir", "Native conceptual route for partial lowering.");
            ("xdsl", "Equivalent affine/memref subset is feasible.");
            ("emitc", "EmitC route is feasible after lowering.");
          ];
      };
    ]
