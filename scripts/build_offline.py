import argparse
import hashlib
import os
import platform
import shutil
import subprocess
import sys
import sysconfig
import tarfile
import tempfile
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bishengir-opt", required=True, type=Path)
    parser.add_argument("--output", type=Path, default=Path("_build/offline/unified-interpreter"))
    args = parser.parse_args()
    if platform.machine() != "x86_64" or sys.platform != "linux":
        parser.error("build on Linux x86_64")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=args.output.parent) as work:
        work = Path(work)
        root = work / "payload"
        py = root / ".venv-attention"
        (py / "bin").mkdir(parents=True)
        shutil.copy2(sys.executable, py / "bin/python")
        lib = py / "lib" / f"python{sys.version_info.major}.{sys.version_info.minor}"
        shutil.copytree(sysconfig.get_path("stdlib"), lib, ignore=shutil.ignore_patterns(
            "site-packages", "dist-packages", "__pycache__", "test", "idlelib", "tkinter"))
        shutil.copytree(sysconfig.get_path("purelib"), lib / "site-packages", ignore=shutil.ignore_patterns(
            "__pycache__", "pip", "pip-*.dist-info"))
        shutil.copy2("_build/default/bin/main.exe", root / "interpreter")
        profiles = Path("benchmarks/scheduler/launch-profiles.json")
        (root / profiles.parent).mkdir(parents=True)
        shutil.copy2(profiles, root / profiles)
        shutil.copy2(args.bishengir_opt, root / "bishengir-opt")
        vendor = args.bishengir_opt.resolve().parents[5]
        for license_file in vendor.glob("triton*dist-info/licenses/*"):
            if license_file.is_file():
                shutil.copy2(license_file, root / (license_file.parent.parent.name + "-" + license_file.name))
        (root / "scripts").mkdir()
        for name in ("mlir_frontend", "scheduler_affine", "attention_dialects", "attention_frontend"):
            shutil.copy2(f"scripts/{name}.py", root / "scripts")
        libs = root / "libs"
        libs.mkdir()
        glibc = {"libc.so.6", "libm.so.6", "libpthread.so.0", "libdl.so.2", "librt.so.1",
                 "libutil.so.1", "libresolv.so.2", "libanl.so.1"}
        binaries = [Path(sys.executable).resolve(), Path("_build/default/bin/main.exe"), args.bishengir_opt]
        binaries.extend(Path(sysconfig.get_path("platstdlib")).glob("lib-dynload/*.so"))
        binaries.extend(Path(sysconfig.get_path("stdlib")).glob("lib-dynload/*.so"))
        for binary in set(binaries):
            for line in subprocess.check_output(["ldd", binary], text=True).splitlines():
                fields = line.split()
                if len(fields) >= 3 and fields[1] == "=>" and fields[0] not in glibc:
                    dest = libs / fields[0]
                    if not dest.exists():
                        shutil.copy2(fields[2], dest)
        archive = work / "payload.tar.gz"
        with tarfile.open(archive, "w:gz", compresslevel=2) as tar:
            tar.add(root, arcname=".")
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        output = work / "launcher"
        site_packages = (lib / "site-packages").relative_to(root)
        subprocess.run(["cc", "-O2", f'-DSITE_PACKAGES="{site_packages}"', f'-DPAYLOAD_HASH="{digest}"', f"-DPAYLOAD_SIZE={archive.stat().st_size}L",
                        "release/launcher.c", "-o", output], check=True)
        with output.open("ab") as dest, archive.open("rb") as src:
            shutil.copyfileobj(src, dest)
        os.replace(output, args.output)


if __name__ == "__main__":
    main()
