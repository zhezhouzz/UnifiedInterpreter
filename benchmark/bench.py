"""Replay HIVM, translate complete entries, check Core and explore protocol pairs."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

from tools.elaborate import elaborate, read
from tools.explore import explore
from tools.metadata import validate
from tools.replay import compile_ir
from tools.wellformed import check

ROOT = Path(__file__).resolve().parent


def baseline(path, value, refresh):
    data = json.dumps(value, indent=2, ensure_ascii=False) + "\n"
    if refresh:
        path.write_text(data)
    elif path.read_text() != data:
        raise ValueError(f"baseline differs: {path}")


def absent(path, refresh):
    if path.exists():
        if not refresh:
            raise ValueError(f"stale baseline: {path}")
        path.unlink()


def check_tools(build):
    for line in (ROOT / "toolchain.txt").read_text().splitlines():
        fields = line.split()
        if len(fields) == 2 and len(fields[0]) == 64:
            binary = build / "bin" / fields[1]
            if hashlib.sha256(binary.read_bytes()).hexdigest() != fields[0]:
                raise ValueError(f"toolchain digest mismatch: {binary}")
    for profile in (ROOT / "profiles").glob("*.mlir"):
        argv = [build / "bin/bishengir-opt", "--hacc-append-device-spec=target=" + profile.stem]
        if subprocess.check_output(argv, input=b"module {}\n") != profile.read_bytes():
            raise ValueError(f"chip profile differs: {profile.stem}")


def verify_variant(folder, case, side, args, reader, counts):
    prefix = side + "." if side else ""
    source = folder / "source.mlir"
    argv = case["compile_argv"]
    if side == "buggy":
        argv = case.get("buggy_compile_argv", argv)
        if (folder / "buggy.source.mlir").exists():
            source = folder / "buggy.source.mlir"
    hivm = folder / (prefix + "hivm.mlir")
    compiled = compile_ir(args.build, argv, source, case.get("pass_boundary"))
    if compiled != hivm.read_bytes():
        raise ValueError(f"compiler mismatch: {hivm}")
    counts["byte_identical"] += 1
    if case["id"] == "issue-920":
        result = subprocess.run([args.build / "bin/FileCheck", source], input=compiled, capture_output=True)
        if result.returncode != 1 or result.stderr.count(b"CHECK-NOT: excluded string found") != 2:
            raise ValueError("changed #920 regression signature")

    entries = list(dict.fromkeys(case["entry_functions"]))
    program, errors = elaborate(read(reader, hivm), entries, case.get("semantics_profile", "opsem"))
    if not entries:
        errors = [dict(function=None, op="module", location="module", reason="no executable function")]
    core = folder / (prefix + "program.core")
    diagnostics = folder / (prefix + "diagnostics.json")
    static = folder / (prefix + "static.json")
    execution = folder / (prefix + "execution.json")
    if errors:
        for obsolete in (core, static, execution):
            absent(obsolete, args.refresh)
        baseline(diagnostics, errors, args.refresh)
        counts["diagnosed"] += 1
        if "execution" in case:
            raise ValueError(f"executable case diagnosed: {hivm}")
        return

    absent(diagnostics, args.refresh)
    baseline(core, program, args.refresh)
    counts["whole_translation"] += 1
    try:
        check(program, case)
    except (KeyError, ValueError) as exc:
        absent(execution, args.refresh)
        baseline(static, {"passed": False, "reason": str(exc)}, args.refresh)
        if "execution" in case:
            raise
        return
    baseline(static, {"passed": True}, args.refresh)
    counts["static_wellformed"] += 1

    if "execution" not in case:
        absent(execution, args.refresh)
        return
    verdict, trace, states, observation = explore(program, case["execution"])
    if verdict != case["expected_verdict"][side]:
        raise ValueError((hivm, verdict, observation, trace))
    record = dict(verdict=verdict, states_discovered=states, witness=trace, observation=observation)
    baseline(execution, record, args.refresh)
    if args.demo:
        print(case["id"], side, verdict, "states", states)
        if trace:
            print("  " + " -> ".join(trace))
        print(" ", observation)


def run(args, reader):
    counts = Counter()
    check_tools(args.build)
    selected = 0
    for path in sorted(ROOT.glob("L[123]/**/case.json")):
        case = json.loads(path.read_text())
        validate(case, path)
        pair = "execution" in case
        if (args.case and case["id"] != args.case) or (args.demo and not pair):
            continue
        selected += 1
        sides = ("buggy", "fixed") if pair or case.get("variants") else ("",)
        for side in sides:
            verify_variant(path.parent, case, side, args, reader, counts)
        if pair:
            key = "extension_pairs" if "semantics_profile" in case else "pairs"
            counts[key] += 1
    if args.case and selected != 1:
        raise ValueError(f"expected one matching case, selected {selected}")
    if not args.demo and not args.case:
        baseline(ROOT / "verification.json", dict(counts), args.refresh)
    print(dict(counts))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, default=Path.home() / "GIT/Distributed/AscendNPU-IR/build")
    parser.add_argument("--reader", type=Path)
    parser.add_argument("--case", help="select an exact case.json id")
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--refresh", action="store_true")
    modes.add_argument("--demo", action="store_true", help="verify executable pairs and print witnesses")
    options = parser.parse_args()
    options.build = options.build.resolve()
    with tempfile.TemporaryDirectory() as tmp:
        reader = options.reader.resolve() if options.reader else Path(tmp) / "reader"
        if not options.reader:
            subprocess.run([sys.executable, ROOT / "tools/build_reader.py", options.build, reader], check=True)
        run(options, reader)
