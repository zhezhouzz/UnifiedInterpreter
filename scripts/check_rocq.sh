#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

switch=${ROCQ_OPAM_SWITCH:-with-rocq-1}
python3 scripts/check_hivm_scope.py
printf '%s\n' "Building with Rocq's native generated Makefile..."
opam exec --switch="$switch" -- make -C rocq -f Makefile all

(
  cd rocq/Extraction
  opam exec --switch="$switch" -- ocamlc -c unified_semantics.mli
  opam exec --switch="$switch" -- ocamlc -c unified_semantics.ml
)

printf '%s\n' "Native Rocq build and OCaml extraction succeeded."

# Keep compiled driver artifacts out of test/ and never link the hand-written
# interpreter into this check: these calls must exercise the extracted code.
mkdir -p _build/extracted-hivm
cp scripts/check_extracted_hivm.ml _build/extracted-hivm/check_extracted_hivm.ml
opam exec --switch="$switch" -- ocamlc -w -20-26 \
  -I rocq/Extraction rocq/Extraction/unified_semantics.cmo \
  _build/extracted-hivm/check_extracted_hivm.ml \
  -o _build/extracted-hivm/check_extracted_hivm.exe
_build/extracted-hivm/check_extracted_hivm.exe
