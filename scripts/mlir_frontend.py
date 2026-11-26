"""Parse an HFusion/HIVM MLIR module for the Core Language lowerer."""

import argparse
import json
import subprocess
import sys

from xdsl.context import Context
from xdsl.dialects.builtin import (
    ArrayAttr, Builtin, DenseArrayBase, DYNAMIC_INDEX, FileLineColLoc, FloatAttr,
    IndexType, IntegerAttr, IntegerType, MemRefType, NameLoc, NoneAttr,
    StridedLayoutAttr, StringAttr, TensorType, UnitAttr, UnregisteredOp, VectorType,
)
from xdsl.dialects.utils import EnumAttribute
from xdsl.utils.exceptions import ParseError, VerifyException

from attention_frontend import read_module


def opcode(op):
    return op.op_name.data if isinstance(op, UnregisteredOp) else op.name


def encode_function(function, describe_type=str, annotate=None):
    numbers = {}

    def define(value):
        number = len(numbers)
        numbers[value] = number
        return [number, describe_type(value.type)]

    def block(b):
        return {"arguments": [define(a) for a in b.args], "body": [node(o) for o in b.ops]}

    def node(op):
        details = annotate(op) if annotate is not None else {}
        if op.successors:
            span = details.get("span")
            where = f"{span['file']}:{span['start']['line']}:{span['start']['column']}" if span else str(op.location)
            raise ValueError(f"{where}: {opcode(op)} uses unsupported CFG successors")
        result = {
            "opcode": opcode(op),
            "operands": [numbers[v] for v in op.operands],
            "results": [define(v) for v in op.results],
            "attributes": {k: str(v) for k, v in op.attributes.items() if k != "op_name__"},
            "properties": {k: str(v) for k, v in op.properties.items()},
            "regions": [[block(b) for b in region.blocks] for region in op.regions],
        }
        result.update(details)
        return result

    return node(function)


def type_info(typ):
    if isinstance(typ, IntegerType):
        return {"kind": "integer", "bits": typ.width.data}
    if isinstance(typ, IndexType):
        return {"kind": "integer", "bits": 64}
    if isinstance(typ, TensorType | MemRefType | VectorType):
        info = {
            "kind": "memref" if isinstance(typ, MemRefType) else (
                "tensor" if isinstance(typ, TensorType) else "vector"),
            "shape": [None if dim == DYNAMIC_INDEX else dim for dim in typ.get_shape()],
            "element": str(typ.get_element_type()),
        }
        if isinstance(typ, MemRefType):
            info["space"] = None if isinstance(typ.memory_space, NoneAttr) else str(typ.memory_space)
            if isinstance(typ.layout, StridedLayoutAttr):
                info.update(layout="strided", offset=typ.get_offset(), strides=typ.get_strides())
            else:
                info["layout"] = "identity" if isinstance(typ.layout, NoneAttr) else "opaque"
        return info
    bits = {"bf16": 16, "f16": 16, "f32": 32, "f64": 64}.get(str(typ))
    return {"kind": "float", "bits": bits} if bits is not None else {"kind": "opaque"}


def attribute_value(attr):
    if isinstance(attr, IntegerAttr):
        return attr.value.data
    if isinstance(attr, FloatAttr):
        return repr(attr.value.data)
    if isinstance(attr, StringAttr):
        return attr.data
    if isinstance(attr, UnitAttr):
        return True
    if isinstance(attr, DenseArrayBase):
        return list(attr.get_values())
    if isinstance(attr, ArrayAttr):
        return [attribute_value(value) for value in attr.data]
    if isinstance(attr, EnumAttribute):
        return attr.data.value
    return str(attr)


def export_module(source, filename, generic=False, normalized=False):
    ctx = Context(allow_unregistered=True) if generic else None
    if ctx is not None:
        ctx.load_dialect(Builtin)
    parser_filename = f"{filename} (generic assembly)" if normalized else filename
    module, parser = read_module(source, parser_filename, ctx)
    types = {}

    def describe_type(typ):
        name = str(typ)
        if name not in types:
            types[name] = type_info(typ)
        if isinstance(typ, TensorType | MemRefType | VectorType):
            describe_type(typ.get_element_type())
        return name

    def annotate(op):
        values = dict(op.attributes)
        values.update(op.properties)
        values.pop("op_name__", None)
        span = parser.locations.get(op)
        if normalized:
            location = op.location
            while isinstance(location, NameLoc):
                location = location.location
            if isinstance(location, FileLineColLoc):
                path = location.filename.data
                position = {"offset": 0, "line": location.line.data, "column": location.column.data}
                span = {"file": filename if path in {"-", "<stdin>"} else path,
                        "start": position, "stop": position}
        return {
            "decoded": {key: attribute_value(value) for key, value in values.items()},
            "generic": isinstance(op, UnregisteredOp),
            "span": span,
            "location": str(op.location),
        }

    functions = {}
    for op in module.body.block.ops:
        if opcode(op) != "func.func":
            where = parser.locations.get(op)
            line = where["start"]["line"] if where else 1
            raise ValueError(f"{filename}:{line}: unsupported module operation {opcode(op)}")
        name = op.properties.get("sym_name", op.attributes.get("sym_name")).data
        if name in functions:
            raise ValueError(f"{filename}: duplicate function @{name}")
        functions[name] = encode_function(op, describe_type, annotate)
    return {
        "format": "mlir-module-1",
        "attributes": {key: str(value) for key, value in module.attributes.items()},
        "functions": functions,
        "types": types,
    }


def main():
    arguments = argparse.ArgumentParser(description=__doc__)
    arguments.add_argument("filename", help="source name for diagnostics")
    mode = arguments.add_mutually_exclusive_group()
    mode.add_argument("--generic", action="store_true", help="read MLIR generic assembly")
    mode.add_argument("--bishengir-opt", help="convert vendor custom assembly to generic assembly")
    args = arguments.parse_args()
    source = sys.stdin.read()
    try:
        if args.bishengir_opt:
            source = subprocess.run(
                [args.bishengir_opt, "--mlir-print-op-generic", "--mlir-print-debuginfo"],
                input=source, stdout=subprocess.PIPE, text=True, check=True,
            ).stdout
        normalized = args.bishengir_opt is not None
        doc = export_module(source, args.filename, args.generic or normalized, normalized=normalized)
    except (ParseError, VerifyException, ValueError, RuntimeError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from None
    json.dump(doc, sys.stdout, allow_nan=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
