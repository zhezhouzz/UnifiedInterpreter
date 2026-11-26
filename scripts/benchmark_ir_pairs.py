import argparse
from hashlib import sha256
import json
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory
from zipfile import ZipFile

from export_catalog_ast import REVISION
from export_vectorlayout_ast import DIGESTS
from project_hfusion_ir import compile_ir, project


ROOT = Path(__file__).resolve().parents[1]
PAIRS = Path("benchmarks/ir-pairs")
INDEX = PAIRS / "catalog.json"
FORWARD = "--convert-hfusion-to-hivm"
CV_FORWARD = FORWARD + "=mm-map-mode=macro_instr"
SCENE = {"correct": "2a3cf05a6ddbf7043d2055701426c3f5bce90be3b94c84b689580b6386141937",
         "error": "6fa7864c33735b1cb35f5d7844324fcb59fec23cff9f95be79bce61943fd4617"}
EXISTING = {"fixture/hivm-two-loads": "two_loads", "issue316/ordered": "issue316_vexp",
            "issue316/missing-ready": "issue316_missing_ready"}


def digest(data):
    return sha256(data).hexdigest()


def record(path, data):
    return {"path": str(path), "sha256": digest(data)}


def read(path, staging=None):
    if staging is not None and (staging / path).is_file():
        return (staging / path).read_bytes()
    return (ROOT / path).read_bytes()


def store(staging, path, data):
    dest = staging / path
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    return record(path, data)


def scheduler_catalog(exe):
    def entries(*flags):
        return json.loads(subprocess.check_output([exe, "race", "list", "--json", *flags], cwd=ROOT))
    return {e["name"]: e for e in entries()}, {e["name"]: e for e in entries("--hfusion") if e["native_catalog"]}


def section(log, marker):
    # 仅识别 BiShengIR 的日志边界，快照内的 MLIR 交给编译器解析。
    header = b"// -----// IR Dump "
    snapshot = []
    collecting = False
    for line in log.splitlines(keepends=True):
        if line.startswith(header):
            if collecting:
                break
            collecting = line.startswith(header + marker.encode() + b" ")
        elif collecting:
            if line.startswith(b"[PassID]"):
                break
            snapshot.append(line)
    if not snapshot:
        raise ValueError(f"missing compiler snapshot: {marker}")
    return b"".join(snapshot)


def cv_pair(opts, name, staging):
    family, variant = name.rsplit("/", 1)
    source = {}
    high_marker = "Before ConvertHFusionToHIVM"
    if family == "vectorlayout":
        dump, = opts.layout_dumps.glob(f"*-{variant}.mlir")
        log = dump.read_bytes()
        expected = DIGESTS[variant]
        source["member"] = dump.name
        low = Path(f"benchmarks/hivm/vectorlayout_{variant}.mlir")
        source["hivm_snapshot"] = "GraphSyncSolver / AnalyzeVectorLayout"
    else:
        member = variant + ".log"
        with ZipFile(opts.scene_zip) as archive:
            log = archive.read(member)
        expected = SCENE[variant]
        source["member"] = member
        if variant == "error":
            high_marker = "After ConvertProtonToHIVM"
        low_marker = ("Before ConvertHIVMToStandard" if variant == "correct"
                      else "After InsertFreeLockVarBeforeReturn")
        low = PAIRS / name / "hivm.mlir"
        source["hivm_snapshot"] = low_marker
    if digest(log) != expected:
        raise ValueError(f"{name}: unexpected compiler dump")
    if family != "vectorlayout":
        store(staging, low, compile_ir(opts.opt, section(log, low_marker)))
    high = compile_ir(opts.opt, section(log, high_marker))
    boundary = compile_ir(opts.opt, section(log, "After ConvertHFusionToHIVM"))
    source.update(member_sha256=expected, hfusion_snapshot=high_marker,
                  after_convert_hfusion_to_hivm_sha256=digest(boundary))
    return {"origin": "compiler-dump", "source": source,
            "hfusion": store(staging, PAIRS / name / "hfusion.mlir", high),
            "hivm": record(low, read(low, staging))}


def generate(opts, low_cases, high_cases, staging):
    cases = {}
    litao = Path("benchmarks/litao")
    dirs = {json.loads(f.read_bytes())["id"]: f.parent.relative_to(ROOT / litao)
            for f in (ROOT / litao).rglob("case.json")}

    def original(path):
        return subprocess.check_output(["git", "-C", opts.litao_repo, "show", f"{REVISION}:{path}"])

    for name in sorted(set(low_cases) | set(high_cases) | {f"cv/scene1/{v}" for v in SCENE}):
        if name.startswith(("vectorlayout/", "cv/scene1/")):
            case = cv_pair(opts, name, staging)
        elif name in high_cases:
            path = high_cases[name]["ir"]
            high = read(path)
            lowered = compile_ir(opts.opt, high, FORWARD)
            if name == "vector-add":
                low = Path("examples/kernels/vector_add_hivm.mlir")
                if compile_ir(opts.opt, read(low)) != lowered:
                    raise ValueError(f"{name}: compiler output changed")
                result = record(low, read(low))
            else:
                result = store(staging, PAIRS / name / "hivm.mlir", lowered)
            case = {"origin": "forward", "hfusion": record(path, high), "hivm": result}
        else:
            source = {}
            if name in EXISTING:
                low = Path(f"examples/kernels/{EXISTING[name]}_hivm.mlir")
                data = read(low)
            else:
                low = PAIRS / name / "hivm.mlir"
                if name.startswith("litao/"):
                    _, kernel, variant = name.split("/")
                    path = Path("benchmark") / dirs[kernel] / f"{variant}.hivm.mlir"
                    data = original(path)
                    source = {"revision": REVISION, "hivm_path": str(path)}
                else:
                    data = subprocess.check_output([opts.exe, "race", "source", name], cwd=ROOT)
                ast = json.loads(read(low_cases[name]["hivm_ast"]))
                if digest(data) != ast["source_sha256"]:
                    raise ValueError(f"{name}: HIVM source differs from scheduler AST")
                store(staging, low, data)
            if name.startswith("litao/add-Ascend910B1/"):
                path = Path("benchmark") / dirs[kernel] / "source.mlir"
                source["hfusion_path"] = str(path)
                high = original(path)
                result = store(staging, PAIRS / "litao/add-Ascend910B1/hfusion.mlir", high)
                case = {"origin": "compiler-source", "hfusion": result}
            else:
                high, bindings = project(opts.opt, data, name)
                case = {"origin": "computation-projection",
                        "hfusion": store(staging, PAIRS / name / "hfusion.mlir", high)}
                if bindings:
                    case["extra_arguments"] = bindings
            case["hivm"] = record(low, data)
            if source:
                case["source"] = source
        cases[name] = case
    return cases


def verify(opts, cases, low_cases, high_cases, staging=None):
    expected = set(low_cases) | set(high_cases) | {f"cv/scene1/{v}" for v in SCENE}
    if set(cases) != expected:
        raise ValueError(f"catalog mismatch: {sorted(expected ^ set(cases))}")
    for name, case in cases.items():
        def stage(key):
            item = case[key]
            data = read(item["path"], staging)
            if digest(data) != item["sha256"]:
                raise ValueError(f"{name}: {key} digest mismatch")
            return data
        high, low = stage("hfusion"), stage("hivm")
        is_dump = case["origin"] == "compiler-dump"
        compiled = compile_ir(opts.opt, high, CV_FORWARD if is_dump else FORWARD)
        device = compile_ir(opts.opt, low)
        if is_dump and digest(compiled) != case["source"]["after_convert_hfusion_to_hivm_sha256"]:
            raise ValueError(f"{name}: lowering differs from the archived conversion")
        if case["origin"] == "forward" and device != compiled:
            raise ValueError(f"{name}: HIVM differs from the HFusion lowering")
        if case["origin"] == "computation-projection":
            regenerated, bindings = project(opts.opt, low, name)
            if regenerated != high or bindings != case.get("extra_arguments", {}):
                raise ValueError(f"{name}: HFusion computation or arguments differ")
        print(name, flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["generate", "check"])
    parser.add_argument("--opt", default="bishengir-opt")
    parser.add_argument("--exe", type=Path, default=ROOT / "_build/default/bin/main.exe")
    parser.add_argument("--litao-repo", type=Path, default=ROOT)
    parser.add_argument("--scene-zip", type=Path)
    parser.add_argument("--layout-dumps", type=Path)
    opts = parser.parse_args()
    opts.exe = opts.exe.resolve()
    if opts.action == "generate" and (not opts.scene_zip or not opts.layout_dumps):
        parser.error("generate requires --scene-zip and --layout-dumps")
    low, high = scheduler_catalog(opts.exe)
    if opts.action == "generate":
        with TemporaryDirectory(dir=ROOT / "_build", prefix="ir-pairs-") as directory:
            staging = Path(directory)
            cases = generate(opts, low, high, staging)
            verify(opts, cases, low, high, staging)
            version = subprocess.check_output([opts.opt, "--version"], text=True).splitlines()
            doc = {"compiler": [line.strip() for line in version[:2]], "benchmarks": cases}
            store(staging, INDEX, (json.dumps(doc, indent=2, ensure_ascii=False) + "\n").encode())
            for f in [*staging.rglob("*.mlir"), staging / INDEX]:
                dest = ROOT / f.relative_to(staging)
                dest.parent.mkdir(parents=True, exist_ok=True)
                f.replace(dest)
    else:
        cases = json.loads(read(INDEX))["benchmarks"]
        verify(opts, cases, low, high)
    print(f"{len(cases)} verified HFusion/HIVM pairs")


if __name__ == "__main__":
    main()
