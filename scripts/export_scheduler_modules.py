import argparse
from hashlib import sha256
import json
from pathlib import Path

from xdsl.context import Context
from xdsl.dialects.builtin import AffineMapAttr, Builtin, DenseArrayBase, FloatAttr, IndexType, IntegerAttr, IntegerType, MemRefType, TensorType, UnregisteredAttr, VectorType
from xdsl.parser import Parser
from scheduler_affine import SemiAffineMaps, affine

from export_vectorlayout_ast import encode_function
from project_hfusion_ir import compile_ir


class ModuleParser(SemiAffineMaps, Parser):
    pass


def type_info(ty):
    if isinstance(ty, (MemRefType, TensorType, VectorType)):
        kind = {MemRefType: "buffer", TensorType: "tensor", VectorType: "vector"}[type(ty)]
        result = {"kind": kind, "shape": [max(-1, n) for n in ty.get_shape()], "element": type_info(ty.element_type)}
        if isinstance(ty, MemRefType) and isinstance(ty.memory_space, UnregisteredAttr):
            result["space"] = ty.memory_space.value.data
        return result
    if isinstance(ty, IntegerType):
        return {"kind": "integer", "bits": ty.width.data}
    if isinstance(ty, IndexType):
        return {"kind": "integer", "bits": 64}
    return {"kind": "other", "name": str(ty)}


def export(opt, source):
    ctx = Context(allow_unregistered=True)
    ctx.load_dialect(Builtin)
    generic = compile_ir(opt, source, "--mlir-print-op-generic", "--mlir-print-local-scope")
    module = ModuleParser(ctx, generic.decode()).parse_module()
    functions = {}
    types = {}
    for function in module.body.block.ops:
        doc = encode_function(function)
        name = function.properties["sym_name"].data
        for op in function.walk():
            for v in [*op.results, *(a for r in op.regions for b in r.blocks for a in b.args)]:
                types[str(v.type)] = type_info(v.type)
        def annotate(op, node):
            parsed = {}
            for key, attr in (op.attributes | op.properties).items():
                if isinstance(attr, IntegerAttr):
                    parsed[key] = str(attr.value.data)
                elif isinstance(attr, FloatAttr):
                    parsed[key] = str(attr.value.data)
                elif isinstance(attr, DenseArrayBase):
                    parsed[key] = list(attr.get_values())
                elif isinstance(attr, AffineMapAttr):
                    parsed[key] = [attr.data.num_dims, [affine(x) for x in attr.data.results]]
                elif isinstance(attr, UnregisteredAttr):
                    parsed[key] = attr.value.data
            if parsed:
                node["literals"] = parsed
            for region, blocks in zip(op.regions, node["regions"], strict=True):
                for block, child in zip(region.blocks, blocks, strict=True):
                    for nested, item in zip(block.ops, child["body"], strict=True):
                        annotate(nested, item)
        annotate(function, doc)
        functions[name] = doc
    return {"format": "hivm-module-1", "source_sha256": sha256(source).hexdigest(),
            "attributes": {k: str(v) for k, v in module.attributes.items()},
            "functions": functions, "types": types}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--opt", default="bishengir-opt")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    pairs = json.loads((root / "benchmarks/ir-pairs/catalog.json").read_bytes())["benchmarks"]
    dest = root / "benchmarks/scheduler/modules"
    dest.mkdir(parents=True, exist_ok=True)
    written = set()
    for case in pairs.values():
        for stage in ("hfusion", "hivm"):
            item = case[stage]
            digest = item["sha256"]
            if digest in written:
                continue
            data = (root / item["path"]).read_bytes()
            doc = export(args.opt, data)
            if doc["source_sha256"] != digest:
                raise ValueError(item["path"])
            path = dest / (digest + ".json")
            if args.check:
                if json.loads(path.read_bytes()) != doc:
                    raise ValueError(f"{path}: module differs from the compiler output")
            else:
                path.write_text(json.dumps(doc, separators=(",", ":")) + "\n")
            written.add(digest)
    print(f"{len(written)} unique modules for {len(pairs)} benchmark pairs")


if __name__ == "__main__":
    main()
