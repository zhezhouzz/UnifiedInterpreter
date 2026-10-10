#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

switch=${ROCQ_OPAM_SWITCH:-with-rocq-1}
printf '%s\n' "Building with Rocq's native generated Makefile..."
opam exec --switch="$switch" -- make -C rocq -f Makefile all

(
  cd rocq/Extraction
  opam exec --switch="$switch" -- ocamlc -c unified_semantics.mli
  opam exec --switch="$switch" -- ocamlc -c unified_semantics.ml
)

printf '%s\n' "Native Rocq build and OCaml extraction succeeded."
