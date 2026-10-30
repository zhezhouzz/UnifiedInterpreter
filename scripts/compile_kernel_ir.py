import argparse
import ast
import hashlib
import json
import subprocess
import sys
from importlib.metadata import version
from pathlib import Path

import ascendnpuir
import triton
import triton.language as tl
from triton._C.libtriton import ir
from triton.backends.ascend.compiler import AscendBackend, make_ttir, ttir_to_linalg
from triton.backends.compiler import GPUTarget
from triton.compiler import ASTSource


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "examples/kernels/source"))
from kernels import add_kernel, row_sum, vector_add


def attention_kernel():
    path = ROOT / "artifacts/flash_attention/source/06-fused-attention.py"
    module = ast.parse(path.read_text(), filename=str(path))
    names = {"_attn_fwd_inner", "_attn_fwd"}
    functions = [node for node in module.body
                 if isinstance(node, ast.FunctionDef) and node.name in names]
    if {node.name for node in functions} != names:
        raise ValueError("attention source functions are missing")
    namespace = {"triton": triton, "tl": tl, "__name__": __name__}
    exec(compile(ast.Module(body=functions, type_ignores=[]), str(path), "exec"), namespace)
    return namespace["_attn_fwd"]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/kernels")
    parser.add_argument("--verify-examples", action="store_true")
    parser.add_argument("--kernel", choices=["vector_add", "row_sum", "add_kernel", "_attn_fwd"])
    parser.add_argument("--constants", type=json.loads)
    parser.add_argument("--signature", type=json.loads)
    parser.add_argument("--target", choices=["Ascend910B1"], default="Ascend910B1")
    parser.add_argument("--num-warps", type=int, choices=[4], default=4)
    args = parser.parse_args()
    if (args.constants is not None or args.signature is not None) and args.kernel is None:
        parser.error("--constants and --signature require --kernel")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    versions = {name: version(name) for name in ("triton-ascend", "ascendnpu-ir")}
    if versions != {"triton-ascend": "3.2.0", "ascendnpu-ir": "1.2.0"}:
        raise ValueError(f"unexpected compiler versions: {versions}")
    adapter = Path(triton.__file__).parent / "backends/ascend/triton-adapter-opt"
    optimizer = Path(ascendnpuir.__file__).parent / "bin/bishengir-opt"
    if args.verify_examples:
        for artifact in sorted((ROOT / "examples/kernels").glob("*.mlir")):
            subprocess.run([str(optimizer), str(artifact), "-o", "/dev/null"], check=True)
        return
    backend = AscendBackend(GPUTarget("npu", args.target, 0))
    options = backend.parse_options({"num_warps": args.num_warps})
    provenance = {
        "packages": versions,
        "target": "Ascend910B1",
        "num_warps": 4,
        "source": "examples/kernels/source/kernels.py",
        "source_sha256": sha256(ROOT / "examples/kernels/source/kernels.py"),
        "generator_sha256": sha256(Path(__file__).resolve()),
        "tools": {path.name: sha256(path) for path in (adapter, optimizer)},
        "adapter_options": {
            "named_ops": True, "enable_nd2nz_on_vector": False,
            "enable_select_analysis": False, "compile_on_910_95": False,
            "force_simt_template": False,
        },
        "hfusion_passes": ["convert-arith-to-hfusion"],
        "hivm_passes": ["convert-hfusion-to-hivm"],
        "kernels": {},
    }
    for kernel, signature, constants in [
        (vector_add, {"a": "*fp32", "b": "*fp32", "out": "*fp32"}, {"BLOCK": 4}),
        (row_sum, {"input": "*fp32", "out": "*fp32"}, {"ROWS": 3, "COLS": 4}),
        (add_kernel, {"X": "*fp32", "Y": "*fp32", "Z": "*fp32", "n_elements": "i32"},
         {"BLOCK_SIZE": 256}),
        (attention_kernel(),
         {"Q": "*fp16", "K": "*fp16", "V": "*fp16", "M": "*fp32",
          "Out": "*fp16", "acc": "*fp32", "sm_scale": "fp32"},
         {"stride_qz": 16384, "stride_qh": 16384, "stride_qm": 128, "stride_qk": 1,
          "stride_kz": 16384, "stride_kh": 16384, "stride_kn": 128, "stride_kk": 1,
          "stride_vz": 16384, "stride_vh": 16384, "stride_vn": 128, "stride_vk": 1,
          "stride_oz": 16384, "stride_oh": 16384, "stride_om": 128, "stride_on": 1,
          "Z": 1, "H": 1, "N_CTX": 128, "HEAD_DIM": 128,
          "BLOCK_M": 32, "BLOCK_N": 128, "STAGE": 1}),
    ]:
        name = kernel.__name__
        if args.kernel is not None and name != args.kernel:
            continue
        if args.constants is not None and args.constants != constants:
            parser.error(f"unsupported constants for {name}: expected {constants}")
        if args.signature is not None and list(args.signature.items()) != list(signature.items()):
            parser.error(f"unsupported signature or argument order for {name}: expected {signature}")
        hfusion_passes = ["convert-arith-to-hfusion"]
        hivm_passes = ["convert-hfusion-to-hivm"]
        if name == "_attn_fwd":
            hfusion_passes += ["convert-math-to-hfusion", "convert-linalg-to-hfusion"]
            hivm_passes = ["canonicalize-ext", "convert-hfusion-to-hivm=mm-map-mode=macro_instr"]
        context = ir.context()
        ir.load_dialects(context)
        source = ASTSource(kernel, signature, constants=constants)
        module = source.make_ir(options, backend.get_codegen_implementation(),
                                backend.get_module_map(), context)
        metadata = dict(provenance["adapter_options"])
        metadata.pop("named_ops")
        module = make_ttir(module, metadata, options)
        temporary = ROOT / "_build/kernel-generation"
        temporary.mkdir(parents=True, exist_ok=True)
        ttir_input = temporary / (name + ".ttir.mlir")
        ttir_input.write_text(str(module))
        ttir = output / (name + ".ttir.mlir")
        subprocess.run([str(adapter), str(ttir_input), "-o", str(ttir)], check=True)
        adapter_output = temporary / (name + ".adapter.mlir")
        adapter_output.write_text(ttir_to_linalg(module, metadata, options, named_ops=True))
        hfusion = output / (name + ".hfusion.mlir")
        hivm = output / (name + ".hivm.mlir")
        subprocess.run([str(optimizer), str(adapter_output), *["--" + p for p in hfusion_passes],
                        "-o", str(hfusion)], check=True)
        subprocess.run([str(optimizer), str(hfusion), *["--" + p for p in hivm_passes],
                        "-o", str(hivm)], check=True)
        for artifact in (hfusion, hivm):
            subprocess.run([str(optimizer), str(artifact), "-o", "/dev/null"], check=True)
        provenance["kernels"][name] = {
            "source": str(Path(kernel.fn.__code__.co_filename).resolve().relative_to(ROOT)),
            "source_sha256": sha256(Path(kernel.fn.__code__.co_filename)),
            "signature": signature, "constants": constants,
            "hfusion_passes": hfusion_passes,
            "hivm_passes": hivm_passes,
            "artifacts": {path.name: sha256(path) for path in (ttir, hfusion, hivm)},
        }
    (output / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")


if __name__ == "__main__":
    main()
