import argparse
import csv
import json
import subprocess
from pathlib import Path


def endpoints(report):
    def location(event):
        return event["stream"], tuple(event["path"]), tuple(event["iterations"])

    return {(location(r["first"]), location(r["second"])) for r in report["races"]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", type=Path, default=Path("_build/default/bin/main.exe"))
    parser.add_argument("--output", type=Path, default=Path("_build/hfusion-races"))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    cli = [str(args.exe.resolve()), "race", "--hfusion"]
    catalog = json.loads(subprocess.check_output([*cli, "list", "--json"], cwd=root))
    catalog = [case for case in catalog if case["native_catalog"]]
    expected = {"vector-add": 0, "tensor-entry-add": 0, "row-sum": 0, "flash-attention": 0, "strided-output": 1}
    if {case["name"] for case in catalog} != expected.keys():
        raise ValueError("HFusion regression expectations must cover the catalog")
    rows = []
    for case in catalog:
        name = case["name"]
        path = root / case["ir"]
        source_ast = output / f"{name}.ast.json"
        with path.open("rb") as source, source_ast.open("wb") as ast:
            subprocess.run([root / ".venv-attention/bin/python", "-B", root / "scripts/attention_frontend.py",
                            path], stdin=source, stdout=ast, check=True)
        reports = {}
        for backend in ("bfs", "smt", "symbolic"):
            saved = output / f"{name}-{backend}.json"
            subprocess.run([*cli, "run", name, "--hfusion-ast", source_ast, "--backend", backend,
                            "--save", saved], cwd=root, check=True)
            report = json.loads(saved.read_text())
            status = ("race" if expected[name] else "no-race") if backend == "symbolic" else "complete"
            if (report["format"], report["status"], len(report["races"]), report["n"]) != (
                    "hfusion-race-1", status, expected[name], case["default_n"]):
                raise ValueError(f"{name}/{backend}: unexpected result")
            subprocess.run([*cli, "replay", saved], cwd=root, check=True)
            reports[backend] = report
        if endpoints(reports["bfs"]) != endpoints(reports["smt"]):
            raise ValueError(f"{name}: concrete backends disagree")
        rows.append([name, len(reports["bfs"]["inputs"]), len(reports["bfs"]["races"]),
                     len(reports["smt"]["races"]), reports["symbolic"]["status"], reports["symbolic"]["n"]])
        if name == "flash-attention":
            # 两个真实函数实例使用相同的 program_id，分别写入相同的 LSE 与 O 区域。
            first = reports["bfs"]["inputs"][0]
            launch = output / "flash-attention-duplicate-pid-launch.json"
            launch.write_text(json.dumps([first, first]))
            duplicate_reports = {}
            for backend in ("bfs", "smt", "symbolic"):
                saved = output / f"flash-attention-duplicate-pid-{backend}.json"
                subprocess.run([*cli, "run", name, "--launch", launch, "--backend", backend,
                                "--save", saved], cwd=root, check=True)
                duplicate = json.loads(saved.read_text())
                pairs = duplicate["races"]
                count = 1 if backend == "symbolic" else 2
                if len(pairs) != count or len({tuple(r["first"]["path"]) for r in pairs}) != count or any(
                    r["first"]["opcode"] != "bufferization.materialize_in_destination" or
                    r["second"]["path"] != r["first"]["path"] for r in pairs
                ):
                    raise ValueError("expected two FlashAttention output write races")
                subprocess.run([*cli, "replay", saved], cwd=root, check=True)
                duplicate_reports[backend] = duplicate
            if endpoints(duplicate_reports["bfs"]) != endpoints(duplicate_reports["smt"]):
                raise ValueError("duplicate program_id: concrete backends disagree")
            rows.append(["flash-attention/duplicate-pid", 2, len(duplicate_reports["bfs"]["races"]),
                         len(duplicate_reports["smt"]["races"]), duplicate_reports["symbolic"]["status"], None])
    with (output / "hfusion-races.csv").open("w", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["benchmark", "instances", "bfs_pairs", "smt_pairs", "symbolic_status", "symbolic_n"])
        writer.writerows(rows)


if __name__ == "__main__":
    main()
