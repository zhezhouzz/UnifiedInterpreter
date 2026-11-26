import itertools
import math
import operator
import struct
from scheduler_module import Schedule, View, bind, overlaps, strides, width


class FoundPair(Exception):
    pass


def affine(expr, dims, symbols):
    if isinstance(expr, int):
        return expr
    op, *args = expr
    if op in ("d", "s"):
        return (dims if op == "d" else symbols)[args[0]]
    a, b = (affine(e, dims, symbols) for e in args)
    return {"+": operator.add, "*": operator.mul, "mod": operator.mod, "floordiv": operator.floordiv,
            "ceildiv": lambda n, d: -(-n // d)}[op](a, b)


def merged(spans):
    result = []
    for bank, lo, hi, _ in sorted(spans):
        if result and result[-1][0] == bank and lo <= result[-1][2]:
            result[-1][2] = max(hi, result[-1][2])
        else:
            result.append([bank, lo, hi])
    return result


class DevicePrefix(Schedule):
    def build(self, instances):
        self.tokens = set()
        self.memory = {}
        self.candidate = None
        self.access = None
        self.task = 0
        self.ssa_types = {}
        def index_types(name, node):
            for i, ty in node["results"]:
                self.ssa_types[name, i] = self.module["types"][ty]
            for region in node["regions"]:
                for block in region:
                    for i, ty in block["arguments"]:
                        self.ssa_types[name, i] = self.module["types"][ty]
                    for child in block["body"]:
                        index_types(name, child)
        for name, f in self.module["functions"].items():
            index_types("@"+name, f)
        # 选择允许独立推进的向量核。其他实例在有限前缀内可以保持就绪。
        self.actor = next(s for s in instances if self.issues_vector_tasks(s["entry"]))
        actor = self.actor
        entry = actor["entry"]
        body = self.body(entry)
        args = [bind(self.module["types"][t], a) for (_, t), a in
                zip(body["arguments"], actor["arguments"], strict=True)]
        try:
            self.block(entry, actor["stream"], body, args, {}, [], [], [])
        except FoundPair:
            return {"nodes": self.nodes, "pairs": [self.pair], "status": "race"}
        raise ValueError("device prefix ended without deciding the race query")

    def cell(self, view, index, ty, value=None):
        cell, = view.spans(index)
        bank, lo, hi, _ = cell
        if lo % 8 or hi % 8:
            raise ValueError("device lane access requires a byte-sized element")
        length = (hi-lo)//8
        float_format = {"f32": "<f", "f16": "<e", "f64": "<d"}.get(ty.get("name"))
        if self.access is not None:
            self.access[int(value is not None)].append(cell)
        if value is not None:
            raw = (struct.pack(float_format, value) if float_format else
                   (int(value) % (1 << (hi-lo))).to_bytes(length, "little"))
            for i, byte in enumerate(raw):
                self.memory[bank, lo//8+i] = byte
            return
        initial = self.inputs["memory"].get(bank, {}).get(str(lo), self.inputs["initial_default"])
        raw = (struct.pack(float_format, initial) if float_format else
               (int(initial) % (1 << (hi-lo))).to_bytes(length, "little"))
        data = bytes(self.memory.get((bank, lo//8+i), byte) for i, byte in enumerate(raw))
        return struct.unpack(float_format, data)[0] if float_format else int.from_bytes(data, "little", signed=True)

    def vector_task(self, event, callee, args):
        def run():
            self.access = ([], [])
            self.block(callee, event["stream"], self.body(callee), args, {}, [], [],
                       [*event["calls"], {k:event[k] for k in ("entry", "path", "iterations")}])
            reads, writes = map(merged, self.access)
            self.access = None
            return reads, writes
        initial = self.memory.copy()
        reads, writes = run()
        submit = len(self.nodes)
        base = dict(event, task=self.task, pipe="PIPE_V", callee=callee)
        self.task += 1
        self.emit(dict(base, phase="submit"))
        self.emit(dict(base, phase="complete", reads=reads, writes=writes))
        if self.candidate is not None:
            previous, old_run, old_memory, rr, ww = self.candidate
            if (any(overlaps(a, b) for a in writes for b in rr+ww) or
                any(overlaps(a, b) for a in reads for b in ww)):
                # 重新执行反序，确保内存的变化没有改变端点地址或控制流。
                self.memory = old_memory.copy()
                if run() != (reads, writes) or old_run() != (rr, ww):
                    raise ValueError("vector task footprints depend on completion order")
                self.nodes[submit]["requires"] = [[previous]]
                self.nodes[previous+1]["requires"].append([submit])
                self.pair = [previous+1, submit+1]
                raise FoundPair()
        self.candidate = submit, run, initial, reads, writes

    def operation(self, op, types, values, event):
        code = op["opcode"]
        lit = op.get("literals", {})
        stream = self.actor["stream"]
        if code == "affine.apply":
            n, exprs = lit["map"]
            return [affine(e, values[:n], values[n:]) for e in exprs]
        if code in ("arith.minsi", "arith.maxsi"):
            return [(min if code == "arith.minsi" else max)(values)]
        if code in ("arith.trunci", "arith.remui"):
            bits = types[0]["bits"]
            u = values[0] % (1 << bits)
            if code == "arith.remui":
                u %= values[1] % (1 << bits)
            return [u-(1 << bits) if u >= (1 << (bits-1)) else u]
        if code in ("hivm.hir.get_block_idx", "hivm.hir.get_sub_block_idx"):
            return [self.actor["block" if code.endswith("get_block_idx") else "subblock"]]
        if code == "hivm.hir.pointer_cast":
            ty, = types
            space = ty["space"]
            shape = tuple(ty["shape"])
            owner = stream if space == "ub" else self.actor["block"]
            return [View(f"{space}:{owner}", self.inputs["local_storage_bits"][space], values[0]*8,
                         shape, strides(shape), width(ty["element"]), True)]
        if code == "memref.expand_shape":
            v, = values
            shape = tuple(types[0]["shape"])
            if v.steps != strides(v.shape) or math.prod(shape) != math.prod(v.shape):
                raise ValueError("expected contiguous expand_shape")
            return [View(v.bank, v.bits, v.offset, shape, strides(shape), v.width, v.initialized)]
        if code == "memref.subview":
            v, *args = values
            dynamic = iter(args)
            def concrete(key):
                return [next(dynamic) if n == -(1 << 63) else n for n in lit[key]]
            offsets, sizes, steps = map(concrete, ("static_offsets","static_sizes","static_strides"))
            if any(o < 0 or (n and o+(n-1)*s >= bound) for o,n,s,bound in zip(offsets,sizes,steps,v.shape,strict=True)):
                raise ValueError("subview exceeds its source")
            target = types[0]["shape"]
            keep = next(ix for ix in itertools.combinations(range(len(sizes)), len(target))
                        if all(a == -1 or a == sizes[i] for a,i in zip(target,ix))
                        and all(n == 1 for i,n in enumerate(sizes) if i not in ix))
            off = v.offset + sum(o*s for o,s in zip(offsets,v.steps))*v.width
            return [View(v.bank,v.bits,off,tuple(sizes[i] for i in keep),
                         tuple(steps[i]*v.steps[i] for i in keep),v.width,v.initialized)]
        if code == "func.call" and "hivm.vector_function" in op["attributes"]:
            self.vector_task(event, op["properties"]["callee"], values)
            return []
        if code in ("memref.load", "memref.store"):
            load = code == "memref.load"
            v, *indices = values if load else values[1:]
            cell, = v.spans(indices)
            ty = types[0] if load else self.ssa_types[event["entry"], op["operands"][0]]
            if self.access is None:
                self.candidate = None
                self.emit(dict(event, **{("reads" if load else "writes"): [list(cell[:3])]}))
            if load:
                return [self.cell(v, indices, ty)]
            self.cell(v, indices, ty, values[0])
            return []
        if code == "hivm.hir.set_ctrl":
            self.candidate = None
            self.emit(event)
            return []
        if code in ("hivm.hir.set_flag","hivm.hir.wait_flag","hivm.hir.sync_block_set","hivm.hir.sync_block_wait"):
            cross = "sync_block" in code
            send = code.endswith(("set", "set_flag"))
            src, dst = (lit["tpipe"], lit["pipe"]) if cross else (lit["set_pipe"],lit["wait_pipe"])
            flag = int(lit["static_flag_id"] if cross else lit["static_event_id"].removeprefix("EVENT_ID"))
            peers = ([s["stream"] for s in self.inputs["instances"] if s["block"] == self.actor["block"]
                      and s["core"] != self.actor["core"]] if cross else [stream])
            keys = {(stream if send else p, p if send else stream, src,dst,flag) for p in peers}
            if not keys or (keys & self.tokens if send else keys - self.tokens):
                raise ValueError("flag completion disabled in this prefix")
            self.tokens = self.tokens | keys if send else self.tokens - keys
            self.candidate = None
            base = dict(event, task=self.task, pipe=src if send else dst)
            self.task += 1
            for phase in ("submit","complete"):
                self.emit(dict(base, phase=phase))
            return []
        if not code.startswith("ave.hir."):
            return None
        if self.access is None:
            raise ValueError("vector operation outside a vector task")
        lanes = math.prod(types[0]["shape"]) if types else None
        if code == "ave.hir.pge":
            pat = lit["pattern"]
            count = lanes if pat == "ALL" else int(pat.removeprefix("VL"))
            return [[i < count for i in range(lanes)]]
        if code == "ave.hir.vci":
            step = {"INCREASE":1,"DECREASE":-1}[lit["increase_p"]]
            return [[values[0]+step*i for i in range(lanes)]]
        if code in ("ave.hir.broadcast","ave.hir.scalar_broadcast"):
            return [[values[0] if len(values)==1 or values[1][i] else 0 for i in range(lanes)]]
        if code in ("ave.hir.vmuls","ave.hir.vadd"):
            a,b,mask = values
            return [[(a[i]*b if code.endswith("vmuls") else a[i]+b[i]) if mask[i] else 0 for i in range(lanes)]]
        if code == "ave.hir.vload":
            v,index = values
            step = {"NORM":1, "BRC_B32":0}[lit["pattern"]]
            return [[self.cell(v,[index+i*step],types[0]["element"]) for i in range(lanes)]]
        if code == "ave.hir.masked_store":
            v,index,mask,data = values
            pat = lit["pattern"]
            count = {"ONEPT_B32":1,"NORM_B32":len(data),"NORM_B16":len(data)}[pat]
            ty = self.ssa_types[event["entry"], op["operands"][0]]["element"]
            for i in range(count):
                if mask[i]:
                    self.cell(v,[index+i],ty,data[i])
            return []
        raise ValueError(f"unsupported vector operation {code}")
