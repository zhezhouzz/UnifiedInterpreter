"""Check scoped Core SSA, command signatures, region exits and configured queues."""
import re

DATA = {"AIC": {"M", "FIX", "MTE1", "MTE2"}, "AIV": {"V", "MTE2", "MTE3"}}

def category(t):
    if t.startswith("memref<"):
        return "view"
    if t == "i1":
        return "bool"
    if t=="index" or re.fullmatch(r"[su]?i[0-9]+",t):
        return "int"
    if re.fullmatch(r"(?:bf|f)[0-9]+",t):
        return "float"
    raise ValueError("no Core category for "+t)

def require(condition,message):
    if not condition:
        raise ValueError(message)

def check(program,case):
    ratio=case["core_ratio"]
    require(ratio is not None,"source does not specify an active-stream configuration")
    launch=case.get("execution",{})
    kinds=dict(zip(launch.get("streams",[]),launch.get("kinds",["AIV"]*len(launch.get("streams",[])))))
    def block(commands, env, terminator, kind):
        require(commands and commands[-1]["cmd"]==terminator,"missing "+terminator)
        pipes=DATA[kind]
        for i,c in enumerate(commands):
            op=c["cmd"]
            args=[env[v] for v in c["args"]]
            if op in ("return","end"):
                require(i==len(commands)-1,"early region terminator")
            elif op=="issue":
                require(c["p"] in pipes,"DPS dispatched to inactive pipe")
                if c["fn"] in ("nd2nz","mmadL1","fixpipe"):
                    require(kind=="AIC","cube operation requires an AIC")
                for k in [c["write_operand"],*c["read_operands"]]:
                    require(args[k]=="view","DPS view required")
            elif op=="pipebarrier":
                require(c["p"]=="ALL" or c["p"] in pipes,"invalid barrier pipe")
            elif op in ("setflag","waitflag","syncblockset","syncblockwait"):
                if "event_operand" in c:
                    require(args==["int"],"dynamic event conversion requires an integer")
                else:
                    require(isinstance(c["event"],int) and c["event"]>=0,"invalid event")
                if op.startswith("syncblock"):
                    require(ratio in ("1:1","1:2"),"cross-core peer inactive")
                    peer="AIV" if kind=="AIC" else "AIC"
                    src,dst=(kind,peer) if op=="syncblockset" else (peer,kind)
                    require(c["p"] in DATA[src] and c["q"] in DATA[dst]|{"S"},"invalid block endpoints")
                else:
                    local=pipes|({"S"} if case.get("semantics_profile")=="local-scalar-memory" else set())
                    require(c["p"] in local and c["q"] in local,"inactive local sync endpoint")
            elif op=="if":
                require(args==["bool"] and len(c["bodies"])==2,"expected boolean branch")
            elif op=="for":
                require(args==["int"]*3 and len(c["bodies"])==1,"incompatible loop bounds")
            elif op=="alloc":
                require(len(c["types"])==1 and category(c["types"][0])=="view","alloc result")
            elif op=="scalarstore":
                require(args[1:]==["view","int"] and case.get("semantics_profile")=="local-scalar-memory","scalar store signature")
            elif op!="scalar":
                raise ValueError("unknown command "+op)
            for body,bindings in zip(c.get("bodies",[]),c.get("bindings",[])):
                local=dict(env)
                local.update({p["id"]:category(p["type"]) for p in bindings[0]})
                block(body,local,"end",kind)
            require(len(c["results"])==len(c["types"]),"result arity")
            for v,t in zip(c["results"],c["types"]):
                require(v not in env,"duplicate SSA definition")
                env[v]=category(t)
    for name,stream in program.items():
        kind=kinds.get(name) or {"1:0":"AIC","0:1":"AIV"}.get(ratio)
        attr=stream["core_kind"]
        if kind is None and attr:
            kind=attr.partition("<")[2].rstrip(">")
        require(kind in DATA,"entry has no concrete AIC or AIV assignment")
        if attr in ("#hivm.func_core_type<AIC>","#hivm.func_core_type<AIV>"):
            require(attr==f"#hivm.func_core_type<{kind}>","entry kind disagrees with launch")
        block(stream["body"],{p["id"]:category(p["type"]) for p in stream["params"]},"return",kind)
