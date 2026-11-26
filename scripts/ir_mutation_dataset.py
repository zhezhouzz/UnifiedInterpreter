"""Write deterministic IR mutations and their dataset metadata."""

import difflib
import json


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def write_mutation(output, case_id, source, baseline, edits):
    mutant = source
    for edit in edits:
        before, after = edit["before"], edit["after"]
        if mutant.count(before) != 1 or before == after:
            raise ValueError(f"{case_id}: expected a unique, changing IR anchor: {before!r}")
        mutant = mutant.replace(before, after, 1)
    ir, patch = f"cases/{case_id}.mlir", f"cases/{case_id}.diff"
    (output / ir).parent.mkdir(parents=True, exist_ok=True)
    (output / ir).write_text(mutant, encoding="utf-8")
    diff = difflib.unified_diff(
        source.splitlines(keepends=True),
        mutant.splitlines(keepends=True),
        fromfile=baseline,
        tofile=ir,
    )
    (output / patch).write_text("".join(diff), encoding="utf-8")
    return ir, patch
