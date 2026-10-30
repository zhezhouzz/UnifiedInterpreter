#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p _build/task-tmp _build/pip-cache
export TMPDIR="$PWD/_build/task-tmp"
export PIP_CACHE_DIR="$PWD/_build/pip-cache"
export TRITON_CACHE_DIR="$PWD/_build/triton-cache"
compiler_python=${TRITON_PYTHON:-python3.10}
environment=_build/kernel-compiler
if [ ! -x "$environment/bin/python" ]; then
  "$compiler_python" -m venv "$environment"
fi
"$environment/bin/python" -m pip install -r requirements-kernel-compiler.txt
"$environment/bin/python" scripts/compile_kernel_ir.py
sh scripts/bootstrap_attention.sh
.venv-attention/bin/python scripts/prepare_kernel_ir.py
"$environment/bin/python" scripts/compile_kernel_ir.py --verify-examples
