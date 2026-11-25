import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from xdsl.context import Context
from xdsl.dialects.builtin import Builtin, UnregisteredOp
from xdsl.parser import Parser

from check_vectorlayout_sources import FUSED, function_names, sections


DIGESTS = {
    "ok": "10b036e929601b3436971e55b64faf828f3cd8b447b2233f98764305327ef4cd",
    "fail": "f5ce22f8993f97e7b5efe9ad11dbdb7a12482fb191fe8402385345cda44d2f29",
}


def encode_function(function):
    # SSA 编号以函数为作用域，保留每个结果及 block 参数的原始 MLIR 类型。
    numbers = {}

    def define(value):
        number = len(numbers)
        numbers[value] = number
        return [number, str(value.type)]

    def block(b):
        return {"arguments": [define(a) for a in b.args], "body": [node(o) for o in b.ops]}

    def node(op):
        if op.successors:
            raise ValueError("unexpected CFG successor in structured vectorlayout module")
        name = op.op_name.data if isinstance(op, UnregisteredOp) else op.name
        return {
            "opcode": name,
            "operands": [numbers[v] for v in op.operands],
            "results": [define(v) for v in op.results],
            "attributes": {k: str(v) for k, v in op.attributes.items() if k != "op_name__"},
            "properties": {k: str(v) for k, v in op.properties.items()},
            "regions": [[block(b) for b in region.blocks] for region in op.regions],
        }

    return node(function)


def main():
    args = argparse.ArgumentParser()
    args.add_argument("variant", choices=DIGESTS)
    args.add_argument("dump", type=Path)
    args.add_argument("--opt", default="bishengir-opt")
    args.add_argument("--output", required=True, type=Path)
    args.add_argument("--mlir", type=Path)
    options = args.parse_args()
    with options.dump.open("rb") as data:
        if hashlib.file_digest(data, "sha256").hexdigest() != DIGESTS[options.variant]:
            raise ValueError("unexpected vectorlayout compiler dump")
    expected = function_names(options.variant)
    header, graph, layout = sections(options.dump, expected)
    if graph.keys() != expected:
        raise ValueError("incomplete GraphSyncSolver module")
    graph[FUSED] = layout
    source = header + "".join(line for name in sorted(graph) for _, line in graph[name]) + "}\n"
    # BiShengIR 验证所有调用和类型。xDSL 读取其标准 generic assembly。
    canonical = subprocess.run([options.opt, "--mlir-print-op-generic"], input=source,
                               capture_output=True, text=True)
    if canonical.returncode:
        raise ValueError(canonical.stderr)
    context = Context(allow_unregistered=True)
    context.load_dialect(Builtin)
    module = Parser(context, canonical.stdout).parse_module()
    doc = {"format": "hivm-module-1", "archive_sha256": DIGESTS[options.variant],
           "attributes": {k: str(v) for k, v in module.attributes.items()},
           "functions": {op.properties["sym_name"].data: encode_function(op)
                         for op in module.body.block.ops}}
    options.output.write_text(json.dumps(doc, separators=(",", ":"), sort_keys=True) + "\n")
    if options.mlir:
        options.mlir.write_text(source)


if __name__ == "__main__":
    main()
