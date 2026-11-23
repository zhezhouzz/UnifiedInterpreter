"""Build an isolated reader against the exact dialect registry of a Ninja AscendNPU-IR build."""
import argparse
import json
from pathlib import Path
import shlex
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("build", type=Path, help="Configured AscendNPU-IR Ninja build with compile_commands.json")
parser.add_argument("output", type=Path)
args = parser.parse_args()
build = args.build.resolve()
output = args.output.resolve()
source = Path(__file__).with_name("ir.cpp").resolve()
entry = next(e for e in json.loads((build / "compile_commands.json").read_text())
             if e["file"].endswith("/bishengir-opt/bishengir-opt.cpp"))
commands = subprocess.check_output(["ninja", "-C", build, "-t", "commands", "bishengir-opt"], text=True)
# Ninja's actual link line includes the configured LLVM and BiShengIR plugin libraries.
# Extract the compiler invocation as argv, without executing other shell commands.
words = shlex.split(commands.splitlines()[-1])
start = next(i for i, word in enumerate(words) if Path(word).name.endswith(("c++", "g++", "clang++")))
link = words[start:]
if "&&" in link:
    link = link[:link.index("&&")]
with tempfile.TemporaryDirectory() as tmp:
    obj = str(Path(tmp) / "reader.o")
    compile_args = shlex.split(entry["command"])
    compile_args[compile_args.index("-o") + 1] = obj
    compile_args[compile_args.index("-c") + 1] = str(source)
    subprocess.run(compile_args, cwd=entry["directory"], check=True)
    index = next(i for i, word in enumerate(link) if word.endswith("/bishengir-opt.cpp.o"))
    link[index] = obj
    link[link.index("-o") + 1] = str(output)
    subprocess.run(link, cwd=build, check=True)
