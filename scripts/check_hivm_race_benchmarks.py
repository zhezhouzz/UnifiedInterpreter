import argparse
import csv
import json
import subprocess
from pathlib import Path


def run_case(cli, output, case, backend):
    name = case["name"]
    path = output / name / f"{backend}.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([*cli, "run", name, "--hivm", "--backend", backend, "--save", path], check=True)
    report = json.loads(path.read_text())
    if report["format"] != "hivm-race-1" or report["benchmark"] != name:
        raise ValueError(f"{path}: unexpected report format or benchmark")

    races = report["races"]
    if backend == "symbolic":
        status = report["status"]
        if status not in ("race", "no-race") or len(races) != int(status == "race"):
            raise ValueError(f"{path}: {status}, {len(races)} race pairs")
        if races and (type(report["n"]) is not int or report["n"] < 0):
            raise ValueError(f"{path}: expected a nonnegative symbolic model")
    elif report["status"] != "complete" or report["n"] != case["default_n"]:
        raise ValueError(f"{path}: expected a complete report for the default input")

    for race in races:
        first, second = race["first"], race["second"]
        if first == second:
            raise ValueError(f"{path}: identical target events")
        for direction, order in (("forward", [first, second]), ("reverse", [second, first])):
            prefix = race[direction]
            if not prefix or prefix[-1] != order[-1] or [e for e in prefix if e in order] != order:
                raise ValueError(f"{path}: incorrect target order or final event in {direction}")
    return report


def targets(report):
    return sorted(json.dumps([r["first"], r["second"]], sort_keys=True) for r in report["races"])


def main():
    parser = argparse.ArgumentParser(description="Check HIVM race traces for the full benchmark catalog.")
    parser.add_argument("--exe", type=Path, default=Path("_build/default/bin/main.exe"))
    parser.add_argument("--output", type=Path, default=Path("_build/hivm-race-results"))
    args = parser.parse_args()
    cli = [args.exe.resolve(), "race"]
    catalog = json.loads(subprocess.check_output([*cli, "list", "--json"]))
    if not catalog or len({case["name"] for case in catalog}) != len(catalog):
        raise ValueError("expected a nonempty catalog with unique benchmark names")

    rows = []
    for case in catalog:
        bfs = run_case(cli, args.output, case, "bfs")
        smt = run_case(cli, args.output, case, "smt")
        if targets(bfs) != targets(smt):
            raise ValueError(f"{case['name']}: BFS and SMT reported different target events")
        symbolic = run_case(cli, args.output, case, "symbolic") if case["symbolic_n"] else None
        rows.append([case["name"], case["default_n"], len(bfs["races"]), len(smt["races"]),
                     symbolic["status"] if symbolic else None, symbolic["n"] if symbolic else None])

    with (args.output / "results.csv").open("w", newline="") as table:
        writer = csv.writer(table, lineterminator="\n")
        writer.writerow(["benchmark", "default_n", "bfs_pairs", "smt_pairs", "symbolic_status", "symbolic_n"])
        writer.writerows(rows)


if __name__ == "__main__":
    main()
