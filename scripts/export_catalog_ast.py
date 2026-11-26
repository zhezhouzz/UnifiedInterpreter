import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from xdsl.context import Context
from xdsl.dialects.builtin import Builtin, NameLoc
from xdsl.parser import Parser

from mlir_frontend import encode_function


REVISION = "ee071f0409535dd13fcb2e2e96fd3e5f5ce050eb"
CONTROL = {"if": "scf.if", "for": "scf.for"}
SYNC = {"pipebarrier": "hivm.hir.pipe_barrier", "setflag": "hivm.hir.set_flag",
        "waitflag": "hivm.hir.wait_flag", "syncblockset": "hivm.hir.sync_block_set",
        "syncblockwait": "hivm.hir.sync_block_wait", "scalarstore": "memref.store"}
PURE = {"annotation.mark", "hivm.hir.get_block_idx", "hivm.hir.get_sub_block_idx",
        "hivm.hir.pointer_cast", "hivm.hir.set_mask_norm", "memref.reinterpret_cast",
        "memref.subview", "scf.yield", "func.return"}


def litao_sites(commands, body, site, path):
    # Core 的循环携带视图可以额外产生 cmpi 和 select。两者都在解释器中同步求值。
    indexed = iter((i, op) for i, op in enumerate(body)
                   if op["opcode"] not in PURE and not op["opcode"].startswith(("arith.", "affine.")))
    for cmd in commands:
        kind = cmd["cmd"]
        if kind == "scalar":
            site = [*site, 0]
            continue
        if kind in ("end", "return"):
            break
        i, op = next(indexed)
        if kind == "issue":
            expected = "hivm.hir." + ("custom" if cmd["fn"] == "indirect_atomic_add" else cmd["fn"])
        else:
            expected = (CONTROL | SYNC)[kind]
        target = [*path, i]
        if op["opcode"] != expected:
            raise ValueError((target, expected, op["opcode"]))
        if kind in CONTROL:
            for r, commands_in_region in enumerate(cmd["bodies"]):
                blocks = op["regions"][r]
                native = blocks[0]["body"] if blocks else []
                yield from litao_sites(commands_in_region, native, [*site, r], [*target, r, 0])
            site = [*site, len(cmd["bodies"])]
        else:
            yield [site, target]
            site = [*site, 0]
    if next(indexed, None) is not None:
        raise ValueError("unmapped HIVM operation")


def fixture_sites(block, path):
    for i, op in enumerate(block.ops):
        target = [*path, i]
        if isinstance(op.location, NameLoc):
            label, *site = op.location.desc.data.split(".")
            if label != "site":
                raise ValueError(label)
            yield [list(map(int, site)), target]
        for r, region in enumerate(op.regions):
            for b, child in enumerate(region.blocks):
                yield from fixture_sites(child, [*target, r, b])


def export(opt, source, name, core):
    flags = ["--mlir-print-op-generic", "--mlir-print-local-scope"]
    if core is None:
        flags.append("--mlir-print-debuginfo")
    result = subprocess.run([opt, *flags], input=source, stdout=subprocess.PIPE, check=True)
    context = Context(allow_unregistered=True)
    context.load_dialect(Builtin)
    module = Parser(context, result.stdout.decode()).parse_module()
    functions, sites = {}, {}
    for func in module.body.block.ops:
        sym = func.properties["sym_name"].data
        functions[sym] = encode_function(func)
        if core is None and sym.startswith("stream_"):
            sites[sym] = list(fixture_sites(func.regions[0].block, []))
        if core is not None and sym in core:
            entry = functions[sym]["regions"][0][0]
            if [ty for _, ty in entry["arguments"]] != [arg["type"] for arg in core[sym]["params"]]:
                raise ValueError(f"{name}: entry parameter types differ")
            sites[sym] = list(litao_sites(core[sym]["body"], entry["body"], [], []))
    if core is not None and sites.keys() != core.keys():
        raise ValueError(f"{name}: missing kernel entry")
    return {"format": "hivm-module-1", "benchmark": name, "sites": sites, "functions": functions,
            "source_sha256": hashlib.sha256(source).hexdigest(),
            "attributes": {k: str(v) for k, v in module.attributes.items()}}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--litao-repo", type=Path, required=True)
    parser.add_argument("--opt", default="bishengir-opt")
    parser.add_argument("--exe", type=Path, default=Path("_build/default/bin/main.exe"))
    parser.add_argument("--output", type=Path, default=Path("benchmarks/hivm"))
    args = parser.parse_args()
    root = Path("benchmarks/litao")
    cases = {json.loads(f.read_text())["id"]: f.parent.relative_to(root) for f in root.rglob("case.json")}
    cli = [args.exe.resolve(), "race"]
    names = subprocess.check_output([*cli, "list"], text=True).splitlines()
    archived = {"fixture/hivm-two-loads", "issue316/ordered", "issue316/missing-ready",
                "vectorlayout/ok", "vectorlayout/fail"}
    manifest = {}
    for name in sorted(set(names) - archived):
        core = None
        if name.startswith("litao/"):
            _, case, variant = name.split("/")
            def original(ext):
                file = Path("benchmark") / cases[case] / f"{variant}.{ext}"
                return subprocess.check_output(["git", "-C", args.litao_repo, "show", f"{REVISION}:{file}"])
            source = original("hivm.mlir")
            model = original("program.core")
            if model != (root / cases[case] / f"{variant}.program.core").read_bytes():
                raise ValueError(f"{name}: local Core program differs from the source revision")
            core = json.loads(model)
        else:
            source = subprocess.check_output([*cli, "source", name])
            model = source
        doc = export(args.opt, source, name, core)
        doc["model_digest"] = hashlib.md5(model).hexdigest()
        data = json.dumps(doc, sort_keys=True, separators=(",", ":")).encode()
        path = args.output / (name + ".ast.json")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data + b"\n")
        manifest[name] = hashlib.md5(data).hexdigest()
    (args.output / "catalog.json").write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n")


if __name__ == "__main__":
    main()
