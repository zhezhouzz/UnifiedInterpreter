import argparse
import hashlib
import io
import json
import os
import tarfile
from pathlib import Path
from tempfile import TemporaryDirectory


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "unified-interpreter-benchmarks"


def main():
    parser = argparse.ArgumentParser(description="Package the offline interpreter, guide and benchmark sources.")
    parser.add_argument("executable", type=Path)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    if not args.executable.is_file() or not os.access(args.executable, os.X_OK):
        parser.error(f"expected an executable file: {args.executable}")

    catalog = json.loads((ROOT / "benchmarks/ir-pairs/catalog.json").read_text())
    args.archive.parent.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=args.archive.parent) as directory:
        output = Path(directory) / "release.tar"
        with tarfile.open(output, mode="w", dereference=True) as tar:
            tar.add(args.executable, f"{PACKAGE}/unified-interpreter")
            tar.add(ROOT / "docs/offline-executable.md", f"{PACKAGE}/offline-executable.md")
            for example in (
                "examples/kernels/vector_add_hivm.mlir",
                "examples/kernels/vector_add_hfusion.mlir",
                "examples/kernels/issue316_missing_ready_hivm.mlir",
                "benchmark/L2/cross-loop-placement/fixed.hivm.mlir",
            ):
                tar.add(ROOT / example, f"{PACKAGE}/{Path(example).name}")
            for name, versions in catalog["benchmarks"].items():
                for stage in ("hivm", "hfusion"):
                    entry = versions[stage]
                    source = (ROOT / entry["path"]).read_bytes()
                    if hashlib.sha256(source).hexdigest() != entry["sha256"]:
                        raise ValueError(f"benchmark checksum mismatch: {entry['path']}")
                    member = tarfile.TarInfo(f"{PACKAGE}/benchmarks/{name}/{stage}.mlir")
                    member.size = len(source)
                    tar.addfile(member, io.BytesIO(source))
        output.replace(args.archive)


if __name__ == "__main__":
    main()
