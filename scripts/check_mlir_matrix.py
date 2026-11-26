import argparse
import csv
import hashlib
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from check_scheduler_matrix import endpoints, verify_locations
from mlir_benchmark_launch import launch_for


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bishengir-opt", required=True, type=Path)
    parser.add_argument("--exe", default="_build/default/bin/main.exe", type=Path)
    parser.add_argument("--output", default="_build/mlir-matrix", type=Path)
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--filter", default="")
    parser.add_argument("--stage", choices=("hfusion","hivm"))
    parser.add_argument("--timeout", type=int, default=180)
    opts = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = opts.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    scratch = output/"tmp"
    scratch.mkdir(exist_ok=True)
    env = dict(os.environ, ATTENTION_ROOT=str(root), TMPDIR=str(scratch))
    compiler = opts.bishengir_opt.resolve()
    exe = opts.exe.resolve()
    catalog = json.loads((root/"benchmarks/ir-pairs/catalog.json").read_bytes())["benchmarks"]
    configs = {}
    for path in (root/"benchmarks/litao").rglob("case.json"):
        case = json.loads(path.read_bytes())
        configs[case["id"]] = case.get("execution",{})

    def invoke(argv, log, data=None):
        result = subprocess.run(argv, input=data, cwd=root, env=env, capture_output=True, timeout=opts.timeout)
        log.write_bytes(result.stderr)
        if result.returncode:
            raise ValueError(result.stderr.decode(errors="replace").strip() or f"exit status {result.returncode}")
        return result.stdout

    def run(item):
        name,stage = item
        directory = output/stage/name
        directory.mkdir(parents=True, exist_ok=True)
        source = catalog[name][stage]
        filename = root/source["path"]
        data = filename.read_bytes()
        if hashlib.sha256(data).hexdigest()!=source["sha256"]:
            raise ValueError(f"benchmark checksum mismatch: {filename}")
        frontend = [root/".venv-attention/bin/python","-B",root/"scripts/mlir_frontend.py",filename]
        options = []
        try:
            ast = invoke(frontend,directory/"custom.log",data)
            syntax = "custom"
        except ValueError:
            options = ["--bishengir-opt",compiler]
            ast = invoke([*frontend,*options],directory/"bisheng.log",data)
            syntax = "bisheng"
        ast = json.loads(ast)
        request = json.loads(invoke([exe,"race","launch-request",name,"--"+stage],directory/"input.log"))
        config = configs[name.split("/")[1]] if name.startswith("litao/") else {}
        launch = launch_for(request,ast,config)
        launch_path = directory/"launch.json"
        launch_path.write_text(json.dumps(launch,separators=(",",":")))
        args = [exe,"race","mlir",filename,*options,"--launch",launch_path]
        rows, reports = [], []
        for backend in ("bfs","smt"):
            folder = directory/backend
            folder.mkdir(exist_ok=True)
            row = dict(benchmark=name,stage=stage,source_sha256=source["sha256"],syntax=syntax,
                       backend=backend,status="",pairs="",replayed="",detail="")
            phase = "analysis"
            try:
                core = folder/"core.json"
                invoke([*args,"--backend",backend,"--save",core],folder/"analysis.log")
                phase = "projection"
                trace = folder/"trace.json"
                invoke([*args,"--backend",backend,"--project",core,"--save",trace],folder/"projection.log")
                report = json.loads(trace.read_bytes())
                phase = "verification"
                if report["status"] != "complete":
                    raise ValueError(report.get("reason", f"incomplete search: {report['status']}"))
                verify_locations(ast,report)
                for race in report["races"]:
                    for key,a,b in (("forward","first","second"),("reverse","second","first")):
                        seq = [race[a],race[b]]
                        if [e for e in race[key] if e in seq]!=seq or race[key][-1]!=seq[1]:
                            raise ValueError("wrong source trace endpoint order")
                replay = invoke([*args,"--replay",core],folder/"replay.log").decode()
                count = len(report["races"])
                if not replay.rstrip().endswith(f"replayed={2*count}") or len(json.loads(core.read_bytes())["races"])!=count:
                    raise ValueError("core and source trace counts differ")
                reports.append(report)
                row.update(status=report["status"],pairs=count,replayed=2*count)
            except (ValueError,KeyError,IndexError,subprocess.TimeoutExpired) as error:
                row.update(status=phase,detail=str(error).replace(str(root)+"/",""))
            rows.append(row)
        if len(reports)==2 and (endpoints(reports[0])!=endpoints(reports[1]) or
                (reports[0]["inputs"],reports[0]["status"])!=(reports[1]["inputs"],reports[1]["status"])):
            for row in rows:
                row.update(status="verification",detail="BFS and SMT disagree")
        return rows

    items = [(name,stage) for name in sorted(catalog) if opts.filter in name
             for stage in ([opts.stage] if opts.stage else ["hfusion","hivm"])]
    fields = ["benchmark","stage","source_sha256","syntax","backend","status","pairs","replayed","detail"]
    failed = 0
    with ThreadPoolExecutor(opts.jobs) as pool, (output/"results.csv").open("w",newline="") as dest:
        writer = csv.DictWriter(dest,fieldnames=fields,lineterminator="\n")
        writer.writeheader()
        ordered = sorted(items, key=lambda item: (root/catalog[item[0]][item[1]]["path"]).stat().st_size, reverse=True)
        futures = {item: pool.submit(run, item) for item in ordered}
        for item in items:
            rows = futures[item].result()
            writer.writerows(rows)
            failed += sum(r["status"] != "complete" for r in rows)
            dest.flush()
    print(f"{2*len(items)} backend runs, {failed} failed")
    return int(failed!=0)


if __name__=="__main__":
    sys.exit(main())
