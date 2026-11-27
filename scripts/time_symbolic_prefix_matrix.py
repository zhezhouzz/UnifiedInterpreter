import csv
import hashlib
import json
import statistics
import subprocess
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    catalog = json.loads(Path("benchmarks/ir-pairs/catalog.json").read_bytes())["benchmarks"]
    results = Path("benchmarks/results")
    with (results / "first-analysis.csv").open() as source:
        inputs = {(row["benchmark"], row["stage"]): row for row in csv.DictReader(source)}
    backends = ["bfs-before", "bfs", "smt"]
    fields = ["benchmark", "stage", "source_sha256", "launch_sha256", "status", "pairs",
              "loop_analysis", "symbolic_prefix_used", "prefix_rounds", "baseline_status", "baseline_pairs"]
    for backend in backends:
        fields.extend(f"{backend}_ms_{trial}" for trial in range(1, 4))
        fields.append(f"{backend}_median_ms")
    fields.extend(["bfs_speedup", "faster_after"])
    with (results / "symbolic-prefix-matrix.csv").open("w", newline="") as out:
        writer = csv.DictWriter(out, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for name, case in catalog.items():
            for stage in ("hfusion", "hivm"):
                original = inputs[name, stage]
                sha = digest(Path(case[stage]["path"]))
                ast = Path("_build/first-analysis") / (sha + ".json")
                launch = Path("_build/offline-validation-smt") / stage / name / "launch.json"
                launch_sha = digest(launch)
                if sha != original["source_sha256"] or launch_sha != original["launch_sha256"]:
                    raise ValueError((name, stage, "input digest mismatch"))
                row = dict(benchmark=name, stage=stage, source_sha256=sha, launch_sha256=launch_sha)
                times = {backend: [] for backend in backends}
                outcomes = {backend: set() for backend in backends}
                flags = set()
                for trial in range(3):
                    for backend in backends[trial:] + backends[:trial]:
                        run = subprocess.run(["_build/default/benchmarks/timing/first_analysis.exe",
                                              ast, launch, backend, "--details"],
                                             capture_output=True, check=True, text=True)
                        elapsed, status, pairs = run.stdout.split()
                        outcomes[backend].add((status, pairs))
                        times[backend].append(float(elapsed) * 1000)
                        if backend == "bfs":
                            details = json.loads(run.stderr)
                            flags.add((details["analysis"], details["prefix_rounds"], details["graph_loop_bound"]))
                baseline = {(original["status"], original["pairs"])}
                if outcomes["smt"] != baseline or outcomes["bfs-before"] != baseline or len(flags) != 1 or len(outcomes["bfs"]) != 1:
                    raise ValueError((name, stage, outcomes, flags))
                row["baseline_status"], row["baseline_pairs"] = baseline.pop()
                row["status"], row["pairs"] = outcomes["bfs"].pop()
                if row["status"] != "unknown" and (int(row["pairs"]) > 0) != (int(row["baseline_pairs"]) > 0):
                    raise ValueError((name, stage, row))
                method, rounds, graph_bound = flags.pop()
                row["loop_analysis"] = method or "none"
                row["symbolic_prefix_used"] = "yes" if graph_bound is not None else "no"
                row["prefix_rounds"] = rounds
                for backend, samples in times.items():
                    for trial, sample in enumerate(samples, 1):
                        row[f"{backend}_ms_{trial}"] = round(sample, 6)
                    row[f"{backend}_median_ms"] = round(statistics.median(samples), 6)
                bfs = row["bfs_median_ms"]
                smt = row["smt_median_ms"]
                row["bfs_speedup"] = round(row["bfs-before_median_ms"] / bfs, 4)
                row["faster_after"] = "bfs" if bfs < smt else "smt" if smt < bfs else "tie"
                writer.writerow(row)
                out.flush()


if __name__ == "__main__":
    main()
