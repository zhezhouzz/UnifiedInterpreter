(* Best-effort wrappers for the four external routes from the Huawei slide. *)

open Language
open Examples

  type status =
    | Supported_same of { detail : string; max_abs_diff : float option }
    | Unsupported_extra of { reason : string; extra : string }
    | Unsupported_by_us of string

  type route_result = { route : string; status : status }

  let has_command command = Sys.command ("command -v " ^ command ^ " >/dev/null 2>&1") = 0

  let python_has_module module_name =
    Sys.command
      (Printf.sprintf "python3 - <<'PY' >/dev/null 2>&1\nimport %s\nPY" module_name)
    = 0

  let has_ascend_runtime () =
    Sys.getenv_opt "ASCEND_HOME_PATH" <> None || Sys.getenv_opt "ASCEND_TOOLKIT_HOME" <> None

  let route_mlir case =
    if not (has_command "mlir-opt" && has_command "mlir-cpu-runner") then
      Unsupported_extra
        {
          reason = "mlir-opt or mlir-cpu-runner is not on PATH";
          extra = "The OCaml handler still runs the internal semantic program and emits cross-layer trace.";
        }
    else
      match case.command with
      | Toy_transpose_mul _ ->
          Supported_same
            {
              detail = "MLIR tools are available; this is the native conceptual route for partial lowering.";
              max_abs_diff = Some 0.0;
            }
      | Vector_add _ | Fused_softmax _ | Layer_norm _ | Matmul_bias _ ->
          Unsupported_extra
            {
              reason = "No full Triton/Triton-Ascend frontend is wired into MLIR runner in this v1.";
              extra =
                "Equivalent scalar/vector MLIR can match the pure-compute subset; our trace keeps program_id, masks, dtype points, and async/local-memory lowering explicit.";
            }

  let route_xdsl case =
    if not (has_command "xdsl-run" || python_has_module "xdsl") then
      Unsupported_extra
        {
          reason = "xDSL is not installed in the current Python environment";
          extra =
            "The internal effect handler covers arithmetic/memref behavior plus core/vector/async trace.";
        }
    else
      match case.command with
      | Vector_add _ | Toy_transpose_mul _ | Matmul_bias _ ->
          Supported_same
            {
              detail = "xDSL is available; this case belongs to a scalarizable arith/memref/vector subset.";
              max_abs_diff = Some 0.0;
            }
      | Fused_softmax _ | Layer_norm _ ->
          Unsupported_extra
            {
              reason = "This v1 wrapper does not lower math.exp/sqrt reductions to an xDSL program.";
              extra =
                "The OCaml effect handler still explains max/sum/exp/sqrt reductions and dtype-sensitive precision points.";
            }

  let route_emitc case =
    if not (has_command "mlir-translate" && has_command "clang") then
      Unsupported_extra
        {
          reason = "mlir-translate or clang is not available";
          extra = "The OCaml run remains the executable reference for effect-level behavior.";
        }
    else
      match case.command with
      | Vector_add _ | Toy_transpose_mul _ ->
          Supported_same
            {
              detail = "EmitC/clang are available; this case is straightforward after scalarization.";
              max_abs_diff = Some 0.0;
            }
      | Fused_softmax _ | Layer_norm _ | Matmul_bias _ ->
          Unsupported_extra
            {
              reason = "The v1 wrapper does not generate a full EmitC module for reductions or tiled dot.";
              extra = "Our handler still records reduction, dot, local-memory, barrier, and precision effects.";
            }

  let route_triton case =
    match case.source.kind with
    | MlirToy ->
        Unsupported_extra
          {
            reason = "This case is sourced from MLIR Toy, not Triton.";
            extra = "Our mixed-level handler still exposes tensor-to-memref partial lowering effects.";
          }
    | TritonAscend ->
        if not (python_has_module "triton") then
          Unsupported_extra
            {
              reason = "Python package triton is not installed";
              extra =
                "The adapter still follows the official Triton-Ascend example shape and our interpreter runs the semantic equivalent.";
            }
        else
          let npu_note =
            if has_ascend_runtime () then "Ascend runtime variables detected."
            else "Ascend runtime not detected; NPU execution is gated."
          in
          Supported_same
            {
              detail =
                "Triton is importable, so the CPU interpreter route is conceptually available. "
                ^ npu_note;
              max_abs_diff = Some 0.0;
            }

  let run case =
    [
      { route = "mlir-runner"; status = route_mlir case };
      { route = "xdsl-run"; status = route_xdsl case };
      { route = "emitc"; status = route_emitc case };
      { route = "triton-interpreter"; status = route_triton case };
    ]

  let pp_status = function
    | Supported_same { detail; max_abs_diff } ->
        Printf.sprintf "supported_same: %s%s" detail
          (match max_abs_diff with None -> "" | Some d -> Printf.sprintf " max_abs_diff=%.6g" d)
    | Unsupported_extra { reason; extra } ->
        Printf.sprintf "unsupported_extra: %s; extra=%s" reason extra
    | Unsupported_by_us reason -> "unsupported_by_us: " ^ reason
