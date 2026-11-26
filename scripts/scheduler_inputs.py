import math
import struct


def prepare_inputs(request, module):
    launch = request["launch"]
    kind = launch["kind"]
    if kind == "explicit":
        return launch["value"]
    def sig(entry):
        block = module["functions"][entry.removeprefix("@")]["regions"][0][0]
        return [module["types"][ty] for _, ty in block["arguments"]]
    def buffer(bank, size):
        return {"storage": bank, "bytes": size}
    if kind == "tensor":
        instances = launch["instances"]
        for stream in instances:
            for ty, value in zip(sig(stream["entry"]), stream["arguments"], strict=True):
                if isinstance(value, dict):
                    value["bytes"] = value["elements"] * element_bytes(ty)
                    value["offset_bits"] = value["offset"] * element_bytes(ty)*8
        return {"instances": instances, "initial_default": 0}
    if kind == "vectorlayout":
        entry, = module["functions"]
        args = []
        for i, ty in enumerate(sig(entry)):
            if i >= 28:
                args.append(0)
                continue
            value = launch["bindings"][f"arg{i}"]
            if "bank" in value:
                args.append(buffer(value["bank"], math.prod(value["shape"])*element_bytes(ty)))
            else:
                raw = int(value["lanes"][0])
                args.append(struct.unpack("<f", struct.pack("<I", raw))[0] if value["type"] == "f32" else raw)
        return {"config": launch["config"], "initialization": "vectorlayout", "grid": [1, 1, 1],
                "instances": [{"stream": 0, "entry": "@"+entry, "arguments": args}]}
    if kind == "scene1":
        from scheduler_scene import scene_inputs
        return scene_inputs(request, module)
    inp = launch["inputs"]
    instances = []
    for stream in launch["entries"]:
        sid, entry = stream["stream"], stream["entry"]
        types = sig(entry)
        if "bindings" in inp:
            args = next(b["arguments"] for b in inp["bindings"] if b["stream"] == sid).copy()
            if request["stage"] == "hfusion" and request["name"].startswith("litao/add-Ascend910B1/"):
                # HFusion 的 ABI 以锁和 workspace 开始，最后三个参数是 program_id。
                args = args[1:] + [0, 0, 0]
        elif entry == "@two_loads":
            args = [buffer("gm:"+str(i), 4) for i in range(3)] + [request["n"]]
        elif entry == "@issue316_vexp":
            args = [buffer("gm:0", request["n"]*2048), buffer("ub:output", 2048), request["n"]]
        else:
            raise ValueError(f"missing launch for {entry}")
        extra = (launch["extra_arguments"] or {}).get(entry.removeprefix("@"), [])
        coords = next((s for s in inp.get("coordinates", []) if s["stream"] == sid), {})
        for addition in extra:
            i, src = addition["index"], addition["source"]
            if i != len(args):
                raise ValueError("unexpected added argument position")
            if src == ["sub-block-id"]:
                args.append(coords["subblock"])
            else:
                _, space, offset, _ = src
                extent = math.prod(types[i]["shape"])*element_bytes(types[i])
                bank = {"#hivm.address_space<ub>": "ub", "#hivm.address_space<cc>": "cc"}[space]
                args.append(dict(storage=f"{bank}:{sid}", bytes=offset+extent, offset_bits=offset*8,
                                 shape=types[i]["shape"]))
        capacities = {}
        for arg in args:
            if isinstance(arg, dict) and "storage" in arg:
                key = arg["storage"]
                capacities[key] = max(capacities.get(key, 0), arg["bytes"])
        for arg in args:
            if isinstance(arg, dict) and "storage" in arg:
                arg["bytes"] = capacities[arg["storage"]]
        instances.append(dict(stream=sid, entry=entry, arguments=args))
    return {"instances": instances, **{k: v for k, v in inp.items()
                                      if k in ("initial", "initial_default", "initial_cells", "coordinates", "tile")}}


def element_bytes(ty):
    elem = ty["element"]
    if elem["kind"] == "integer":
        return max(1, (elem["bits"]+7)//8)
    return {"bf16": 2, "f16": 2, "f32": 4, "f64": 8}[elem["name"]]
