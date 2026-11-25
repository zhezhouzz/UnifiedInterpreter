"""Specialize scalar-only control to a concrete launch, retaining one step per command.
The executable memory instance represents a uniform contiguous tile by one value.
"""
def scalar(c, a, stream, tile, subblock):
    fn,attrs=c["fn"],c["attrs"]
    if fn=="arith.constant":
        literal=attrs["value"].split()[0]
        if literal in ("true","false"):
            return literal=="true"
        return float(literal) if "." in literal else int(literal)
    if fn=="hivm.hir.pointer_cast":
        space=next((t for t in ("ub","cc") if "<"+t+">" in c["types"][0]),None)
        if not space:
            raise ValueError("unsupported concrete pointer space")
        return f"{space}:{stream}:{a[0]}"
    if fn=="hivm.hir.get_block_idx":
        return 0
    if fn=="hivm.hir.get_sub_block_idx":
        return subblock
    if fn=="arith.muli":
        return a[0]*a[1]
    if fn=="arith.remsi" and min(a)>=0:
        return a[0]%a[1]
    if fn in ("arith.trunci","arith.index_cast") and 0<=a[0]<2**31:
        return a[0]
    if fn=="arith.cmpi" and attrs["predicate"]=="0 : i64":
        return a[0]==a[1]
    if fn=="arith.select":
        return a[1] if a[0] else a[2]
    if fn=="arith.cmpi" and attrs["predicate"]=="2 : i64":
        return a[0]<a[1]
    if fn=="affine.max" and attrs["map"]=="affine_map<()[s0, s1] -> (s1, s0)>":
        return max(a)
    if fn=="affine.min" and attrs["map"]=="affine_map<()[s0, s1] -> (s1 + 256, s0)>":
        return min(a[1]+256,a[0])
    if fn=="affine.apply" and attrs["map"]=="affine_map<()[s0, s1] -> (s0 - s1)>":
        return a[0]-a[1]
    if fn in ("memref.reinterpret_cast","memref.subview"):
        if attrs["static_strides"]=="array<i64: 1>" and (
            fn=="memref.reinterpret_cast" and a[1]==0 and attrs["static_sizes"]==f"array<i64: {tile}>"
            or fn=="memref.subview" and a[1]==tile and attrs["static_offsets"]=="array<i64: 0>"):
            return a[0]
        raise ValueError("concrete oracle requires a complete contiguous tile")
    if fn in ("annotation.mark","hivm.hir.set_mask_norm"):
        return None  # Logical launch annotation and normal-mask launch configuration.
    raise ValueError("unsupported concrete scalar "+fn)

def specialize(stream, case, s):
    trace=[]
    kinds=case.get("kinds",["AIV"]*len(case["streams"]))
    subblock=kinds[:s].count("AIV") if kinds[s]=="AIV" else 0
    env={p["id"]:case.get("arguments",{}).get(str(i),f"gm:{i}")
         for i,p in enumerate(stream["params"])}
    def visit(body):
        for c in body:
            op=c["cmd"]
            a=[env[v] for v in c["args"]]
            if op in ("end","return"):
                continue
            if op=="for":
                lo,hi,step=a
                if not step:
                    raise ValueError("zero step")
                for k in range(lo,hi,step):
                    trace.append({"cmd":"control","label":"for-step"})
                    env[c["bindings"][0][0][0]["id"]]=k
                    visit(c["bodies"][0])
                trace.append({"cmd":"control","label":"for-done"})
            elif op=="if":
                trace.append({"cmd":"control","label":"branch "+str(a[0])})
                visit(c["bodies"][0 if a[0] else 1])
            elif op=="scalar":
                value=scalar(c,a,s,case.get("tile",32),subblock)
                if c["results"]:
                    env[c["results"][0]]=value
                trace.append({"cmd":"control","label":c["fn"]})
            elif "event_operand" in c:
                event=env[c["event_operand"]]
                if not isinstance(event,int) or event<0:
                    raise ValueError("event id must be a nonnegative integer")
                trace.append(dict(c,event=event))
            elif op=="alloc":
                env[c["results"][0]]=f"alloc:{s}:{len(trace)}:{c['space']}"
                trace.append({"cmd":"control","label":"alloc "+c["space"]})
            elif op=="scalarstore":
                value,dst,offset=a
                if case.get("tile")!=1 or offset!=0:
                    raise ValueError("scalar store requires one lane at offset zero")
                trace.append({"cmd":op,"dst":dst,"value":value})
            elif op=="issue":
                trace.append(dict(c,reads=[a[k] for k in c["read_operands"]],dst=a[c["write_operand"]]))
            else:
                trace.append(c)
    visit(stream["body"])
    for fn,expected in case.get("read_sequence",{}).items():
        operations=[c for c in trace if c.get("fn")==fn]
        if len(operations)!=len(expected):
            raise ValueError("oracle length differs from dynamic issue count")
        for c,value in zip(operations,expected):
            c["expected_read"]=value
    return trace
