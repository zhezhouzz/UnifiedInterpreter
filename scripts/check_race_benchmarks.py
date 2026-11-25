import argparse
import json
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", type=Path, default=Path("_build/default/bin/main.exe"))
    parser.add_argument("--output", type=Path, default=Path("_build/race-reports"))
    parser.add_argument("--root", type=Path, default=Path("benchmarks/litao"))
    parser.add_argument("--filter", default="")
    parser.add_argument("--n", type=int)
    parser.add_argument("--kv-heads", type=int, default=1)
    parser.add_argument("--symbolic", action="store_true")
    args = parser.parse_args()
    cli = [str(args.exe.resolve()), "race", "--root", str(args.root.resolve())]
    args.output.mkdir(parents=True, exist_ok=True)
    catalog = json.loads(subprocess.check_output([*cli, "list", "--json"], text=True))
    cases = [case for case in catalog if args.filter in case["name"]]
    if not cases:
        raise ValueError("no benchmark matched the filter")
    for case in cases:
        name = case["name"]
        orders = []
        for backend in ["bfs", "smt"]:
            path = args.output / (name.replace("/", "-") + "-" + backend + ".json")
            command = [*cli, "run", name, "--backend", backend, "--save", str(path)]
            if args.n is not None:
                command.extend(["--n", str(args.n)])
            subprocess.run([*command, "--kv-heads", str(args.kv_heads)], check=True)
            subprocess.run([*cli, "replay", str(path)], check=True)
            report = json.loads(path.read_text())
            assert report["status"] == "complete", name
            assert all(r["conflicts"] for r in report["races"]), name
            orders.append(sorted((r["nodes"], r["conflicts"], len(r["forward"]), len(r["reverse"]))
                                 for r in report["races"]))
        assert orders[0] == orders[1], name
        if args.symbolic and case["symbolic_n"]:
            path = args.output / (name.replace("/", "-") + "-symbolic.json")
            subprocess.run([*cli, "run", name, "--backend", "symbolic", "--save", str(path),
                            "--kv-heads", str(args.kv_heads)], check=True)
            report = json.loads(path.read_text())
            assert report["status"] in {"race", "no-race"}, name
            if report["status"] == "race":
                assert report["n"] >= 0 and len(report["races"]) == 1, name
                subprocess.run([*cli, "replay", str(path)], check=True)


if __name__ == "__main__":
    main()
