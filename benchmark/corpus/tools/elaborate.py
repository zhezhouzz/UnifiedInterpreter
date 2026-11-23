"""Elaborate one post-sync HIVM function to the straight-line core protocol fragment."""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

VECTOR = set("vadd vsub vmul vmax vmin vabs vdiv vexp vln vbrc vcast vrelu vrec vsqrt vtranspose".split())
REASONS = {
    "hivm.hir.pipe_barrier": "The axiomatic syntax has no pipe barrier. Replacing it with a flag changes the protocol.",
    "scf.for": "Loop bounds, iteration bindings and carried aliases need a loop translation.",
    "scf.while": "Data-dependent trip count and yielded state need a while translation.",
    "scf.if": "Branch guards, yields and SSA joins need a conditional translation.",
    "func.call": "The call needs a callee effect summary or inlining.",
    "memref.subview": "A subview needs alias and offset resolution.",
}

class Unsupported(ValueError):
    def __init__(self, node, reason):
        self.op = node["op"]
        self.loc = node["loc"]
        super().__init__(reason)

def fail(node, reason):
    raise Unsupported(node, reason)

def enum(node, field, kind, prefix):
    value = node["attrs"].get(field, "")
    match = re.fullmatch(r"#hivm\." + kind + "<(" + prefix + r"\w+)>", value)
    if not match:
        fail(node, f"Expected a static {kind} in {field}, found {value!r}.")
    return match[1]

def flags(node, constants):
    source = enum(node, "set_pipe", "pipe", "PIPE_")
    dest = enum(node, "wait_pipe", "pipe", "PIPE_")
    if "static_event_id" in node["attrs"]:
        event = enum(node, "static_event_id", "event", "EVENT_ID")
    else:
        args = node["args"]
        if len(args) != 1 or args[0] not in constants or constants[args[0]] < 0:
            fail(node, "Runtime event ID needs a typed event binding. Only literal IDs and nonnegative integer constants are supported.")
        event = f"EVENT_ID{constants[args[0]]}"
    op = "setflag" if node["op"].endswith("set_flag") else "waitflag"
    return f"{op}[{source}, {dest}]({event})"

def monitored_effect(node, bases, offset):
    """Observe whether this single byte lies in a contiguous UB operand; reject unknown aliasing."""
    op = node["op"].split(".")[-1]
    hits = []
    for index, (v, ty) in enumerate(zip(node["args"], node["types"])):
        if not ty.startswith("memref<") or "#hivm.address_space<gm>" in ty:
            continue
        desc = re.fullmatch(r"memref<((?:\d+x)+)(?:f|bf|i)(8|16|32|64), #hivm.address_space<ub>>", ty)
        if not desc or v not in bases:
            fail(node, "Monitored UB requires flat contiguous, statically sized operands with known base offsets.")
        size = int(desc[2]) // 8
        for dim in desc[1][:-1].split("x"):
            size *= int(dim)
        if bases[v] <= offset < bases[v] + size:
            hits.append(index)
    if len(hits) > 1:
        fail(node, "Multiple operands touch the monitored byte. An atomic read/modify/write needs its own abstraction.")
    if not hits:
        return None
    # Whitelist only the fixed arities whose last operand is the sole destination.
    arity = {"load":2, "store":2, "vabs":2, "vadd":3, "vsub":3, "vmul":3}.get(op)
    if len(node["args"]) != arity:
        fail(node, "The addressing or destination segments need an operation-specific memory rule.")
    return "write" if hits[0] == arity - 1 else "read"

def instruction(node, constants, bases, index, watch):
    name = node["op"]
    args, attrs = node["args"], node["attrs"]
    if name == "arith.constant":
        value = re.fullmatch(r"(-?\d+) : (?:i\d+|index)", attrs.get("value", ""))
        if value:
            constants[node["results"][0]] = int(value[1])
        return None
    if name == "hivm.hir.pointer_cast":
        if len(args) == 1 and args[0] in constants:
            bases[node["results"][0]] = constants[args[0]]
        return None
    if name in ("hivm.hir.set_flag", "hivm.hir.wait_flag"):
        return flags(node, constants)
    if name == "func.return":
        if args:
            fail(node, "The calling convention for returned SSA data is unspecified.")
        return "return()"
    op = name.removeprefix("hivm.hir.")
    if name.startswith("hivm.hir.") and op in VECTOR | {"load", "store"}:
        if node["results"] or any(t.startswith("tensor<") for t in node["types"]) or not any(t.startswith("memref<") for t in node["types"]):
            fail(node, "Tensor-stage data operation requires bufferization before dispatch mapping.")
        if "atomic_kind" in attrs and not attrs["atomic_kind"].endswith("<none>"):
            fail(node, "Atomic store needs a read-modify-write and ordering rule.")
        if any("unit_flag" in k.lower() or "unitflag" in k.lower() for k in attrs):
            fail(node, "Unit flag synchronization requires a distinct protocol.")
        pipe = {"load":"MTE2", "store":"MTE3"}.get(op, "V")
        if op == "vbrc":
            target = node["types"][-1]
            if "#hivm.address_space<l1>" in target:
                pipe = "MTE2"
            elif "#hivm.address_space<ub>" not in target:
                fail(node, "vbrc dispatch requires a UB or L1 destination.")
        unit = f"unit_{op}@PIPE_{pipe}"
        effect = monitored_effect(node, bases, watch) if watch is not None else None
        if effect == "read":
            return f"x{index} := read[{unit}](UB_BYTE_{watch})"
        if effect == "write":
            return f"write[{unit}](UB_BYTE_{watch}, {index})"
        return f"x{index} := compute[{unit}]()"
    reason = REASONS.get(name, "No core elaboration rule for this operation.")
    if "sync_block" in name:
        reason = "Cross-core synchronization needs the actual participant set and target notification protocol."
    fail(node, reason)

def select_slice(func, first, last):
    """Resolve a range to sibling operations in one basic block. Nested control is never flattened."""
    def locate(node):
        match = re.fullmatch(r'loc\("<stdin>":(\d+):\d+\)', node["loc"])
        return int(match[1]) if match else None
    def blocks(op):
        for region in op["regions"]:
            for block in region:
                yield block
                for child in block:
                    yield from blocks(child)
    hits = []
    for block in blocks(func):
        starts = [i for i, op in enumerate(block) if locate(op) == first]
        ends = [i for i, op in enumerate(block) if locate(op) == last]
        for i in starts:
            for j in ends:
                if j >= i:
                    hits.append(block[i:j + 1])
    if len(hits) != 1:
        fail(func, "Slice endpoints must identify unambiguous sibling operations in one basic block.")
    return hits[0]

def elaborate(module, function=None, watch=None, lines=None):
    if module["op"] != "builtin.module" or len(module["regions"]) != 1 or len(module["regions"][0]) != 1:
        fail(module, "Expected a single top-level module block.")
    top = module["regions"][0][0]
    funcs = [op for op in top if op["op"] == "func.func"]
    if not function and len(top) != len(funcs):
        fail(module, "Additional module-level operations require an explicit entry and environment.")
    if function:
        funcs = [op for op in funcs if op["attrs"]["sym_name"] == json.dumps(function)]
    if len(funcs) != 1:
        fail(module, "Select exactly one func.func using --function. Available: " +
             ", ".join(op["attrs"]["sym_name"] for op in top if op["op"] == "func.func"))
    func = funcs[0]
    if not lines and (len(func["regions"]) != 1 or len(func["regions"][0]) != 1):
        fail(func, "External declarations and multi-block CFGs need control-flow or external-call semantics.")
    commands, constants, bases, errors = [], {}, {}, []
    selected = select_slice(func, *lines) if lines else func["regions"][0][0]
    for node in selected:
        try:
            cmd = instruction(node, constants, bases, len(commands), watch)
            if cmd is not None:
                commands.append(cmd)
        except Unsupported as error:
            errors.append({"op":error.op, "location":error.loc, "reason":str(error)})
    if errors:
        return None, errors
    if lines and (not commands or commands[-1] != "return()"):
        commands.append("return()")
    if not commands or commands[-1] != "return()":
        fail(func, "Missing supported terminator.")
    return "run {\n" + "".join("  " + c + ";\n" for c in commands[:-1]) + "  return()\n}\n", []

def translate(path, reader, function=None, watch=None, lines=None):
    parsed = subprocess.run([str(reader)], input=path.read_bytes(), capture_output=True)
    if parsed.returncode:
        return None, [{"op":"<parse>", "location":str(path), "reason":parsed.stderr.decode(errors="replace")}]
    try:
        return elaborate(json.loads(parsed.stdout), function, watch, lines)
    except Unsupported as error:
        return None, [{"op":error.op, "location":error.loc, "reason":str(error)}]

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mlir", type=Path)
    parser.add_argument("--reader", required=True, type=Path)
    parser.add_argument("--function")
    parser.add_argument("--watch-ub-byte", type=int)
    parser.add_argument("--lines", nargs=2, metavar=("FIRST", "LAST"), type=int,
                        help="Explicit conditional basic-block slice; starts with an external environment")
    args = parser.parse_args()
    if args.lines and not 0 < args.lines[0] <= args.lines[1]:
        parser.error("invalid source line interval")
    if args.watch_ub_byte is not None and args.watch_ub_byte < 0:
        parser.error("UB byte offset must be nonnegative")
    code, errors = translate(args.mlir, args.reader.resolve(), args.function, args.watch_ub_byte, args.lines)
    if errors:
        print(json.dumps({"file":str(args.mlir), "function":args.function, "errors":errors}, indent=2), file=sys.stderr)
        sys.exit(2)
    sys.stdout.write(code)
