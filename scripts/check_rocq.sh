#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

switch=${ROCQ_OPAM_SWITCH:-with-rocq-1}
python3 scripts/check_hivm_scope.py
printf '%s\n' "Building with Rocq's native generated Makefile..."
opam exec --switch="$switch" -- make -C rocq -f Makefile all

printf '%s\n' "Verifying Derived CoreLanguage proofs with rocqchk (kernel checker)..."
opam exec --switch="$switch" -- sh -c 'cd rocq && rocqchk -silent -Q . UnifiedInterpreter \
  UnifiedInterpreter.CoreLanguage.Derived.Refocusing \
  UnifiedInterpreter.CoreLanguage.Derived.Automaton \
  UnifiedInterpreter.CoreLanguage.Derived.CoreEffects \
  UnifiedInterpreter.CoreLanguage.Derived.Handlers \
  UnifiedInterpreter.CoreLanguage.Derived.Soundness \
  UnifiedInterpreter.CoreLanguage.Derived.Completeness \
  UnifiedInterpreter.CoreLanguage.Derived.DerivedExamples \
  UnifiedInterpreter.CoreLanguage.Derived.ProofAudit'

printf '%s\n' "Auditing top-level theorem assumptions (ProofAudit.v)..."
audit_out=$(opam exec --switch="$switch" -- sh -c 'cd rocq && rocq compile -Q . UnifiedInterpreter CoreLanguage/Derived/ProofAudit.v')
if printf '%s\n' "$audit_out" | grep -qv '^Closed under the global context$'; then
  printf '%s\n' "ProofAudit failed: unexpected assumptions found:" >&2
  printf '%s\n' "$audit_out" >&2
  exit 1
fi

(
  cd rocq/Extraction
  opam exec --switch="$switch" -- ocamlfind ocamlc -package rocq-runtime.kernel -c unified_semantics.mli
  opam exec --switch="$switch" -- ocamlfind ocamlc -package rocq-runtime.kernel -c unified_semantics.ml
  opam exec --switch="$switch" -- ocamlc -w -a -c derived_core_interpreter.mli
  opam exec --switch="$switch" -- ocamlc -w -a -c derived_core_interpreter.ml
)

printf '%s\n' "Native Rocq build, rocqchk, ProofAudit, and OCaml extraction succeeded."

# Keep compiled driver artifacts out of test/ and never link the hand-written
# interpreter into this check: these calls must exercise the extracted code.
mkdir -p _build/extracted-hivm
cp scripts/check_extracted_hivm.ml _build/extracted-hivm/check_extracted_hivm.ml
opam exec --switch="$switch" -- ocamlfind ocamlc -package rocq-runtime.kernel -linkpkg -w -20-26 \
  -I rocq/Extraction rocq/Extraction/unified_semantics.cmo \
  _build/extracted-hivm/check_extracted_hivm.ml \
  -o _build/extracted-hivm/check_extracted_hivm.exe
opam exec --switch="$switch" -- _build/extracted-hivm/check_extracted_hivm.exe

mkdir -p _build/extracted-derived
cp scripts/check_extracted_derived.ml _build/extracted-derived/check_extracted_derived.ml
opam exec --switch="$switch" -- ocamlc -w -20-26 \
  -I rocq/Extraction rocq/Extraction/derived_core_interpreter.cmo \
  _build/extracted-derived/check_extracted_derived.ml \
  -o _build/extracted-derived/check_extracted_derived.exe
opam exec --switch="$switch" -- _build/extracted-derived/check_extracted_derived.exe
