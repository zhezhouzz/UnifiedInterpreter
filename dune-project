(lang dune 3.11)

(name unified_interpreter)

(generate_opam_files true)

(package
 (name unified_interpreter)
 (synopsis "A small OCaml 5 effect-based multi-level IR interpreter demo")
 (depends
  (ocaml (>= 5.0))
  dune))
