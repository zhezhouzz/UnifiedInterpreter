import argparse
import hashlib
import io
import json
from importlib.metadata import version
from pathlib import Path

from xdsl.dialects.builtin import MemRefType, ModuleOp, f32
from xdsl.dialects.func import FuncOp, ReturnOp
from xdsl.ir import BlockArgument, OpResult
from xdsl.parser import Parser
from xdsl.printer import Printer

from attention_dialects import context


ROOT = Path(__file__).resolve().parents[1]
SIGNATURES = {
    "vector_add": [("a", [8]), ("b", [8]), ("out", [8])],
    "row_sum": [("input", [3, 4]), ("out", [3])],
}


def load(path):
    module = Parser(context(), path.read_text(), str(path)).parse_module()
    module.verify()
    functions = tuple(module.body.block.ops)
    if len(functions) != 1 or not isinstance(functions[0], FuncOp):
        raise ValueError(f"expected one compiled function: {path}")
    return functions[0]


def new_entry(name, source):
    signature = SIGNATURES[name]
    function = FuncOp(name, ([MemRefType(f32, shape) for _, shape in signature], []))
    old_arguments = source.body.block.args
    if len(old_arguments) != len(signature) + 8:
        raise ValueError("unexpected Triton-Ascend entry ABI")
    mapper = {}
    for index, old in enumerate(old_arguments):
        if 2 <= index < 2 + len(signature):
            argument = function.body.block.args[index - 2]
            argument.name_hint = signature[index - 2][0]
            mapper[old] = argument
        elif old.uses:
            raise ValueError("kernel uses implicit runtime arguments")
    return function, mapper


def append_operation(operation, destination, mapper):
    if operation.results and all(value in mapper for value in operation.results):
        return
    # 复制跨分段依赖时保留原来的 SSA 定义。
    for nested in operation.walk():
        for operand in nested.operands:
            if operand in mapper:
                continue
            if isinstance(operand, OpResult) and operand.owner.parent_block() is operation.parent_block():
                append_operation(operand.owner, destination, mapper)
            elif isinstance(operand, BlockArgument) and operand.block is operation.parent_block():
                raise ValueError("unbound compiled function argument")
    destination.body.block.add_op(operation.clone(value_mapper=mapper))


def segments(source):
    groups = []
    pending = []
    for operation in source.body.block.ops:
        if isinstance(operation, ReturnOp):
            continue
        pending.append(operation)
        if operation.name == "bufferization.materialize_in_destination":
            groups.append(pending)
            pending = []
    if pending:
        raise ValueError("compiled kernel has operations after its final store")
    return groups


def render(function):
    function.body.block.add_op(ReturnOp())
    module = ModuleOp([function])
    module.verify()
    stream = io.StringIO()
    Printer(stream=stream).print_op(module)
    text = stream.getvalue() + "\n"
    Parser(context(), text).parse_module().verify()
    return text


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=ROOT / "artifacts/kernels")
    parser.add_argument("--output", type=Path, default=ROOT / "examples/kernels")
    parser.add_argument("--kernel", choices=tuple(SIGNATURES))
    args = parser.parse_args()
    if version("xdsl") != "0.74.0":
        raise ValueError("kernel IR preparation requires xdsl==0.74.0")
    compiler_provenance = json.loads((args.input / "provenance.json").read_text())
    for kernel in compiler_provenance["kernels"].values():
        for filename, expected_hash in kernel["artifacts"].items():
            if hashlib.sha256((args.input / filename).read_bytes()).hexdigest() != expected_hash:
                raise ValueError(f"compiler artifact hash mismatch: {filename}")
    args.output.mkdir(parents=True, exist_ok=True)
    provenance = {
        "abi": "static f32 arguments; unused implicit arguments removed",
        "xdsl": version("xdsl"),
        "generator_sha256": hashlib.sha256(Path(__file__).resolve().read_bytes()).hexdigest(),
        "kernels": {},
    }
    for name in ([args.kernel] if args.kernel else SIGNATURES):
        sources = {stage: load(args.input / f"{name}.{stage}.mlir")
                   for stage in ("hfusion", "hivm")}
        outputs = {}
        for stage, source in sources.items():
            function, mapper = new_entry(name, source)
            for operation in source.body.block.ops:
                if not isinstance(operation, ReturnOp):
                    append_operation(operation, function, mapper)
            outputs[stage] = render(function)
        groups = {stage: segments(source) for stage, source in sources.items()}
        if len(groups["hfusion"]) != len(groups["hivm"]) or len(groups["hfusion"]) < 2:
            raise ValueError("mixed kernel requires matching independent output segments")
        function, hfusion_mapper = new_entry(name, sources["hfusion"])
        _, hivm_arguments = new_entry(name, sources["hivm"])
        hivm_mapper = {
            old: new for old, new in zip(hivm_arguments, function.body.block.args)
        }
        for index in range(len(groups["hfusion"])):
            stage = "hfusion" if index == 0 else "hivm"
            mapper = hfusion_mapper if stage == "hfusion" else hivm_mapper
            for operation in groups[stage][index]:
                append_operation(operation, function, mapper)
        outputs["mixed"] = render(function)
        for stage, text in outputs.items():
            (args.output / f"{name}_{stage}.mlir").write_text(text)
        provenance["kernels"][name] = {
            "signature": SIGNATURES[name],
            "mixed_segments": ["hfusion"] + ["hivm"] * (len(groups["hfusion"]) - 1),
            "inputs": {stage: hashlib.sha256((args.input / f"{name}.{stage}.mlir").read_bytes()).hexdigest()
                       for stage in sources},
            "outputs": {stage: hashlib.sha256(text.encode()).hexdigest() for stage, text in outputs.items()},
        }
    (args.output / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")


if __name__ == "__main__":
    main()
