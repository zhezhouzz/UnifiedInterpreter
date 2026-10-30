#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p _build/task-tmp reports/compiled-kernels
export TMPDIR="$PWD/_build/task-tmp"
opam exec --switch="${KERNEL_OPAM_SWITCH:-unified-interpreter}" -- dune build attention_cli/main.exe kernel_cli/main.exe
for stage in hfusion hivm; do
  _build/default/attention_cli/main.exe --stage "$stage" \
    --ir "artifacts/kernels/_attn_fwd.$stage.mlir" \
    --output "reports/compiled-kernels/attention-$stage.json"
  for length in 0 1 255 256 257 512 513 777; do
    _build/default/kernel_cli/main.exe --kernel vector-add --stage "$stage" \
      --ir "artifacts/kernels/add_kernel.$stage.mlir" --length "$length" \
      --output "reports/compiled-kernels/vector-add-$stage-$length.json"
  done
done
for kernel in vector-add row-sum; do
  for stage in hfusion hivm mixed; do
    _build/default/kernel_cli/main.exe --kernel "$kernel" --stage "$stage" \
      --output "reports/compiled-kernels/$kernel-static-$stage.json"
  done
done
