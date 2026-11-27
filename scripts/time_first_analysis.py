import argparse
import csv
import hashlib
import json
import statistics
import subprocess
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--launches", required=True, type=Path)
    parser.add_argument("--bishengir-opt", required=True)
    args = parser.parse_args()
    cases = json.loads(Path("benchmarks/ir-pairs/catalog.json").read_bytes())["benchmarks"]
    scratch = Path("_build/first-analysis")
    scratch.mkdir(parents=True, exist_ok=True)
    with open("benchmarks/results/scheduler-mlir-matrix.csv") as f:
        syntax = {(r["benchmark"], r["stage"]): r["syntax"] for r in csv.DictReader(f)}
    with open("benchmarks/results/first-analysis.csv", "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["benchmark", "stage", "source_sha256", "launch_sha256", "status", "pairs",
                         "bfs_ms_1", "bfs_ms_2", "bfs_ms_3", "smt_ms_1", "smt_ms_2", "smt_ms_3",
                         "bfs_median_ms", "smt_median_ms", "faster"])
        for name, case in cases.items():
            for stage in ("hfusion", "hivm"):
                source = Path(case[stage]["path"])
                data = source.read_bytes()
                digest = hashlib.sha256(data).hexdigest()
                if digest != case[stage]["sha256"]:
                    raise ValueError(source)
                launch = args.launches / stage / name / "launch.json"
                ast = scratch / (digest + ".json")
                options = ["--bishengir-opt", args.bishengir_opt] if syntax[name, stage] == "bisheng" else []
                with ast.open("wb") as out:
                    subprocess.run([sys.executable, "-B", "scripts/mlir_frontend.py", source, *options],
                                   input=data, stdout=out, check=True)
                times = {"bfs": [], "smt": []}
                outcomes = set()
                for trial in range(3):
                    for backend in (("bfs", "smt") if (trial + len(name)) % 2 else ("smt", "bfs")):
                        duration, status, pairs = subprocess.check_output(
                            ["_build/default/benchmarks/timing/first_analysis.exe", ast, launch, backend],
                            text=True).split()
                        times[backend].append(round(float(duration) * 1000, 6))
                        outcomes.add((status, pairs))
                if len(outcomes) != 1 or status == "unknown":
                    raise ValueError((name, stage, outcomes))
                b, s = (statistics.median(t) for t in times.values())
                writer.writerow([name, stage, digest, hashlib.sha256(launch.read_bytes()).hexdigest(),
                                 status, pairs, *times["bfs"], *times["smt"], b, s,
                                 "bfs" if b < s else "smt" if s < b else "tie"])
                f.flush()


if __name__ == "__main__":
    main()
