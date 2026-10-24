#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p _build/task-tmp _build/pip-cache reports
export TMPDIR="$PWD/_build/task-tmp"
export PIP_CACHE_DIR="$PWD/_build/pip-cache"
python_command=${ATTENTION_PYTHON:-python3.12}
if [ ! -x .venv-attention/bin/python ]; then
  "$python_command" -m venv .venv-attention
fi
.venv-attention/bin/python -m pip install -r requirements-attention.txt
