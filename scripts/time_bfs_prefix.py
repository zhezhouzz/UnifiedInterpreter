import csv
import json
import statistics
import subprocess
from pathlib import Path


def measure(exe, ast, launch):
    elapsed, status, pairs = subprocess.check_output([exe, ast, launch, "bfs"], text=True).split()
    return float(elapsed) * 1000, (status, pairs)


def main():
    root = Path("_build/first-analysis")
    after = Path("_build/default/benchmarks/timing/first_analysis.exe")
    before = root / "bfs-before"
    with open("benchmarks/results/first-analysis.csv") as f:
        rows = list(csv.DictReader(f))
    with open("benchmarks/results/bfs-prefix-analysis.csv", "w", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow(["benchmark", "stage", "rounds", "status", "pairs", "before_ms", "after_ms"])
        for row in rows:
            name, stage = row["benchmark"], row["stage"]
            launch = Path("_build/offline-validation-smt") / stage / name / "launch.json"
            ast = root / (row["source_sha256"] + ".json")
            for count in ([None, 128] if name in ("fixture/loop-write", "issue316/missing-ready") else [None]):
                config = launch
                if count:
                    spec = json.loads(launch.read_bytes())
                    args = spec["streams"][0]["arguments"]
                    args[-1] = count
                    if name.startswith("issue316/"):
                        args[0].update(shape=[count * 1024], bytes=count * 2048)
                    config = root / "long-launch.json"
                    config.write_text(json.dumps(spec))
                old = [] if count else [float(row["bfs_median_ms"])]
                new = []
                results = set()
                for trial in range(3):
                    runs = [(after, new)]
                    if count:
                        runs.insert(trial % 2, (before, old))
                    for exe, times in runs:
                        elapsed, outcome = measure(exe, ast, config)
                        times.append(elapsed)
                        results.add(outcome)
                if not count:
                    results.add((row["status"], row["pairs"]))
                if len(results) != 1:
                    raise ValueError((name, stage, results))
                writer.writerow([name, stage, count or "original", *results.pop(),
                                 statistics.median(old), statistics.median(new)])
                f.flush()


if __name__ == "__main__":
    main()
