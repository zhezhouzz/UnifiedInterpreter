import json
import sys
from importlib.metadata import version

from xdsl.dialects.builtin import (
    ArrayAttr, DenseArrayBase, FloatAttr, Float16Type, Float32Type,
    IndexType, IntegerAttr, IntegerType, MemRefType, StringAttr,
    TensorType, UnitAttr, UnregisteredAttr, DYNAMIC_INDEX,
)
from xdsl.dialects.func import FuncOp
from xdsl.parser import Parser
from xdsl.utils.lexer import Span

from attention_dialects import ReductionKindAttr, context


class LocatedParser(Parser):
    def __init__(self, ctx, source, filename):
        super().__init__(ctx, source, filename)
        self.locations = {}
        self.names = {}

    def parse_operation(self):
        start = self._current_token.span
        operation = super().parse_operation()
        stop = Span(self.pos, self.pos, start.input)
        self.locations[operation] = {
            "file": start.input.name,
            "start": self.position(start),
            "stop": self.position(stop),
        }
        return operation

    @staticmethod
    def position(span):
        location = span.get_location()
        return {"offset": span.start, "line": location.line, "column": location.col}

    def _register_ssa_definition(self, name, values, span):
        super()._register_ssa_definition(name, values, span)
        if len(values) != 1:
            raise ValueError("attention profile requires individual SSA result bindings")
        self.names[values[0]] = "%" + name


def scalar_type(typ):
    if isinstance(typ, IntegerType):
        if typ.signedness.data.value != 0:
            raise ValueError("attention profile requires signless integer types")
        return "i" + str(typ.width.data)
    if isinstance(typ, IndexType):
        return "index"
    if isinstance(typ, Float16Type):
        return "f16"
    if isinstance(typ, Float32Type):
        return "f32"
    raise ValueError(f"unsupported element type: {typ}")


def export_type(typ):
    if isinstance(typ, TensorType | MemRefType):
        return {
            "kind": "tensor" if isinstance(typ, TensorType) else "memref",
            "shape": [-1 if n == DYNAMIC_INDEX else n for n in typ.get_shape()],
            "element": scalar_type(typ.get_element_type()),
        }
    return {"kind": "scalar", "element": scalar_type(typ)}


def export_attribute(attribute):
    if isinstance(attribute, UnitAttr):
        return True
    if isinstance(attribute, IntegerAttr):
        return attribute.value.data
    if isinstance(attribute, FloatAttr):
        return repr(attribute.value.data)
    if isinstance(attribute, StringAttr):
        return attribute.data
    if isinstance(attribute, DenseArrayBase):
        return list(attribute.get_values())
    if isinstance(attribute, ArrayAttr):
        return [export_attribute(value) for value in attribute.data]
    if isinstance(attribute, UnregisteredAttr):
        return {"enum": attribute.attr_name.data, "value": attribute.value.data}
    if isinstance(attribute, ReductionKindAttr):
        return attribute.data.value
    raise ValueError(f"unsupported attribute: {attribute}")


def export_operation(operation, parser):
    if len(operation.results) > 1:
        raise ValueError("attention profile supports at most one result")
    attributes = dict(operation.attributes)
    properties = dict(operation.properties)
    properties.pop("operandSegmentSizes", None)
    # xDSL 为整数和浮点算术补充默认 flags；执行配置只接受空 flags。
    for name in ("fastmath", "overflowFlags"):
        if name in properties:
            if properties[name].data:
                raise ValueError(f"unsupported {name}: {properties[name]}")
            del properties[name]
    if attributes.keys() & properties.keys():
        raise ValueError("duplicate operation attribute/property")
    attributes.update(properties)
    values = {name: export_attribute(value) for name, value in attributes.items()}
    inputs = []
    outputs = []
    region = []
    region_arguments = []
    else_region = []
    name = operation.name
    if name.startswith(("linalg.", "hivm.", "hfusion.")) and name != "linalg.yield":
        if name == "linalg.reduce":
            inputs = [operation.operands[0]]
            outputs = [operation.operands[1]]
        elif name in {"linalg.broadcast", "linalg.transpose"}:
            inputs = list(operation.operands[:-1])
            outputs = [operation.operands[-1]]
        else:
            inputs = list(operation.operands[:-1])
            outputs = [operation.operands[-1]]
    if name in {"scf.for", "linalg.reduce"}:
        if len(operation.regions) != 1 or len(operation.regions[0].blocks) != 1:
            raise ValueError("attention control flow requires one block")
        block = operation.regions[0].block
        region_arguments = [
            {"name": parser.names[arg], "type": export_type(arg.type)}
            for arg in block.args
        ]
        for child in block.ops:
            if child not in parser.locations:
                if child.name != "scf.yield" or child.operands:
                    raise ValueError("unsupported implicit region operation")
                continue
            region.append(export_operation(child, parser))
    if name == "scf.if":
        if operation.results:
            raise ValueError("scf.if results are unsupported")
        for index, branch in enumerate(operation.regions):
            if not branch.blocks:
                continue
            if len(branch.blocks) != 1 or branch.block.args:
                raise ValueError("scf.if requires argument-free single-block branches")
            target = region if index == 0 else else_region
            for child in branch.block.ops:
                if child not in parser.locations:
                    if child.name != "scf.yield" or child.operands:
                        raise ValueError("unsupported implicit branch operation")
                    continue
                target.append(export_operation(child, parser))
    if name in {"memref.subview", "tensor.extract_slice"}:
        for key in ("offsets", "sizes", "strides"):
            dynamic = iter(getattr(operation, key))
            entries = []
            for value in getattr(operation, "static_" + key).get_values():
                if value == DYNAMIC_INDEX:
                    operand = next(dynamic, None)
                    if operand is None:
                        raise ValueError("missing dynamic " + key)
                    entries.append({"ssa": parser.names[operand]})
                else:
                    entries.append({"static": value})
            if next(dynamic, None) is not None:
                raise ValueError("extra dynamic " + key)
            del values["static_" + key]
            values[key] = entries
    if name == "memref.reinterpret_cast":
        offsets = list(operation.offsets)
        values["offsets"] = [
            parser.names[offsets.pop(0)] if value == DYNAMIC_INDEX else str(value)
            for value in operation.static_offsets.get_values()
        ]
        if offsets or operation.sizes or operation.strides:
            raise ValueError("attention profile requires static view sizes and strides")
        del values["static_offsets"]
        values["sizes"] = values.pop("static_sizes")
        values["strides"] = values.pop("static_strides")
    return {
        "opcode": name,
        "result": parser.names[operation.results[0]] if operation.results else None,
        "operands": [parser.names[value] for value in operation.operands],
        "operand_types": [export_type(value.type) for value in operation.operands],
        "result_type": export_type(operation.results[0].type) if operation.results else None,
        "inputs": [parser.names[value] for value in inputs],
        "outputs": [parser.names[value] for value in outputs],
        "attributes": values,
        "region": region,
        "else_region": else_region,
        "region_arguments": region_arguments,
        "span": parser.locations[operation],
    }


def read_program(source, filename):
    if version("xdsl") != "0.74.0":
        raise RuntimeError("attention requires xdsl==0.74.0")
    parser = LocatedParser(context(), source, filename)
    module = parser.parse_module()
    module.verify()
    functions = tuple(module.body.block.ops)
    if len(functions) != 1 or not isinstance(functions[0], FuncOp):
        raise ValueError("attention input must contain exactly one function")
    function = functions[0]
    if len(function.body.blocks) != 1:
        raise ValueError("attention function must have one entry block")
    return {
        "name": "@" + function.sym_name.data,
        "arguments": [
            {"name": parser.names[arg], "type": export_type(arg.type)}
            for arg in function.body.block.args
        ],
        "body": [
            export_operation(operation, parser)
            for operation in function.body.block.ops
        ],
    }


if __name__ == "__main__":
    json.dump(read_program(sys.stdin.read(), sys.argv[1]), sys.stdout, allow_nan=False)
    sys.stdout.write("\n")
