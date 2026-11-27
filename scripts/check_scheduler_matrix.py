import argparse
import csv
from hashlib import sha256
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess


def endpoints(doc):
    return {json.dumps([r["first"], r["second"]], sort_keys=True) for r in doc["races"]}


def verify_locations(module, doc):
    fmt = doc["format"]
    full_path = fmt == "ir-race-1" or (fmt == "hivm-race-1" and doc["inputs"].get("ast_format") in ("hivm-module-1","mlir-module-1"))
    def locate(entry, path):
        body = module["functions"][entry.removeprefix("@")]["regions"][0][0]["body"]
        i = 0
        while i < len(path):
            op = body[path[i]]
            i += 1
            if i == len(path):
                return op
            r,b = path[i:i+2] if full_path else (0,0)
            i += 2 if full_path else 0
            body = op["regions"][r][b]["body"]
        raise ValueError("empty event path")
    if fmt == "hivm-race-1":
        entries = {s["stream"]:s["entry"] for s in doc["streams"]}
    elif fmt == "hfusion-race-1":
        entries = {i:doc["entry"] for i in range(len(doc["inputs"]))}
    else:
        entries = {s["stream"]:s["entry"] for s in doc["inputs"]["instances"]}
        if module["source_sha256"] != doc["source_sha256"]:
            raise ValueError("trace and module digest differ")
    for name in entries.values():
        if name.removeprefix("@") not in module["functions"]:
            raise ValueError(f"missing entry {name}")
    for race in doc["races"]:
        for key in ("forward","reverse"):
            pending = {}
            submitted = set()
            for event in race[key]:
                entry = entries[event["stream"]]
                for frame in event.get("calls", []):
                    if frame["entry"] != entry:
                        raise ValueError("invalid dynamic call chain")
                    entry = locate(entry, frame["path"])["properties"]["callee"]
                op = locate(entry, event["path"])
                if entry != event["entry"] or op["opcode"] != event["opcode"]:
                    raise ValueError(f"wrong source location {event}")
                if op["opcode"] in ("memref.alloc", "memref.alloca") or event.get("action") == "allocate":
                    raise ValueError(f"address allocation consumed a scheduler event: {event}")
                if "callee" in event and op["properties"]["callee"] != event["callee"]:
                    raise ValueError("incorrect vector function")
                phase = event["phase"]
                if phase in ("submit","complete"):
                    for task in event.get("tasks", [event]):
                        ident = event["stream"], (task["id"] if "id" in task else task["task"])
                        where = entry, event["path"], event["iterations"], event.get("calls", []), event.get("part"), task["pipe"]
                        if phase == "submit":
                            if ident in submitted:
                                raise ValueError("duplicate submission")
                            submitted.add(ident)
                            pending[ident] = where
                        elif pending.pop(ident) != where:
                            raise ValueError("completion differs from submission")
            if doc.get("trace_extent") == "program_end" and pending:
                raise ValueError("complete trace has pending tasks")


def check_launch_replay(cli, root, dest, name, stage, report):
    # 使用相同的两个真实实例，将输出改为独立分配，原先的重叠写入应当消失。
    path = dest / "independent-outputs.json"
    launch = report["inputs"]
    for stream in launch["instances"]:
        output = stream["arguments"][1]
        output["storage"] += str(stream["stream"])
    path.write_text(json.dumps(launch))
    for method in ("bfs","smt"):
        check = subprocess.check_output([*cli,"run",name,"--"+stage,"--backend",method,"--launch",path],cwd=root)
        result = json.loads(check)
        if result["status"] != "complete" or result["races"]:
            raise ValueError("disjoint output buffers share a target")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", type=Path, default=Path("_build/default/bin/main.exe"))
    parser.add_argument("--output", type=Path, default=Path("_build/scheduler-matrix"))
    parser.add_argument("--results", type=Path)
    parser.add_argument("--jobs", type=int, default=3)
    parser.add_argument("--stage", choices=["hfusion", "hivm"])
    parser.add_argument("--filter", default="")
    opts = parser.parse_args()
    partial_modules = {
        ("cv/scene1/correct", "hivm"),
        ("cv/scene1/error", "hivm"),
        ("fixture/invalid-allocation-offset", "hfusion"),
    }
    root = Path(__file__).resolve().parents[1]
    output = opts.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    cli = [opts.exe.resolve(), "race"]
    cases = json.loads(subprocess.check_output([*cli, "pairs", "--json"], cwd=root))
    def run(item):
        name, stage = item
        ir = cases[name][stage]
        digest = sha256((root / ir["path"]).read_bytes()).hexdigest()
        if digest != ir["sha256"]:
            raise ValueError(f"{name}/{stage}: IR digest mismatch")
        module = json.loads((root / "benchmarks/scheduler/modules" / (digest+".json")).read_bytes())
        dest = output / stage / name
        dest.mkdir(parents=True, exist_ok=True)
        reports = {}
        row = [name, stage]
        for method in ("bfs", "smt"):
            path = dest / (method + ".json")
            with (dest / (method+".log")).open("wb") as log:
                result = subprocess.run([*cli, "run", name, "--"+stage, "--backend", method, "--save", path],
                                        cwd=root, stdout=log, stderr=subprocess.STDOUT)
                if result.returncode:
                    row.extend(["error", ""])
                    continue
                doc = json.loads(path.read_bytes())
                verify_locations(module, doc)
                if (name, stage) in partial_modules:
                    valid = (doc["format"] == "ir-race-1" and doc["status"] == "unknown" and not doc["races"]
                             and doc.get("reason") == "the module model ends before program termination")
                else:
                    valid = doc["status"] in ("complete","no-race") or (doc["status"] == "race" and doc["races"])
                if doc["benchmark"] != name or not valid:
                    raise ValueError(f"{name}/{stage}/{method}: incomplete report")
                if doc["format"] in ("hfusion-race-1", "ir-race-1"):
                    subprocess.run([*cli, "replay", path, "--"+stage], cwd=root, stdout=log, stderr=log, check=True)
                for r in doc["races"]:
                    for first, last, prefix in [(r["first"], r["second"], r["forward"]),
                                                (r["second"], r["first"], r["reverse"])]:
                        if ((doc.get("trace_extent") != "program_end" and prefix[-1] != last) or
                                [e for e in prefix if e in (first, last)] != [first, last]):
                            raise ValueError(f"{name}/{stage}/{method}: wrong endpoint order")
                reports[method] = doc
                row.extend([doc["status"], len(doc["races"])])
        if len(reports) == 2:
            bfs, smt = reports["bfs"], reports["smt"]
            if endpoints(bfs) != endpoints(smt) or (bfs["inputs"],bfs["status"]) != (smt["inputs"],smt["status"]):
                raise ValueError(f"{name}/{stage}: BFS and SMT results differ")
            if stage == "hivm" and name == "strided-output":
                if len(bfs["races"]) != 1:
                    raise ValueError("expected overlapping output writes")
                check_launch_replay(cli, root, dest, name, stage, bfs)
        return row
    stages = [opts.stage] if opts.stage else ["hfusion", "hivm"]
    items = [(name, stage) for name in sorted(cases) if opts.filter in name for stage in stages]
    with ThreadPoolExecutor(max_workers=opts.jobs) as executor:
        rows = list(executor.map(run, items))
    with (opts.results or output / "results.csv").open("w", newline="") as out:
        writer = csv.writer(out, lineterminator="\n")
        writer.writerow(["benchmark", "stage", "bfs_status", "bfs_pairs", "smt_status", "smt_pairs"])
        writer.writerows(rows)
    failures = [row[:2] for row in rows if "error" in row]
    print(f"{len(rows)} benchmark/stage combinations, {len(failures)} failed")
    for row in failures:
        print(*row)
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
