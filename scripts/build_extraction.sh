#!/bin/sh
# Run from Dune's build directory; never compile into the source checkout.
set -eu
source_dir=$1
mkdir -p rocq-build
cp "$source_dir/_CoqProject" rocq-build/_CoqProject
while IFS= read -r path; do
  case "$path" in
    *.v)
      mkdir -p "rocq-build/$(dirname "$path")"
      cp "$source_dir/$path" "rocq-build/$path"
      ;;
  esac
done < "$source_dir/_CoqProject"
(
  cd rocq-build
  rocq makefile -f _CoqProject -o Makefile
  make -s -f Makefile all
)
cp rocq-build/Extraction/unified_semantics.ml .
cp rocq-build/Extraction/unified_semantics.mli .
