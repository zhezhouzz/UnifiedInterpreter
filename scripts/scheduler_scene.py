def scene_inputs(request, module):
    model = request["launch"]["model"]
    q, heads, dim = model["query_length"], 16, 128
    slots = 2
    sizes = [8, 4096, q*heads*dim*2, slots*128*dim*2, slots*128*dim*2,
             slots*128*dim*2, slots*4, q*heads*dim*2, slots*4, 8, 8, 4, 4]
    args = [dict(storage=f"gm:{i}", bytes=size) for i, size in enumerate(sizes)]
    args.extend([1, heads, dim, 1, 0.125, heads*dim, dim, 128*dim, dim, dim, 128*dim,
                 dim, dim, 1, 1, 1, heads*dim, dim, slots, 1, 1, 1])
    # 坐标由 grid 和逻辑核类型决定，查询长度及稀疏页索引由同一个模型提供。
    instances = []
    for entry, function in module["functions"].items():
        attrs = function["attributes"]
        if "hacc.entry" not in attrs:
            continue
        if request["stage"] == "hfusion":
            instances.append(dict(stream=0, entry="@"+entry, arguments=args+[0, 0, 0]))
        else:
            cube = attrs["hivm.func_core_type"] == "#hivm.func_core_type<AIC>"
            for sub in (range(1) if cube else range(2)):
                instances.append(dict(stream=0 if cube else sub+1, entry="@"+entry, arguments=args,
                                      core="AIC" if cube else "AIV", block=0, subblock=sub))
    if len(instances) != (1 if request["stage"] == "hfusion" else 3):
        raise ValueError("missing sparse attention kernel entry")
    memory = {"gm:9": {"0": 0, "32": q}, "gm:10": {"0": 0, "32": model["active_rows"]},
              "gm:11": {"0": model["key_length"]}, "gm:12": {"0": model["key_length"]-1},
              "gm:6": {str(i*32): model["sparse_index"] for i in range(slots)},
              "gm:8": {str(model["sparse_index"]*32): model["physical_page"]}}
    return {"grid": [1, 1, 1], "instances": sorted(instances, key=lambda s: s["stream"]),
            "model": model, "memory": memory, "initial_default": 0,
            "local_storage_bits": {"ub": 2031616, "cbuf": 4194304, "ca": 524288,
                                   "cb": 524288, "cc": 2097152}}
