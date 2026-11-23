"""One-coordinate projection for rank-one FP32 copy/fill regressions (pre-HIVM)."""
import argparse
import json
import re
import subprocess
from pathlib import Path

def project(module, lane):
    if lane < 0:
        raise ValueError("lane must be nonnegative")
    functions = module["regions"][0][0]
    if len(functions) != 1 or functions[0]["op"] != "func.func":
        raise ValueError("expected one function")
    func = functions[0]
    if len(func["regions"][0]) != 1:
        raise ValueError("expected one straight-line block")
    views, zeros, cmds = {}, set(), []
    def size(ty):
        match = re.fullmatch(r"memref<(\d+)xf32>", ty)
        if not match:
            raise ValueError("expected contiguous static rank-one f32 storage, got " + ty)
        return int(match[1])
    for i, arg in enumerate(func["regionArgs"][0][0]):
        views[arg["id"]] = (i, size(arg["type"]))
    storage_count = len(views)
    for op in func["regions"][0][0]:
        name, args, attrs = op["op"], op["args"], op["attrs"]
        def reject(reason):
            raise ValueError(f'{op["loc"]} {name}: {reason}')
        if name == "memref.alloc" and not args:
            views[op["results"][0]] = (storage_count, size(op["resultTypes"][0]))
            storage_count += 1
        elif name == "memref.subview":
            if len(args) != 1 or attrs["static_offsets"] != "array<i64: 0>" or attrs["static_strides"] != "array<i64: 1>":
                reject("only zero-offset unit-stride sibling views preserve the projected lane")
            m = re.fullmatch(r"array<i64: (\d+)>", attrs["static_sizes"])
            if not m or args[0] not in views:
                reject("unknown extent or view base")
            base, extent = views[args[0]]
            if int(m[1]) > extent:
                reject("view exceeds source")
            views[op["results"][0]] = (base, int(m[1]))
        elif name == "arith.constant" and re.fullmatch(r"0\.0+e\+00 : f32", attrs["value"]):
            zeros.add(op["results"][0])
        elif name == "linalg.fill" and len(args) == 2 and args[0] in zeros and args[1] in views:
            dst, extent = views[args[1]]
            if lane < extent:
                cmds.append(f"write[mem](CELL_{dst}, 0)")
        elif name == "memref.copy" and all(v in views for v in args):
            (src, n), (dst, m) = (views[v] for v in args)
            if n != m:
                reject("different copy extents")
            if lane < n:
                x = f"x{len(cmds)}"
                cmds.extend([f"{x} := read[mem](CELL_{src})", f"write[mem](CELL_{dst}, {x})"])
        elif name != "func.return" or args:
            reject("no one-coordinate copy/fill rule")
    return "run {\n" + "".join("  " + c + ";\n" for c in cmds) + "  return()\n}\n"

def translate(path, reader, lane):
    result = subprocess.run([reader], input=path.read_bytes(), capture_output=True, check=True)
    return project(json.loads(result.stdout), lane)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mlir", type=Path)
    parser.add_argument("--reader", required=True)
    parser.add_argument("--lane", type=int, required=True)
    args = parser.parse_args()
    try:
        print(translate(args.mlir, args.reader, args.lane), end="")
    except (ValueError, subprocess.CalledProcessError) as e:
        parser.exit(2, str(e) + "\n")
