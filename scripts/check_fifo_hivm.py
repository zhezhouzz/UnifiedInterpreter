import argparse
import json
import subprocess
from pathlib import Path

from xdsl.context import Context
from xdsl.dialects import arith, builtin, func, memref, scf
from xdsl.interpreter import Interpreter
from xdsl.interpreters.arith import ArithFunctions
from xdsl.interpreters.func import FuncFunctions
from xdsl.interpreters.memref import MemRefFunctions
from xdsl.interpreters.scf import ScfFunctions
from xdsl.interpreters.shaped_array import ShapedArray
from xdsl.interpreters.utils.ptr import TypedPtr
from xdsl.parser import Parser


def execute(module, inputs, events):
    runtime = Interpreter(module)
    for semantics in (ArithFunctions(), FuncFunctions(), MemRefFunctions(), ScfFunctions()):
        runtime.register_implementations(semantics)
    name = events[0]["entry"].removeprefix("@")
    block = runtime.get_op_for_symbol(name).body.block
    arg, = inputs["bindings"][0]["arguments"]
    size = arg["bytes"] // 4
    memory = ShapedArray(TypedPtr.new_int32([inputs["initial"][arg["storage"]]] * size), [size])
    for cell in inputs["initial_cells"]:
        memory.store((cell["element"],), cell["value"])
    runtime.set_values([(block.args[0], memory)])
    operations = list(block.ops)
    pc = 0
    pending = {}
    for event in events:
        index, = event["path"]
        task, = event["tasks"]
        target = operations[index]
        assert target.name == event["opcode"] and isinstance(target, func.CallOp)
        if event["phase"] == "submit":
            assert pc <= index
            for op in operations[pc:index]:
                assert not isinstance(op, func.CallOp)
                values = runtime.run_op(op, runtime.get_values(op.operands))
                runtime.set_values(zip(op.results, values, strict=True))
            pending[task["id"]] = target, runtime.get_values(target.operands)
            pc = index + 1
        else:
            assert event["phase"] == "complete"
            op, args = pending.pop(task["id"])
            assert op is target
            runtime.run_op(op, args)
    return memory.data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", type=Path, default=Path("_build/default/bin/main.exe"))
    parser.add_argument("--opt", default="bishengir-opt")
    args = parser.parse_args()
    cli = [args.exe.resolve(), "race"]
    source = subprocess.check_output([*cli, "source", "fixture/fifo-copy"])
    generic = subprocess.check_output([args.opt, "--mlir-print-op-generic"], input=source)
    ctx = Context(allow_unregistered=True)
    for dialect in (builtin.Builtin, arith.Arith, func.Func, memref.MemRef, scf.Scf):
        ctx.load_dialect(dialect)
    module = Parser(ctx, generic.decode()).parse_module()
    for backend in ("bfs", "smt"):
        report = json.loads(subprocess.check_output([*cli, "run", "fixture/fifo-copy", "--hivm",
                                                     "--backend", backend]))
        race, = report["races"]
        results = [execute(module, report["inputs"], race[order]) for order in ("forward", "reverse")]
        assert results == [[7, 7, 7], [7, 7, 0]]
        print(f"{backend}: {results}")


if __name__ == "__main__":
    main()
