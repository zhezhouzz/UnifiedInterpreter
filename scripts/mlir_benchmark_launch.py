import math
import struct

from scheduler_inputs import prepare_inputs


def source_signature(ast):
    def convert(name):
        ty = ast["types"][name]
        if ty["kind"] in ("memref", "tensor", "vector"):
            return dict(kind="buffer", shape=[-1 if n is None else n for n in ty["shape"]],
                        element=convert(ty["element"]))
        return ty if ty["kind"] == "integer" else dict(kind="other", name=name)
    return dict(functions=ast["functions"], types={ty:convert(ty) for ty in ast["types"]})


def vector_memory(config):
    length, dim, group, kv = (config[k] for k in ("length","dimension","group","kv_heads"))
    pages, heads = (length+127)//128, group*kv
    return {"gm2":[1+(t*3+h*5+k)%7 for t in range(length) for h in range(heads) for k in range(dim)],
            "gm3":[1+(pages-1-p+t*2+h*3+k*5)%11 for p in range(pages) for t in range(128)
                   for h in range(kv) for k in range(dim)], "gm4":list(reversed(range(pages))),
            "gm5":[0], "gm6":[(length-1)//32], "gm7":[length], "gm8":[length],
            "gm9":[12345]*(length*heads*pages)}


def buffer_argument(raw, ty, elem, inputs, vector):
    width = max(1,(elem.get("bits",64)+7)//8)
    if "descriptor_slot" in raw:
        raw = dict(storage=raw["descriptor_slot"], bytes=width)
    bank, size = raw["storage"], raw["bytes"]
    shape = raw.get("shape", ty["shape"])
    if None in shape:
        if shape.count(None) != 1:
            raise ValueError("launch requires an explicit multidimensional shape")
        known = math.prod(n for n in shape if n is not None)
        shape = [size//(width*known) if n is None else n for n in shape]
    arg = dict(storage=bank,bytes=size,shape=shape)
    for key in ("offset","strides"):
        if key in raw:
            arg[key] = raw[key]
    if "offset_bits" in raw and "offset" not in raw:
        if raw["offset_bits"]%8:
            raise ValueError("unaligned buffer base")
        arg["base_bytes"] = raw["offset_bits"]//8
    cells = {c["element"]:c["value"] for c in inputs.get("initial_cells",[]) if c["storage"]==bank}
    for bit,value in inputs.get("memory",{}).get(bank,{}).items():
        if int(bit)%(width*8):
            raise ValueError("unaligned initial element")
        cells[int(bit)//(8*width)] = value
    initial = inputs.get("initial") or {}
    default = initial.get(bank,0)
    if bank in vector:
        arg["initial"] = vector[bank]
    elif cells or default:
        extent = size//width if default else max(cells)+1
        arg["initial"] = [cells.get(i,i if default=="identity" else default) for i in range(extent)]
    for key,value in initial.items():
        if key.startswith(bank+":") and key[len(bank)+1:].isdigit():
            offset = int(key[len(bank)+1:])//width
            count = min(inputs["tile"],size//width-offset)
            if count>0:
                data = arg.setdefault("initial",[0]*(size//width))
                data[offset:offset+count] = [value]*count
    return arg


def launch_for(request, ast, config):
    module = source_signature(ast)
    spec,stage,name = request["launch"],request["stage"],request["name"]
    vector = {}
    if spec["kind"]=="vectorlayout":
        vector = vector_memory(spec["config"])
        instances = []
        for entry,function in module["functions"].items():
            if "hacc.entry" not in function["attributes"] and len(module["functions"])!=1:
                continue
            core = function["attributes"].get("hivm.func_core_type")
            args = []
            for i,(_,ty) in enumerate(function["regions"][0][0]["arguments"]):
                if i>=28:
                    args.append(0)
                    continue
                value = spec["bindings"][f"arg{i}"]
                if "bank" in value:
                    element = ast["types"][ast["types"][ty]["element"]]
                    args.append(dict(storage=value["bank"],bytes=math.prod(value["shape"])*max(1,element["bits"]//8)))
                else:
                    value_bits = int(value["lanes"][0])
                    args.append(struct.unpack("<f",struct.pack("<I",value_bits))[0] if value["type"]=="f32" else value_bits)
            cube = core=="#hivm.func_core_type<AIC>"
            for sub in range(2 if stage=="hivm" and not cube else 1):
                instances.append(dict(stream=(sub+1 if stage=="hivm" and not cube else 0),
                                      entry="@"+entry, arguments=args, core="cube" if cube else "vector", subblock=sub))
        inputs = dict(instances=sorted(instances,key=lambda s:s["stream"]))
    else:
        inputs = prepare_inputs(request,module)
    coords = {x["stream"]:x for x in inputs.get("coordinates",[])}
    streams = []
    for s in inputs["instances"]:
        c = {**coords.get(s["stream"],{}),**s}
        args = []
        signature = ast["functions"][s["entry"].removeprefix("@")]["regions"][0][0]["arguments"]
        for (_,t),raw in zip(signature,s["arguments"],strict=True):
            ty = ast["types"][t]
            args.append(buffer_argument(raw,ty,ast["types"][ty["element"]],inputs,vector) if isinstance(raw,dict) else raw)
        stream = dict(entry=s["entry"],arguments=args,block=c.get("block",0),subblock=c.get("subblock",0))
        core = c.get("kind",c.get("core"))
        if core:
            stream["core"] = "cube" if core in ("AIC","cube") else "vector"
        streams.append(stream)
    ids = [s["stream"] for s in inputs["instances"]]
    edges = []
    for i,a in enumerate(streams):
        for j,b in enumerate(streams):
            targets = config.get("targets",{}).get(str(ids[i]))
            allowed = a.get("core")!=b.get("core") if targets is None else ids[j] in targets
            if name.startswith(("fixture/","regression/")):
                allowed = ids[j]==2 if name in ("regression/single-broadcast","regression/two-broadcasts") else True
            if i!=j and allowed:
                edges.append([i,j])
    return dict(stage=stage,streams=streams,edges=edges,capacity=config.get("capacity",1))
