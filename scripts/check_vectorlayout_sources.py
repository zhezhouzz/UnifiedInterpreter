import argparse
import json
import subprocess
from pathlib import Path


OPERATIONS = {
    "affine": "apply",
    "annotation": "mark",
    "arith": "addi andi bitcast cmpf cmpi constant divsi extsi extui index_cast maximumf "
             "maxsi minsi mulf muli ori remsi remui select shrsi subi trunci",
    "ave.hir": "broadcast masked_store pge plt preg.and preg.xor scalar_broadcast vcmp "
               "vector.layout_cast vector_broadcast vextsi vintlv vload vor vsel vxor",
    "builtin": "module unrealized_conversion_cast",
    "func": "call func return",
    "hivm.hir": "copy debug fixpipe get_block_idx get_sub_block_idx indirect_load indirect_store "
                "mmadL1 multi_buffer_counter nd2nz pipe_barrier pointer_cast set_ctrl set_flag "
                "sync_block_set sync_block_wait vbrc wait_flag",
    "memref": "cast collapse_shape expand_shape extract_strided_metadata load reinterpret_cast store subview",
    "scf": "for if yield",
    "vector": "broadcast constant_mask multi_reduction shape_cast transfer_read transfer_write",
}
SUPPORTED = {f"{dialect}.{op}" for dialect, names in OPERATIONS.items() for op in names.split()}
PREFIX = "_prefill_bnsd_score_kernel_mix_"
FUSED = PREFIX + "aiv_fused_5_outlined_merged_vf_0"


def sections(path, expected):
    # 这里只识别编译日志的分段标记，MLIR 指令和符号引用由 bishengir-opt 解析。
    graph = {}
    layout = []
    header = None
    destination = None
    phase = None
    with path.open() as log:
        for number, line in enumerate(log, 1):
            if header is None and line.startswith("module attributes {dlti.target_system_spec"):
                header = line
            if line.startswith("[PassID]"):
                destination = None
                phase = None
            elif line.startswith("// -----// IR Dump"):
                destination = None
                phase = None
                if line.startswith("// -----// IR Dump After GraphSyncSolver "):
                    phase = "graph"
                elif line.startswith("// -----// IR Dump After AnalyzeVectorLayout "):
                    phase = "layout"
            elif phase is not None and line.strip():
                if phase == "graph":
                    function = next((f for f in expected if line.startswith(f"func.func @{f}(")), None)
                    if function is None or function in graph:
                        raise ValueError(f"{path}:{number}: unexpected function snapshot: {line[:120]}")
                    destination = graph[function] = []
                elif line.startswith(f"func.func @{FUSED}("):
                    if layout:
                        raise ValueError(f"{path}:{number}: duplicate layout snapshot for {FUSED}")
                    destination = layout
                phase = None
                if destination is not None:
                    destination.append((number, line))
            elif destination is not None:
                destination.append((number, line))
    if header is None or not layout or FUSED not in graph:
        raise ValueError(f"{path}: missing kernel or layout snapshot")
    return header, graph, layout


def check_module(tool, path, header, lines):
    source = header + "".join(line for _, line in lines) + "}\n"
    # 保留两个入口及所有被调用函数，让 MLIR 检查符号、类型和操作。
    result = subprocess.run([tool, "--print-op-stats=json", "-o", "/dev/null"],
                            input=source, capture_output=True, text=True)
    if result.returncode:
        message = result.stderr
        for i, (original, _) in enumerate(lines, 2):
            if f"<stdin>:{i}:" in message:
                message = message.replace(f"<stdin>:{i}:", f"{path}:{original}:")
        raise ValueError(message)
    ops = json.loads(result.stderr)
    for op in sorted(ops.keys() - SUPPORTED):
        where = next((n for n, line in lines if op in line), lines[0][0])
        raise ValueError(f"{path}:{where}: unsupported operation {op}")
    return ops.keys()


def function_names(variant):
    common = {
        "aic", "aiv", "aiv_outlined_vf_2", "aiv_outlined_vf_3", "aiv_fused_4_outlined_vf_0",
        "aiv_fused_4_outlined_vf_1", "aiv_fused_5_outlined_merged_vf_0", "aiv_fused_7_outlined_vf_0",
        "aiv_fused_8_outlined_vf_0", "aiv_fused_1_outlined_merged_vf_0",
        "aiv_fused_0_outlined_merged_merged_vf_0", "aiv_fused_3_outlined_vf_0",
    }
    extra = {"fail": {"aiv_fused_6_outlined_merged_vf_0"},
             "ok": {"aiv_fused_6_outlined_vf_0", "aiv_fused_5_outlined_vf_0"}}
    return {PREFIX + f for f in common | extra[variant]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--opt", default="bishengir-opt")
    parser.add_argument("--fail", type=Path, required=True)
    parser.add_argument("--ok", type=Path, required=True)
    args = parser.parse_args()
    for variant, path in [("fail", args.fail), ("ok", args.ok)]:
        expected = function_names(variant)
        header, graph, layout = sections(path, expected)
        if missing := expected - graph.keys():
            raise ValueError(f"{path}: missing functions {sorted(missing)}")
        graph_ops = check_module(args.opt, path, header, [line for fn in graph.values() for line in fn])
        layout_ops = check_module(args.opt, path, header, layout)
        print(f"{path.name}: {len(graph)} functions, {len(graph_ops | layout_ops)} operation names")


if __name__ == "__main__":
    main()
