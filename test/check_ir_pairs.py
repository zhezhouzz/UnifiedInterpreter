from hashlib import sha256
import json
from pathlib import Path
import subprocess
import sys


exe = Path(sys.argv[1]).resolve()
root = Path(__file__).resolve().parents[1]


def race(*args):
    return subprocess.check_output([exe, "race", *args], cwd=root, text=True)


cases = json.loads(race("pairs", "--json"))
required = set(race("list").splitlines()) | {"vector-add","row-sum","flash-attention","strided-output"}
required.update(["cv/scene1/correct", "cv/scene1/error"])
if set(cases) != required:
    raise ValueError(f"unpaired benchmarks: {sorted(set(cases) ^ required)}")
for stage in ("hfusion", "hivm"):
    if set(race("list", "--"+stage).splitlines()) != required:
        raise ValueError(f"incomplete {stage} scheduler catalog")
for name, case in cases.items():
    if name.startswith("litao/"):
        hivm = Path(case["hivm"]["path"])
        if hivm.parts[0] != "benchmark" or str(hivm) != case["source"]["hivm_path"]:
            raise ValueError(f"{name}: HIVM must use the original Litao file")
        original = json.loads((root / hivm.with_name("case.json")).read_bytes())
        _, case_id, variant = name.split("/")
        if original["id"] != case_id or hivm.name != f"{variant}.hivm.mlir":
            raise ValueError(f"{name}: incorrect Litao variant")
        if case["origin"] == "compiler-source" and case["hfusion"]["path"] != case["source"]["hfusion_path"]:
            raise ValueError(f"{name}: HFusion must use the original compiler input")
        if case["origin"] == "computation-projection" and Path(case["hfusion"]["path"]) != hivm.with_name(f"{variant}.hfusion.mlir"):
            raise ValueError(f"{name}: HFusion must be stored with its HIVM variant")
    for stage in ("hfusion", "hivm"):
        file = case[stage]
        if sha256((root / file["path"]).read_bytes()).hexdigest() != file["sha256"]:
            raise ValueError(f"{name}: {stage} digest mismatch")
for name in ("cv/scene1/correct", "cv/scene1/error"):
    case = cases[name]
    expected = [name, case["hfusion"]["path"], case["hivm"]["path"]]
    if race("pairs", name).rstrip("\n").split("\t") != expected:
        raise ValueError(f"{name}: incorrect file selection")
