#!/usr/bin/env python3
"""Export the archived FlashAttention IR mutations and their analytic oracles."""

import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

from ir_mutation_dataset import write_json, write_mutation


SPEC = Path("attention_test/fixtures/flash_attention_mutations.json")


def expand_input(pattern, config):
    n, d = config["N"], config["D"]
    inputs = {"scale": config["scale"]}
    for name in ("Q", "K", "V"):
        matrix = [[0.0] * d for _ in range(n)]
        fields = pattern.get(name, {})
        for column, value in fields.get("columns", []):
            for row in matrix:
                row[column] = value
        for row, column, value in fields.get("entries", []):
            matrix[row][column] = value
        inputs[name] = matrix
    return inputs


def expand_expected(expected, config):
    if expected["kind"] == "error":
        return expected
    row = [0.0] * config["D"]
    row[expected["O_column"]] = expected["O_value"]
    return {
        "kind": "output",
        "O": [row] * config["N"],
        "log_sum_exp": [expected["log_sum_exp"]] * config["N"],
    }


def generate(root, output):
    spec = json.loads((root / SPEC).read_text(encoding="utf-8"))
    config = spec["configuration"]
    baselines = {}
    sources = {}
    for stage, baseline in spec["baselines"].items():
        raw = (root / baseline["path"]).read_bytes()
        if hashlib.sha256(raw).hexdigest() != baseline["sha256"]:
            raise ValueError(f"{stage}: baseline SHA-256 changed: {baseline['path']}")
        ir = f"baselines/{stage}.mlir"
        (output / ir).parent.mkdir(parents=True, exist_ok=True)
        (output / ir).write_bytes(raw)
        sources[stage] = raw.decode("utf-8")
        baselines[stage] = {"ir": ir, "source": baseline["path"], "sha256": baseline["sha256"]}

    inputs = {}
    for name, pattern in spec["inputs"].items():
        inputs[name] = f"inputs/{name}.json"
        write_json(output / inputs[name], expand_input(pattern, config))

    source_expected = "expected/source.json"
    write_json(output / source_expected, expand_expected(spec["source_expected"], config))

    cases = []
    for mutation in spec["mutations"]:
        expected = f"expected/{mutation['id']}.json"
        write_json(output / expected, expand_expected(mutation["ir_expected"], config))
        for stage, source in sources.items():
            case_id = f"{stage}-{mutation['id']}"
            edits = mutation["edits"][stage] + mutation.get("shared_edits", [])
            ir, patch = write_mutation(output, case_id, source, baselines[stage]["ir"], edits)
            cases.append({
                "id": case_id,
                "stage": stage,
                "origin": "modeled_lowering",
                "rule": mutation["rule"],
                "input": mutation["input"],
                "ir": ir,
                "patch": patch,
                "source_expected": source_expected,
                "ir_expected": expected,
            })
    write_json(output / "manifest.json", {
        "profile": spec["profile"],
        "configuration": config,
        "baselines": baselines,
        "inputs": inputs,
        "source_expected": source_expected,
        "cases": cases,
    })
    return len(cases)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--output", type=Path, help="Export to a new dataset directory")
    mode.add_argument("--test", type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.test:
        with tempfile.TemporaryDirectory(prefix="flash-attention-mutations-") as scratch:
            dataset = Path(scratch)
            generate(args.repo_root, dataset)
            subprocess.run([str(args.test.absolute()), str(dataset)], check=True)
        return

    output = args.output.resolve()
    if output.exists():
        parser.error(f"output already exists: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".flash-attention-mutations-", dir=output.parent) as scratch:
        dataset = Path(scratch) / "dataset"
        count = generate(args.repo_root, dataset)
        dataset.rename(output)
    print(f"Exported {count} FlashAttention IR mutations to {output}")


if __name__ == "__main__":
    main()
