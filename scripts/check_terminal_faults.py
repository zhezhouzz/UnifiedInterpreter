import csv
import json
import subprocess
import sys
import tempfile
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[1]
    executable, launches = map(Path, sys.argv[1:])
    catalog = json.loads((root / "benchmarks/ir-pairs/catalog.json").read_bytes())["benchmarks"]
    deadlocks = ["fixture/blocked-before-loop", "fixture/duplicate-set", "fixture/repeated-broadcast",
                 "fixture/wrong-flag", "issue316/missing-ready", "litao/cross-loop-placement/buggy",
                 "regression/single-broadcast"]
    cases = [(name, "hivm", "deadlock") for name in deadlocks]
    cases.extend(("fixture/invalid-allocation-offset", stage, "invalid-memory") for stage in ("hivm", "hfusion"))
    writer = csv.writer(sys.stdout, lineterminator="\n")
    writer.writerow(["benchmark", "stage", "terminal", "dispatch_events", "detail"])
    with tempfile.TemporaryDirectory(dir=root / "_build") as scratch:
        for name, stage, expected in cases:
            command = [executable, "run", root / catalog[name][stage]["path"], "--stage", stage,
                       "--launch", launches / stage / name / "launch.json", "--scheduler-backend", "bfs",
                       "--trace-db", Path(scratch) / "history.sqlite"]
            run = subprocess.run(command, check=True, capture_output=True, text=True)
            report = json.loads(run.stdout)
            trace = report["schedule"]
            if (report["status"], trace["extent"], trace["terminal"]) != (expected, "terminal", expected):
                raise ValueError((name, stage, report["status"], trace))
            if expected + ": " not in run.stderr:
                raise ValueError((name, stage, run.stderr))
            if expected == "invalid-memory" and "index 1 outside dimension 1" not in report["detail"]:
                raise ValueError((name, stage, report["detail"]))
            writer.writerow([name, stage, expected, len(trace["events"]), json.dumps(report["detail"])])


if __name__ == "__main__":
    main()
