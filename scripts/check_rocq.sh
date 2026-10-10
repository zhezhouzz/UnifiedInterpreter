#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

switch=${ROCQ_OPAM_SWITCH:-with-rocq-1}
files="
rocq/Base/Result.v
rocq/Base/Lens.v
rocq/Base/StateM.v
rocq/Value/DType.v
rocq/Value/Scalar.v
rocq/Memory/Model.v
rocq/Unified/Events.v
rocq/Unified/State.v
rocq/HFusion/Instructions.v
rocq/Examples/FrameworkSmoke.v
"

for file in $files; do
  opam exec --switch="$switch" -- rocq compile \
    -Q rocq UnifiedInterpreter "$file"
done

mkdir -p _build/rocq
opam exec --switch="$switch" -- rocq compile \
  -Q rocq UnifiedInterpreter rocq/Extraction/Extract.v

(
  cd _build/rocq
  opam exec --switch="$switch" -- ocamlc -c unified_semantics.mli
  opam exec --switch="$switch" -- ocamlc -c unified_semantics.ml
)
