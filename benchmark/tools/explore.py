"""Finite litmus instantiation. All 32 lanes have identical initial data and operations."""
from collections import deque
from .concrete import specialize

def explore(program, case):
    streams = [specialize(program[n],case,i) for i,n in enumerate(case["streams"])]
    # Positions refer to dynamic instances after specializing scalar control.
    kinds=case.get("kinds",["AIV"]*len(streams))
    initial = (tuple(0 for _ in streams), (), frozenset(), ())
    todo = deque([(initial, ())])
    seen = {initial}
    while todo:
        state, trace = todo.popleft()
        if isinstance(state,str):
            return state,trace,len(seen),trace[-1]
        pcs,pending,tokens,memory=state
        mem=dict(memory)
        def step(label, *, pc=pcs, queue=pending, flags=tokens, cells=mem):
            state = (pc, queue, flags, tuple(sorted(cells.items())))
            if state not in seen:
                seen.add(state)
                todo.append((state, trace + (label,)))
        advanced = False
        def key(s, c):
            return (c["cmd"].startswith("syncblock"),s,c["p"],c["q"],c["event"])
        def at(item):
            s,i,r = item
            return streams[s][i]
        for s, stream in enumerate(streams):
            i = pcs[s]
            if i == len(stream):
                continue
            c = stream[i]
            op = c["cmd"]
            nextpc = pcs[:s]+(i+1,)+pcs[s+1:]
            label = f"{s}:{i} {c.get('label',op)}"
            if op=="scalarstore":
                step(label,pc=nextpc,cells={**mem,c["dst"]:c["value"]})
            elif op=="setflag" and c["p"]=="S":
                k=key(s,c)+(1,)
                if k in tokens:
                    continue
                step(label,pc=nextpc,flags=tokens|{k})
            elif op in ("syncblockwait","waitflag") and c["q"]=="S":
                k = key(s,c)
                count=sum(slot[:-1]==k for slot in tokens)
                if not count:
                    continue
                step(label, pc=nextpc, flags=tokens-{k+(count,)})
            elif op in ("issue","setflag","waitflag","syncblockset","syncblockwait"):
                step(label, pc=nextpc, queue=pending+((s,i,c["q"] if op in ("waitflag","syncblockwait") else c["p"]),))
            elif op == "pipebarrier":
                kind=kinds[s]
                data_pipes=("MTE2","V","MTE3") if kind=="AIV" else ("MTE1","MTE2","M","FIX")
                pipes=data_pipes if c["p"]=="ALL" else (c["p"],)
                step(label,pc=nextpc,queue=pending+tuple((s,i,p) for p in pipes))
            elif op=="control":
                step(label, pc=nextpc)
            else:
                raise ValueError("unimplemented executable command "+op)
            advanced = True
        for j,(s,i,r) in enumerate(pending):
            c = at((s,i,r))
            op = c["cmd"]
            before = [at(item)["cmd"] for item in pending[:j] if item[0]==s and item[2]==r]
            if any(x in ("waitflag","syncblockwait","pipebarrier") for x in before):
                continue
            queue = pending[:j]+pending[j+1:]
            label=f"{s}:{i} {op}.done[{r}]"
            if op == "issue":
                src=c["reads"][0]
                dst=c["dst"]
                operands=[mem.get(v,case["initial"].get(v,"uninit")) for v in c["reads"]]
                value=operands[0]
                if c["fn"]=="indirect_atomic_add":
                    old,offsets,increment,mask=operands
                    if offsets!="identity" or mask!=1:
                        raise ValueError("oracle requires one active lane per distinct GM address")
                    total="uninit" if "uninit" in (old,increment) else old+increment
                    step(label,queue=queue,cells={**mem,src:total,dst:old})
                    advanced=True
                    continue
                if c["fn"]=="vadd":
                    value="uninit" if "uninit" in operands else sum(operands)
                elif c["fn"]=="vabs" and value!="uninit":
                    value=abs(value)
                elif c["fn"] not in ("load","store","vabs","fixpipe"):
                    raise ValueError("unimplemented executable DPS "+c["fn"])
                if operands[0] != c.get("expected_read",case.get("reads",{}).get(c["fn"],operands[0])):
                    todo.append(("race",trace+(label+f" read {src}={operands[0]}",)))
                    advanced=True
                    continue
                step(label+f" {dst}={value}",queue=queue,cells={**mem,dst:value})
            elif op=="pipebarrier":
                if before:
                    continue
                step(label,queue=queue)
            elif op in ("setflag","syncblockset"):
                if before:
                    continue
                targets=case.get("targets",{}).get(str(s),[t for t,kind in enumerate(kinds) if kind!=kinds[s]])
                keys={key(s,c)} if op=="setflag" else {key(t,c) for t in targets}
                slots={k+(1+sum(slot[:-1]==k for slot in tokens),) for k in keys}
                if any(slot[-1]>case.get("capacity",1) for slot in slots):
                    if case.get("check_overlap") or "capacity" in case:
                        return "protocol_violation",trace,len(seen),f"{s}:{i} {op} at queue head, next slot {sorted(slots)}"
                    continue
                step(label,queue=queue,flags=tokens|slots)
            else:
                k = key(s,c)+(1,)
                if k not in tokens:
                    continue
                step(label,queue=queue,flags=tokens-{k})
            advanced=True
        if not advanced:
            if pending or any(i<len(st) for i,st in zip(pcs,streams)):
                return "deadlock",trace,len(seen),f"blocked PCs {pcs}, queues {pending}, live tokens {sorted(tokens)}"
            if any(mem.get(k,case["initial"].get(k,"uninit"))!=v for k,v in case.get("outputs",{}).items()):
                return "wrong_value",trace,len(seen),{k:{"expected":v,"actual":mem.get(k,case["initial"].get(k,"uninit"))} for k,v in case["outputs"].items()}
            if tokens:
                return "protocol_violation",trace,len(seen),f"residual tokens {sorted(tokens)}"
    return "safe",(),len(seen),"reachable state space exhausted"
