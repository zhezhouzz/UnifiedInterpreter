"""Whole-entry translation from the native dialect reader's SSA tree."""
import json
import re
import subprocess

PIPES = dict(load="MTE2", store="MTE3", nd2nz="MTE2", fixpipe="FIX", **{
    op: "V" for op in "vabs vadd vsub vmul vcast vbrc".split()})
SCALARS = {"arith." + op for op in
           "constant addi subi muli remsi remui divsi divui cmpi select index_cast extsi extui trunci".split()}
SCALARS.update({"hivm.hir." + op for op in ("get_sub_block_idx", "get_block_idx", "pointer_cast")})
SCALARS.update({"memref.subview", "memref.cast", "memref.reinterpret_cast", "memref.dim"})

def read(reader, path):
    return json.loads(subprocess.check_output([reader], input=path.read_bytes()))

def functions(module):
    return {json.loads(n["attrs"]["sym_name"]): n for n in module["regions"][0][0]
            if n["op"] == "func.func"}

def allocation(n):
    ty = n["resultTypes"][0]
    space = re.search(r"#hivm.address_space<(\w+)>", ty)
    if not space:
        raise ValueError("allocation space unspecified")
    return {"cmd": "alloc", "space": space[1]}

def instruction(n):
    op, a = n["op"], n["attrs"]
    short = op.removeprefix("hivm.hir.")
    def pipe(field):
        return a[field].removeprefix("#hivm.pipe<PIPE_").removesuffix(">")
    if op == "hivm.hir.set_mask_norm" or (op == "annotation.mark" and "logical_block_num" in a):
        return {"cmd": "scalar", "fn": op}
    if op in SCALARS or op in ("affine.apply", "affine.min", "affine.max"):
        return {"cmd": "scalar", "fn": op}
    if op in ("memref.alloc", "memref.alloca"):
        return allocation(n)
    if short == "pipe_barrier":
        return {"cmd": "pipebarrier", "p": pipe("pipe")}
    if short in ("sync_block_set", "sync_block_wait", "set_flag", "wait_flag"):
        cross = short.startswith("sync_block")
        field = "static_flag_id" if cross else "static_event_id"
        if field not in a and not cross and len(n["args"])==1:
            return {"cmd":short.replace("_",""),"p":pipe("set_pipe"),"q":pipe("wait_pipe"),
                    "event_operand":n["args"][0]}
        if field not in a or n["args"]:
            raise ValueError("dynamic cross-core event or FFTS operand needs a binding")
        event = int(a[field].split()[0] if cross else a[field].split("EVENT_ID")[1][:-1])
        return {"cmd": short.replace("_", ""), "p": pipe("tpipe" if cross else "set_pipe"),
                "q": pipe("pipe" if cross else "wait_pipe"), "event": event}
    if short == "custom" and a.get("symbol") == '"__builtin_indirect_atomic"':
        if (a.get("extra_attr"),a.get("gm_addr_args_indices"),a.get("operandSegmentSizes"),a.get("hivm.pipe")) != (
                '"operate=add"',"array<i32: 0>","array<i32: 4, 1, 0>","#hivm.pipe<PIPE_V>"):
            raise ValueError("unsupported indirect atomic signature")
        return {"cmd":"issue","p":"V","fn":"indirect_atomic_add","read_operands":[0,1,2,3],
                "write_operand":4,"gm_rmw_operand":0}
    if short in PIPES or short == "mmadL1":
        if short == "mmadL1" and len(n["args"]) > 7:
            raise ValueError("mmadL1 sync_related_args require internal MTE1/M protocol")
        if n["results"] or any("tensor<" in t for t in n["types"]):
            raise ValueError("requires bufferization")
        if any("unit" in k.lower() and "flag" in k.lower() for k in a) or (
                "atomic_kind" in a and not a["atomic_kind"].endswith("<none>")):
            raise ValueError("requires unit-flag or atomic semantics")
        dest = 6 if short == "mmadL1" else (2 if short in ("vadd","vsub","vmul") else 1)
        if dest >= len(n["types"]) or not n["types"][dest].startswith("memref<"):
            raise ValueError("unknown destination signature")
        pipe_name = "M" if short == "mmadL1" else PIPES[short]
        if short == "vbrc":
            target=n["types"][dest]
            if "<cbuf>" in target or "<l1>" in target:
                pipe_name="MTE2"
            elif "<ub>" not in target:
                raise ValueError("vbrc requires a UB or L1 destination for pipe dispatch")
        return {"cmd": "issue", "p": pipe_name, "fn": short, "write_operand": dest,
                "read_operands": [i for i,t in enumerate(n["types"]) if t.startswith("memref<")
                                  and (i != dest or short == "mmadL1")]}
    if op in ("scf.if","scf.for"):
        if op == "scf.for" and len(n["args"]) != 3 or n["results"]:
            raise ValueError("loop-carried values or yielded joins need bindings")
        return {"cmd": op[4:]}
    if op == "func.return" or (op=="scf.yield" and not n["args"]):
        return {"cmd": "return" if op == "func.return" else "end"}
    raise ValueError("missing Core interpretation")

def invariant_view_loop(n):
    """The carried view is unused inside B; every iteration yields the same outer view.
    After a zero-trip loop the result is init, after any positive trip it is yielded.
    """
    region = n["regions"][0]
    if len(region) != 1 or len(n["args"]) != 4 or len(n["results"]) != 1:
        raise ValueError("general loop carries require a Core state representation")
    body = region[0]
    iv, carried = n["regionArgs"][0][0]
    term = body[-1]
    outer = n["args"][3]
    if term["op"] != "scf.yield" or len(term["args"]) != 1 or not carried["type"].startswith("memref<"):
        raise ValueError("expected one invariant yielded view")
    yielded = term["args"][0]
    def walk(nodes):
        for child in nodes:
            yield child
            for r in child["regions"]:
                for b in r:
                    yield from walk(b)
    nested = list(walk(body[:-1]))
    local = {v for child in nested for v in child["results"]}
    if yielded in local or yielded in (iv["id"],carried["id"]) or any(carried["id"] in child["args"] for child in nested):
        raise ValueError("iteration-dependent carried view")
    if "unsignedCmp" in n["attrs"]:
        raise ValueError("unsigned loop comparison")
    loop = dict(n,args=n["args"][:3],results=[],resultTypes=[],regionArgs=[[[iv]]],
                regions=[[body[:-1]+[dict(term,args=[])]]])
    guard = "nonempty_"+str(n["results"][0])
    cond = dict(n,op="arith.cmpi",args=n["args"][:2],results=[guard],resultTypes=["i1"],
                attrs={"predicate":"2 : i64"},regions=[],regionArgs=[])
    select = dict(n,op="arith.select",args=[guard,yielded,outer],regions=[],regionArgs=[],attrs={})
    return [loop,cond,select]

def elaborate(module, entries, profile="opsem"):
    funcs, errors, streams = functions(module), [], {}
    for name in entries:
        def block(nodes):
            commands = []
            for n in nodes:
                try:
                    if n["op"] == "scf.for" and n["results"]:
                        commands.extend(block(invariant_view_loop(n)))
                        continue
                    if profile=="local-scalar-memory" and n["op"]=="memref.store" and len(n["args"])==3:
                        cmd={"cmd":"scalarstore"}
                    else:
                        cmd = instruction(n)
                    if cmd["cmd"] in ("setflag","waitflag") and "S" in (cmd["p"],cmd["q"]) and profile!="local-scalar-memory":
                        raise ValueError("intra-stream scalar endpoint requires local-scalar-memory profile")
                    if any(len(r) != 1 and not (cmd["cmd"] == "if" and k == 1 and not r) for k,r in enumerate(n["regions"])):
                        raise ValueError("multi-block control flow")
                    if n["regions"] and cmd["cmd"] not in ("for","if"):
                        raise ValueError("unexpected nested region")
                    cmd.update(args=n["args"], results=n["results"], types=n["resultTypes"], attrs=n["attrs"])
                    if n["regions"]:
                        cmd.update(bodies=[block(r[0]) if r else [{"cmd":"end","args":[],"results":[],"types":[]}] for r in n["regions"]], bindings=[r or [[]] for r in n["regionArgs"]])
                    commands.append(cmd)
                except (KeyError, ValueError, IndexError) as ex:
                    errors.append(dict(function=name, location=n["loc"], op=n["op"], reason=str(ex)))
            return commands
        f = funcs.get(name)
        if not f or len(f["regions"][0]) != 1:
            errors.append(dict(function=name, location=f["loc"] if f else "module", op="func.func",
                               reason="missing body or multi-block entry"))
            continue
        streams[name] = dict(params=f["regionArgs"][0][0], body=block(f["regions"][0][0]),
                             core_kind=f["attrs"].get("hivm.func_core_type"))
    return (None, errors) if errors else (streams, [])
