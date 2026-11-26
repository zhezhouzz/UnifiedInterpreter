import itertools
import json
import math
import operator
from dataclasses import dataclass
import sys
from scheduler_inputs import prepare_inputs
from mlir_benchmark_launch import launch_for, source_signature


def strides(shape):
    return tuple(math.prod(shape[i + 1:]) for i in range(len(shape)))


def ranges(shape, steps, offset, width):
    result = [(offset, offset + width)]
    for size, step in reversed(list(zip(shape, steps, strict=True))):
        if size < 0:
            raise ValueError("dynamic shape requires a launch descriptor")
        if not size:
            return []
        shift = step * width
        if len(result) == 1 and abs(shift) <= result[0][1] - result[0][0]:
            lo, hi = result[0]
            result = [(lo + min(0, (size-1)*shift), hi + max(0, (size-1)*shift))]
        else:
            spans = sorted((lo + i*shift, hi + i*shift) for i in range(size) for lo, hi in result)
            result = []
            for lo, hi in spans:
                if result and lo <= result[-1][1]:
                    result[-1] = (result[-1][0], max(result[-1][1], hi))
                else:
                    result.append((lo, hi))
    return result


@dataclass(frozen=True)
class View:
    bank: str
    bits: int
    offset: int
    shape: tuple
    steps: tuple
    width: int
    initialized: bool

    def spans(self, indices=None):
        if indices is None:
            spans = ranges(self.shape, self.steps, self.offset, self.width)
        else:
            if len(indices) != len(self.shape) or any(i < 0 or i >= n for i, n in zip(indices, self.shape)):
                raise EndOfPrefix()
            start = self.offset + sum(i*s for i, s in zip(indices, self.steps)) * self.width
            spans = [(start, start+self.width)]
        if any(lo < 0 or hi > self.bits for lo, hi in spans):
            raise EndOfPrefix()
        return [(self.bank, lo, hi, self.initialized) for lo, hi in spans]


class EndOfPrefix(Exception):
    pass


@dataclass(frozen=True)
class Alias:
    view: View


@dataclass(frozen=True)
class Loaded:
    cell: tuple


TENSOR = object()
EMPTY = object()


def width(ty):
    if ty["kind"] == "integer":
        return ty["bits"]
    if ty["kind"] == "buffer":
        return 64
    return {"f16": 16, "bf16": 16, "f32": 32, "f64": 64}[ty["name"]]


def bind(ty, arg):
    if ty["kind"] != "buffer":
        return arg
    w = width(ty["element"])
    if "descriptor_slot" in arg:
        return View(arg["descriptor_slot"], 64, 0, (1,), (1,), 64, False)
    bits = arg["bytes"]*8
    shape = tuple(arg.get("shape", [bits//w if d == -1 else d for d in ty["shape"]]))
    return View(arg["storage"], bits, arg.get("offset_bits", 0), shape,
                tuple(arg.get("strides", strides(shape))), w, arg.get("initialized", True))


def overlaps(a, b):
    return a[0] == b[0] and max(a[1], b[1]) < min(a[2], b[2])


class Schedule:
    def __init__(self, module, inputs):
        self.module = module
        self.inputs = inputs
        self.nodes = []
        self.last = {}
        self.slots = {}
        self.scalar_reads = []

    def emit(self, event, reads=(), writes=(), claims=()):
        stream = event["stream"]
        deps = [[self.last[stream]]] if stream in self.last else []
        self.last[stream] = len(self.nodes)
        self.nodes.append(dict(event=event, reads=list(reads), writes=list(writes),
                               claims=list(claims), requires=deps, excludes=[]))

    def integer(self, value):
        if isinstance(value, Loaded):
            self.scalar_reads.append(value.cell)
            bank, start, end, _ = value.cell
            element = start // (end-start)
            for cell in self.inputs.get("initial_cells", []):
                if cell["storage"] == bank and cell["element"] == element:
                    return cell["value"]
            default = self.inputs.get("initial", {}).get(bank, self.inputs.get("initial_default", 0))
            value = self.inputs.get("memory", {}).get(bank, {}).get(str(start), default)
            return element if value == "identity" else int(value)
        if not isinstance(value, int):
            raise ValueError(f"expected a concrete index, got {value!r}")
        return value

    def operation(self, op, types, values, event):
        return None

    def block(self, entry, stream, block, arguments, env, parent, iterations, calls):
        env = env | dict(zip((n for n, _ in block["arguments"]), arguments, strict=True))
        for i, op in enumerate(block["body"]):
            path = [*parent, i]
            code = op["opcode"]
            values = [env[n] for n in op["operands"]]
            types = [self.module["types"][t] for _, t in op["results"]]
            literals = op.get("literals", {})
            props = op["properties"]
            event = dict(entry=entry, stream=stream, path=path, iterations=iterations, calls=calls,
                         opcode=code, phase="execute")
            def region(r, args=(), rounds=iterations):
                return self.block(entry, stream, op["regions"][r][0], args, env,
                                  [*path, r, 0], rounds, calls)
            def read_views(xs):
                return [span for v in xs if isinstance(v, Alias) for span in v.view.spans()]
            def local(shape):
                bank = "local:" + json.dumps([stream, entry, path, iterations, calls], separators=(",", ":"))
                w = width(types[0]["element"])
                return View(bank, math.prod(shape)*w, 0, shape, strides(shape), w, False)
            out = []
            if code in ("func.return", "scf.yield", "scf.condition"):
                return values
            special = self.operation(op, types, values, event)
            if special is not None:
                out = special
            elif code == "func.call":
                callee = props["callee"]
                frame = dict(entry=entry, path=path, iterations=iterations)
                out = self.block(callee, stream, self.body(callee), values, {}, [], [], [*calls, frame])
            elif code == "arith.constant":
                converter = int if types[0]["kind"] == "integer" else float
                out = [converter(literals["value"])]
            elif code == "arith.cmpi":
                a, b = map(self.integer, values)
                predicates = [operator.eq, operator.ne, operator.lt, operator.le, operator.gt, operator.ge]
                out = [int(predicates[int(literals["predicate"])](a, b))]
            elif code in ("arith.extsi", "arith.index_cast"):
                out = [self.integer(values[0])]
            elif code in ("arith.addi", "arith.andi", "arith.muli", "arith.subi", "arith.divsi", "arith.remsi"):
                a, b = map(self.integer, values)
                if code in ("arith.divsi", "arith.remsi"):
                    if b == 0:
                        raise EndOfPrefix()
                    q = (abs(a)//abs(b)) * (-1 if (a < 0) != (b < 0) else 1)
                    value = q if code == "arith.divsi" else a-b*q
                else:
                    value = {"arith.addi": operator.add, "arith.andi": operator.and_,
                             "arith.muli": operator.mul, "arith.subi": operator.sub}[code](a, b)
                bits = types[0]["bits"]
                out = [(value + (1 << (bits-1))) % (1 << bits) - (1 << (bits-1))]
            elif code == "scf.if":
                r = 0 if self.integer(values[0]) else 1
                if r < len(op["regions"]) and op["regions"][r]:
                    out = region(r)
            elif code == "scf.for":
                lo, hi, step = map(self.integer, values[:3])
                if step <= 0:
                    raise EndOfPrefix()
                out = values[3:]
                for ordinal, iv in enumerate(range(lo, hi, step)):
                    out = region(0, [iv, *out], [*iterations, ordinal])
            elif code == "scf.while":
                carried = values
                for ordinal in itertools.count():
                    rounds = [*iterations, ordinal]
                    condition, *out = region(0, carried, rounds)
                    if not self.integer(condition):
                        break
                    carried = region(1, out, rounds)
            elif code in ("memref.alloc", "memref.alloca"):
                dynamic = iter(map(self.integer, values))
                out = [local(tuple(next(dynamic) if x < 0 else x for x in types[0]["shape"]))]
            elif code == "memref.reinterpret_cast":
                view, *dynamic = values
                dynamic = iter(map(self.integer, dynamic))
                def concrete(key):
                    return tuple(next(dynamic) if x == -(1 << 63) else x for x in literals[key])
                offset, = concrete("static_offsets")
                out = [View(view.bank, view.bits, offset*view.width, concrete("static_sizes"),
                            concrete("static_strides"), view.width, view.initialized)]
            elif code == "memref.load":
                view, *indices = values
                cell, = view.spans(list(map(self.integer, indices)))
                self.emit(event, [cell])
                if types[0]["kind"] == "buffer":
                    out = [self.slots[cell[:3]]]
                else:
                    out = [Loaded(cell)]
            elif code == "memref.store":
                value, view, *indices = values
                cell, = view.spans(list(map(self.integer, indices)))
                if isinstance(value, View):
                    if cell[:3] in self.slots:
                        raise ValueError("multiple assignments to a shared descriptor affect addresses")
                    self.slots[cell[:3]] = value
                self.emit(event, writes=[cell])
            elif code in ("linalg.copy", "memref.copy"):
                src, dst = values
                if src.shape != dst.shape:
                    raise ValueError("copy shapes differ")
                self.emit(event, src.spans(), dst.spans())
            elif code == "bufferization.to_tensor":
                src, = values
                if "restrict" in props:
                    self.emit(event, claims=src.spans())
                out = [Alias(src)]
            elif code == "bufferization.materialize_in_destination":
                src, dst = values
                if src is EMPTY or "writable" not in props:
                    raise EndOfPrefix()
                self.emit(event, read_views([src]), dst.spans())
            elif code == "tensor.empty":
                out = [EMPTY]
            elif code in ("tensor.expand_shape", "tensor.collapse_shape"):
                reads = read_views(values)
                if reads:
                    self.emit(event, reads)
                out = [EMPTY if values[0] is EMPTY else TENSOR]
            elif types and types[0]["kind"] == "tensor" and code in TENSOR_COMPUTE:
                if any(isinstance(v, View) for v in values):
                    raise ValueError(f"memref effects require a rule for {code}")
                reads = read_views(values)
                if reads:
                    self.emit(event, reads)
                out = [TENSOR]
            else:
                raise ValueError(f"unsupported scheduling operation {entry}{path}: {code}")
            env.update(zip((n for n, _ in op["results"]), out, strict=True))
        return []

    def body(self, entry):
        return self.module["functions"][entry.removeprefix("@")]["regions"][0][0]

    def issues_vector_tasks(self, entry):
        visited = set()
        def contains(op):
            if op["opcode"] == "func.call":
                if "hivm.vector_function" in op["attributes"]:
                    return True
                return visit(op["properties"]["callee"])
            return any(contains(child) for r in op["regions"] for b in r for child in b["body"])
        def visit(name):
            if name in visited:
                return False
            visited.add(name)
            return any(contains(op) for op in self.body(name)["body"])
        return visit(entry)

    def build(self, instances):
        if len(instances) == 1 and self.synchronous(instances[0]["entry"], set()):
            instance, = instances
            for (_, ty), arg in zip(self.body(instance["entry"])["arguments"], instance["arguments"], strict=True):
                bind(self.module["types"][ty], arg)
            # 所有调用及子区域都在同一实例中顺序完成，任意合法前缀上的事件次序唯一。
            return {"nodes": [], "pairs": []}
        for instance in instances:
            entry = instance["entry"]
            body = self.body(entry)
            args = [bind(self.module["types"][ty], arg) for (_, ty), arg in
                    zip(body["arguments"], instance["arguments"], strict=True)]
            try:
                self.block(entry, instance["stream"], body, args, {}, [], [], [])
            except EndOfPrefix:
                continue
        pairs = []
        for i, node in enumerate(self.nodes):
            for cell in self.scalar_reads:
                if any(overlaps(cell, w) for w in node["writes"]):
                    raise ValueError("mutable data influences a scheduling address or branch")
            for cell in node["reads"]:
                if cell[3]:
                    continue
                writers = [(j, w) for j, other in enumerate(self.nodes) for w in other["writes"]
                           if overlaps(cell, w) and (other["event"]["stream"] != node["event"]["stream"] or j < i)]
                cuts = {cell[1]} | {max(cell[1], w[1]) for _, w in writers} | {w[2] for _, w in writers if w[2] < cell[2]}
                for pos in cuts:
                    node["requires"].append(sorted({j for j, w in writers if w[1] <= pos < w[2]}))
            for j in range(i):
                other = self.nodes[j]
                if any(overlaps(a, b) for a in node["claims"] for b in other["claims"]):
                    node["excludes"].append(j)
                    other["excludes"].append(i)
                if other["event"]["stream"] == node["event"]["stream"]:
                    continue
                if (any(overlaps(a, b) for a in node["writes"] for b in other["writes"]+other["reads"]) or
                    any(overlaps(a, b) for a in node["reads"] for b in other["writes"])):
                    pairs.append([j, i])
        return {"nodes": self.nodes, "pairs": pairs}

    def synchronous(self, entry, visited):
        if entry in visited:
            return True
        visited.add(entry)
        def sync(op):
            code = op["opcode"]
            if code == "func.call":
                return self.synchronous(op["properties"]["callee"], visited)
            if code in HIVM_TENSOR and (not op["results"] or
                    any(self.module["types"][t]["kind"] != "tensor" for _, t in op["results"])):
                return False
            if not (code in SYNCHRONOUS or code.startswith(("arith.", "math."))):
                return False
            return all(sync(child) for r in op["regions"] for b in r for child in b["body"])
        return all(sync(op) for op in self.body(entry)["body"])


HIVM_TENSOR = {"hivm.hir."+op for op in ("matmul","vadd","vbrc","vcast","vdiv","vexp","vln","vmul",
                                         "vreduce","vsub","vtranspose")}
TENSOR_COMPUTE = HIVM_TENSOR | {
    "linalg.broadcast","linalg.elemwise_binary","linalg.elemwise_unary","linalg.fill","linalg.matmul",
    "linalg.reduce","linalg.transpose","hfusion.arange","hfusion.bitcast","hfusion.cast","hfusion.compare",
    "hfusion.elemwise_binary","hfusion.indirect_load","hfusion.select",
}
SYNCHRONOUS = TENSOR_COMPUTE | {
    "func.return","scf.condition","scf.for","scf.if","scf.while","scf.yield",
    "affine.apply","linalg.copy","linalg.yield","linalg.index","hfusion.indirect_store","hfusion.print",
    "bufferization.materialize_in_destination","bufferization.to_tensor","memref.alloc","memref.alloca",
    "memref.atomic_rmw","memref.copy","memref.load","memref.reinterpret_cast","memref.store","memref.subview",
    "tensor.collapse_shape","tensor.empty","tensor.expand_shape","tensor.extract","tensor.extract_slice",
    "tensor.insert","tensor.insert_slice",
}


def main():
    request = json.load(sys.stdin)
    module = request["module"]
    if module["format"] == "mlir-module-1":
        inputs = prepare_inputs(request, source_signature(module))
        configuration = launch_for(dict(request, launch=dict(kind="explicit", value=inputs)), module, {})
        json.dump(dict(configuration=configuration, inputs=inputs), sys.stdout)
        return
    inputs = prepare_inputs(request, module)
    instances = inputs["instances"]
    if len({s["stream"] for s in instances}) != len(instances):
        raise ValueError("duplicate execution stream")
    schedule = Schedule(module, inputs)
    if any(schedule.issues_vector_tasks(s["entry"]) for s in instances):
        from scheduler_device import DevicePrefix
        schedule = DevicePrefix(module, inputs)
    graph = schedule.build(instances)
    graph["inputs"] = inputs
    json.dump(graph, sys.stdout, separators=(",", ":"))


if __name__ == "__main__":
    main()
