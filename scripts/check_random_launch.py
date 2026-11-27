import argparse
import json
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("executable", type=Path)
    args = parser.parse_args()
    catalog = json.loads(Path("benchmarks/ir-pairs/catalog.json").read_bytes())["benchmarks"]
    rows = [(name, stage) for name in catalog for stage in ("hivm", "hfusion")]

    def check(row):
        name, stage = row
        path = catalog[name][stage]["path"]
        command = [args.executable.resolve(), "run", path, "--stage", stage, "--trace-db", ":memory:", "--seed", "17"]
        result = json.loads(subprocess.check_output(command))
        assert result["seed"] == 17 and result["launch"]["stage"] == stage
        assert result["status"] in {"returned", "deadlock", "invalid-memory"}, (name, stage, result["status"])

    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(check, rows))
    command = [args.executable.resolve(), "run", "test/random_launch.mlir", "--stage", "hfusion",
               "--trace-db", ":memory:"]
    first = json.loads(subprocess.check_output(command))
    repeat = json.loads(subprocess.check_output(command + ["--seed", str(first["seed"])]))
    assert first["launch"] == repeat["launch"]
    buffer, scalar = first["launch"]["arguments"]
    assert 11 <= buffer["shape"][0] <= 20 and 11 <= scalar <= 20
    assert 11 <= buffer["initial"][0] <= 20
    assert first["returns"] == repeat["returns"] == [[scalar]]
    print(f"{len(rows)} benchmark launches verified")


if __name__ == "__main__":
    main()
