#!/usr/bin/env python3
"""Inventory guard, not an MLIR parser or a semantic-equivalence checker."""
from collections import Counter
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
artifact = ROOT / "artifacts/flash_attention/ir/attention_hivm_compute.mlir"
text = artifact.read_text()
observed = Counter(re.findall(
    r"(?<![\w#])\b((?:arith|tensor|memref|bufferization|hivm|func|scf)\.[\w.]+)\b",
    text,
))
observed["func.return"] = len(re.findall(r"^\s*return\s*$", text, re.MULTILINE))
expected = {
    "arith.constant", "arith.addi", "arith.muli", "arith.divsi", "arith.remsi",
    "arith.extsi", "arith.index_cast", "tensor.empty", "tensor.expand_shape",
    "tensor.collapse_shape", "memref.alloc", "memref.copy", "memref.reinterpret_cast",
    "bufferization.to_tensor", "bufferization.materialize_in_destination",
    "func.func", "func.return", "scf.for",
} | {f"hivm.hir.{op}" for op in (
    "vadd", "vsub", "vmul", "vdiv", "vexp", "vln", "vbrc", "vreduce", "vcast", "mmadL1"
)}
if set(observed) != expected or not all(observed.values()):
    raise SystemExit(f"Compute scope changed: added={set(observed)-expected}, "
                     f"missing={expected-set(observed)}")
coverage = (ROOT / "docs/hivm-compute-semantics.md").read_text()
for op in sorted(expected):
    if f"`{op}`" not in coverage:
        raise SystemExit(f"Missing documented operation: {op}")
print(f"HIVM scope: {len(expected)} operation kinds, including 10 HIVM compute primitives.")
