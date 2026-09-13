#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VENV="$ROOT/.venv-tools"

python3 -m venv "$VENV"
"$VENV/bin/python" -m pip install --upgrade pip
"$VENV/bin/python" -m pip install xdsl triton

cat <<MSG
Installed optional external-route tools into:
  $VENV

Use them with:
  . "$VENV/bin/activate"
  dune exec ./bin/main.exe
MSG
