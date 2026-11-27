import argparse
import csv
import hashlib
import json
import math
import operator
import os
import struct
import subprocess
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from mlir_benchmark_launch import launch_for


def inputs(name, launch):
    values = {
        "vector-add": {"%a": [-3, -1, 0, .5, 2, 4, 8, 16], "%b": [1, 2, 3, 4, -2, -4, .25, -.5]},
        "row-sum": {"%input": [1, 2, 3, 4, -1, 0, 1, 2, .5, .25, -.5, -.25]},
        "strided-output": {"input0": [2], "input1": [4]},
        "fixture/hivm-two-loads": {"gm:0": [-5], "gm:1": [13], "gm:2": [-9]},
    }.get(name, {})
    if name == "flash-attention":
        values = {"%arg5": [1 + i % 8 / 8 for i in range(128 * 128)],
                  "%arg6": [-9] * 128, "%arg7": [-9] * (128 * 128)}
    elif name.startswith("cv/scene1/"):
        values = {"gm:3": [1 + i % 8 for i in range(32768)], "gm:7": [-9] * 2048}
    elif name.startswith("issue316/"):
        values = {"gm:0": [i // 1024 for i in range(3072)], "ub:output": [-9] * 1024}
    seeded = set()
    for stream in launch["streams"]:
        for arg in stream["arguments"]:
            if isinstance(arg, dict) and arg["storage"] in values and arg["storage"] not in seeded:
                arg["initial"] = values[arg["storage"]]
                seeded.add(arg["storage"])


def float32(value):
    return struct.unpack("<f", struct.pack("<f", value))[0]


def vectorlayout_expected(launch):
    args = launch["streams"][0]["arguments"]
    q, keys, table, shift, block, lengths, end, output = [a["initial"] for a in args[2:10]]
    expected = output.copy()
    group, dimension = args[12:14]
    heads = group * args[26]
    scale = float32(args[16] * float32(1.44269502))
    start = shift[0] + 32 * block[0]
    for row in range(start, min(start + 32, end[0])):
        for head in range(heads):
            a = row * args[17] + head * args[18]
            query = q[a:a + dimension]
            for page in range((lengths[0] + 127) // 128):
                scores = []
                for col in range(page * 128, min((page + 1) * 128, lengths[0], row + 1)):
                    b = table[page] * args[19] + col % 128 * args[20] + head // group * args[21]
                    scores.append(float32(sum(map(operator.mul, query, keys[b:b + dimension])) * scale))
                expected[row * args[24] + head * args[23] + page] = max(scores, default=-math.inf)
    return expected


DEADLOCKS = {
    "fixture/blocked-before-loop", "fixture/duplicate-set", "fixture/repeated-broadcast",
    "fixture/wrong-flag", "regression/single-broadcast", "issue316/missing-ready",
    "litao/cross-loop-placement/buggy", "litao/empty-preload/buggy", "litao/wrong-event/buggy",
}


def verify(name, stage, launch, result, config):
    expected_status = "returned"
    if name == "fixture/invalid-allocation-offset":
        expected_status = "invalid-memory"
    elif stage == "hivm" and name in DEADLOCKS:
        expected_status = "deadlock"
    if result["status"] != expected_status:
        raise ValueError(f"expected {expected_status}, observed {result['status']} {result['detail']}")
    if expected_status != "returned":
        if not result["detail"]:
            raise ValueError("missing fault or blocked instruction")
        return str(result["detail"])

    def cells(bank, fmt):
        data = bytes.fromhex(result["memory_hex"][bank])
        return [x for x, in struct.iter_unpack("<" + fmt, data)]

    def check(bank, fmt, expected):
        actual = cells(bank, fmt)
        for i, (a, b) in enumerate(zip(actual, expected, strict=True)):
            if a != b:
                raise ValueError(f"{bank}[{i}]={a}, expected {b}")
        return f"{bank} ({len(actual)} elements)"

    if name.startswith("vectorlayout/"):
        expected = vectorlayout_expected(launch)
        actual = cells("gm9", "f")
        diffs = [i for i, (x, y) in enumerate(zip(actual, expected, strict=True)) if x != y]
        written = [i for i, x in enumerate(expected) if x != 12345]
        required = written if name.endswith("/fail") and stage == "hivm" else []
        if diffs != required:
            raise ValueError(f"layout difference at {len(diffs)} positions, expected {len(required)}")
        return f"gm9 ({len(actual)} elements; {len(diffs)} differ from causal page maxima)"
    if name == "flash-attention":
        return ", ".join([check("%arg7", "e", [1 + i % 8 / 8 for i in range(16384)]),
                          check("%arg6", "f", [float32(math.log(128))] * 128)])
    if name.startswith("cv/scene1/"):
        expected = [struct.unpack("<I", struct.pack("<f", 1 + i % 8))[0] >> 16 for i in range(2048)]
        return check("gm:7", "H", expected)
    if name.startswith("issue316/"):
        rounded, = struct.unpack("<e", struct.pack("<e", math.exp(2)))
        return check("ub:output", "e", [rounded] * 1024)
    simple = {
        "vector-add": ("%out", "f", [-2, 1, 3, 4.5, 0, 0, 8.25, 15.5]),
        "row-sum": ("%out", "f", [10, 2, 0]), "fixture/fifo-copy": ("gm:0", "i", [7] * 3),
        "fixture/hivm-two-loads": ("gm:2", "f", [13]),
        "strided-output": ("output", "e", [2, 2, 2, 4, 4, 4, 4]),
    }
    if name in simple:
        return check(*simple[name])
    if name.startswith("fixture/"):
        groups = [
            ([7, 7, 7], "all-barrier pipe-barrier other-pipe-barrier else-branch loop-zero duplicate-set"),
            ([7, 1], "block-data-wait block-handoff broadcast concurrent-loop local-handoff loop-write "
                     "nested-loop repeated-broadcast stride-minus-two three-accesses two-streams wrong-flag"),
            ([1, 0], "disjoint-reads-writes"), ([7, 0], "two-reads"), ([1, 1, 1], "overlapping-writes"),
            ([7, 0, 0] + [1] * 9, "late-address"),
        ]
        for expected, fixtures in groups:
            if name.split("/")[1] in fixtures.split():
                return check("gm:0", "i", expected)
    if name.startswith("regression/") and name != "regression/fresh-allocation":
        return check("gm:0", "i", [1, 1, 1] if name == "regression/disjoint" else [7, 1])
    outputs = dict(config.get("outputs", {}))
    if name.startswith(("litao/missing-wait/", "litao/mix-handoff/", "litao/wrong-event/")):
        outputs["gm:1"] = 7
    if name.startswith("litao/indirect-atomic/"):
        outputs["gm:1"] = 5
    checks = []
    if stage == "hivm":
        sequences = {op: [v] for op, v in config.get("reads", {}).items()}
        sequences.update(config.get("read_sequence", {}))
        for op, sequence in sequences.items():
            records = [r["values"] for r in result["inspected_inputs"] if r["opcode"] == "hivm.hir." + op]
            for lanes, v in zip(records, sequence, strict=True):
                if not lanes or any(x != v for x in lanes):
                    raise ValueError(f"{op} input differs from {v}: {lanes[:4]}")
            checks.append(f"{op} reads {sequence}")
    if outputs:
        checks.extend(check(bank, "f", [v] * config.get("tile", 32)) for bank, v in outputs.items())
    return ", ".join(checks) or "all streams returned and pending tasks completed"


def verify_schedule(name, stage, launch, result, config, hashes):
    trace = result["schedule"]
    events = trace["events"]
    encoded = json.dumps(events, ensure_ascii=False, separators=(",", ":")).encode()
    if hashlib.sha256(encoded).hexdigest() != trace["hash"] or trace["reused"] != (trace["hash"] in hashes):
        raise ValueError("trace digest or history mismatch")
    if trace["extent"] == "terminal":
        if trace["terminal"] != result["status"] or trace["targets"] is not None:
            raise ValueError("terminal state differs from delivered trace")
        if (name, stage, result["status"]) == ("fixture/shared-allocation", "hfusion", "invalid-memory"):
            if "uninitialized descriptor" not in result["detail"]:
                raise ValueError(str(result["detail"]))
            return result["detail"]
        return verify(name, stage, launch, result, config)
    if trace["extent"] != "race_prefix" or result["status"] not in ("returned", "deadlock", "invalid-memory"):
        raise ValueError("unfinished execution")
    first, last = [target["event"] for target in trace["targets"]]
    if first not in events[:-1] or last != events[-1] or first == last:
        raise ValueError("race endpoints missing or out of order")
    if (name, stage) == ("fixture/fifo-copy", "hivm"):
        values = struct.unpack("<iii", bytes.fromhex(result["memory_hex"]["gm:0"]))
        expected = (7, 7, 7) if trace["targets"][0]["source"]["path"] == [10] else (7, 7, 0)
        if values != expected:
            raise ValueError(f"unexpected FIFO output {values}")
        return f"opposite copy orders checked against gm:0 {values}"
    return "replayed both ordered race endpoints and continued to " + result["status"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bishengir-opt", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("_build/interpreter-matrix"))
    parser.add_argument("--results", type=Path)
    parser.add_argument("--filter", default="")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--scheduled", action="store_true", help="request and replay two traces in separate processes")
    parser.add_argument("--offline", type=Path, help="test the release executable in an isolated network and filesystem")
    opts = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    exe = root / "_build/default/bin/main.exe"
    output = opts.output.resolve()
    scratch = output / "tmp"
    scratch.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, TMPDIR=str(scratch), ATTENTION_ROOT=str(root))
    catalog = json.loads((root / "benchmarks/ir-pairs/catalog.json").read_bytes())["benchmarks"]
    with (root / "benchmarks/results/scheduler-mlir-matrix.csv").open() as f:
        syntax = {(r["benchmark"], r["stage"]): r["syntax"] for r in csv.DictReader(f)}

    def check(item):
        name, stage = item
        source = catalog[name][stage]
        folder = output / stage / name
        folder.mkdir(parents=True, exist_ok=True)
        path = root / source["path"]
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != source["sha256"]:
            raise ValueError(f"source digest mismatch: {path}")
        options = ["--bishengir-opt", opts.bishengir_opt.resolve()] if syntax[item] == "bisheng" else []
        frontend = [root / ".venv-attention/bin/python", "-B", root / "scripts/mlir_frontend.py", path, *options]
        ast = json.loads(subprocess.check_output(frontend, input=data, env=env))
        request = json.loads(subprocess.check_output([exe, "race", "launch-request", name, "--"+stage], env=env))
        config = {}
        if name.startswith("litao/"):
            case = root / catalog[name]["hivm"]["path"]
            config = json.loads(case.with_name("case.json").read_bytes())["execution"]
        launch = launch_for(request, ast, config)
        if stage == "hivm":
            for key, value in config.get("initial", {}).items():
                parts = key.split(":")
                if len(parts) == 3 and parts[0] in ("ub", "cc"):
                    space, stream, offset = parts
                    launch.setdefault("local_initial", []).append(dict(
                        space=space, stream=int(stream), base_bytes=int(offset), element="f32",
                        count=config.get("tile", 32), value=value))
        inputs(name, launch)
        config_file = folder / "launch.json"
        config_file.write_text(json.dumps(launch, separators=(",", ":")))
        peak = folder / "rss"
        args = ["/usr/bin/time", "-f", "%M", "-o", peak, exe, "run", path,
                "--stage", stage, "--launch", config_file, *options]
        if stage == "hivm":
            for op in sorted(set(config.get("reads", {})) | set(config.get("read_sequence", {}))):
                args.extend(["--inspect-input", "hivm.hir." + op])
        if opts.offline:
            cache = output / "cache"
            cache.mkdir(exist_ok=True)
            sandbox = ["bwrap", "--unshare-all", "--die-with-parent", "--clearenv",
                       "--setenv", "HOME", "/home/user", "--setenv", "PATH", "/bin",
                       "--dir", "/home/user", "--bind", cache, "/home/user/.cache",
                       "--proc", "/proc", "--dev", "/dev", "--ro-bind", "/bin/busybox", "/bin/busybox",
                       "--symlink", "busybox", "/bin/tar", "--symlink", "busybox", "/bin/gzip",
                       "--ro-bind", "/lib64/ld-linux-x86-64.so.2", "/lib64/ld-linux-x86-64.so.2"]
            for libname in ("libc", "libm", "libpthread", "libdl", "librt", "libutil", "libresolv", "libanl"):
                for shared in Path("/lib/x86_64-linux-gnu").glob(libname + ".so.[0-9]"):
                    sandbox.extend(["--ro-bind", shared, shared])
            sandbox.extend(["--ro-bind", opts.offline.resolve(), "/interpreter", "--ro-bind", path, "/input.mlir",
                            "--ro-bind", config_file, "/launch.json", "/interpreter", "run", "/input.mlir",
                            "--launch", "/launch.json", "--stage", stage])
            sandbox.extend(args[args.index("--inspect-input"):] if "--inspect-input" in args else [])
            if not opts.scheduled:
                start = time.perf_counter()
                proc = subprocess.run(sandbox, capture_output=True, timeout=300, check=True)
                elapsed = time.perf_counter() - start
                result = json.loads(proc.stdout)
                (folder / "result.json").write_bytes(proc.stdout)
                check_result = verify_schedule(name, stage, launch, result, config, set())
                return dict(benchmark=name, stage=stage, source_sha256=source["sha256"], status=result["status"],
                            trace_sha256=result["schedule"]["hash"], wall_seconds=elapsed, check=check_result)
        if opts.scheduled:
            rows = []
            hashes = set()
            targets = []
            with tempfile.TemporaryDirectory(dir=folder) as history:
                command = [*args, "--trace-db", Path(history) / "history.sqlite"]
                if opts.offline:
                    command = [sandbox[0], "--bind", history, "/history", *sandbox[1:],
                               "--trace-db", "/history/history.sqlite"]
                for number in (1, 2):
                    row = dict(benchmark=name, stage=stage, source_sha256=source["sha256"], run=number, status="error", extent="",
                               reused="", hash="", events="", check="")
                    start = time.perf_counter()
                    proc = subprocess.run(command, env=env, capture_output=True, timeout=600)
                    row["wall_seconds"] = round(time.perf_counter() - start, 6)
                    (folder / f"stderr-{number}").write_bytes(proc.stderr)
                    if proc.returncode:
                        row["check"] = proc.stderr.decode().strip()
                    else:
                        result = json.loads(proc.stdout)
                        (folder / f"result-{number}.json").write_bytes(proc.stdout)
                        trace = result["schedule"]
                        targets.append(trace["targets"])
                        row.update(status=result["status"], extent=trace["extent"], reused=trace["reused"],
                                   hash=trace["hash"], events=len(trace["events"]))
                        try:
                            row["check"] = verify_schedule(name, stage, launch, result, config, hashes)
                        except ValueError as error:
                            row.update(status="mismatch", check=str(error))
                        hashes.add(trace["hash"])
                    rows.append(row)
            if len(targets) == 2 and all(targets):
                comparison = "opposite" if targets[0] == targets[1][::-1] else "different targets or same order"
            else:
                comparison = "no paired race targets"
            for row in rows:
                row["race_order"] = comparison
            return rows
        proc = subprocess.run([*args, "--builtin"], env=env, capture_output=True, timeout=180)
        (folder / "stderr").write_bytes(proc.stderr)
        row = dict(benchmark=name, stage=stage, source_sha256=source["sha256"], status="error", check="",
                   steps="", completed_tasks="", parse_s="", execute_s="", peak_kib="")
        if proc.returncode:
            row["check"] = proc.stderr.decode().strip()
            return row
        result = json.loads(proc.stdout)
        (folder / "result.json").write_bytes(proc.stdout)
        row.update(status=result["status"], steps=result["steps"], completed_tasks=result["tasks"],
                   parse_s=round(result["parse_seconds"], 6), execute_s=round(result["execute_seconds"], 6),
                   peak_kib=peak.read_text().strip())
        try:
            row["check"] = verify(name, stage, launch, result, config)
        except ValueError as error:
            row.update(status="mismatch", check=str(error))
        return row

    items = [(name, stage) for name in catalog for stage in ("hfusion", "hivm") if opts.filter in name]
    if not items:
        parser.error("no matching benchmark")
    with ThreadPoolExecutor(opts.jobs) as pool:
        rows = list(pool.map(check, items))
    if opts.scheduled:
        rows = [row for pair in rows for row in pair]
    with (opts.results or output / "results.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0], lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    failed = sum(row["status"] in ("error", "step-limit", "mismatch") for row in rows)
    print(f"{len(rows)} executions, {failed} failed checks")
    return int(failed != 0)


if __name__ == "__main__":
    raise SystemExit(main())
