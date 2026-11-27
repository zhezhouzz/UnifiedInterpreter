#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
dune build --profile release bin/main.exe attention_cli/main.exe kernel_cli/main.exe

release_dir="$PWD/_build/release"
bundle="$release_dir/unified-interpreter"
test ! -e "$bundle"
mkdir -p "$bundle/bin" "$bundle/scripts" "$bundle/artifacts/flash_attention/ir"
install -m 755 _build/default/bin/main.exe "$bundle/bin/unified-interpreter"
install -m 755 _build/default/attention_cli/main.exe "$bundle/bin/attention"
install -m 755 _build/default/kernel_cli/main.exe "$bundle/bin/kernel-example"
cp scripts/attention_frontend.py scripts/attention_dialects.py scripts/mlir_frontend.py scripts/scheduler_affine.py \
  scripts/scheduler_module.py scripts/scheduler_inputs.py scripts/scheduler_device.py scripts/scheduler_scene.py \
  scripts/bootstrap_attention.sh "$bundle/scripts/"
cp requirements-attention.txt "$bundle/"
cp docs/binary-distribution.md "$bundle/README.md"
cp -R examples "$bundle/"
mkdir -p "$bundle/benchmarks"
cp -R benchmarks/hfusion benchmarks/ir-pairs benchmarks/scheduler benchmarks/hivm "$bundle/benchmarks/"
mkdir -p "$bundle/benchmark"
cp -R benchmark/L1 benchmark/L2 benchmark/licenses "$bundle/benchmark/"
cp artifacts/flash_attention/ir/hfusion_level.mlir \
  artifacts/flash_attention/ir/attention_hivm_compute.mlir \
  "$bundle/artifacts/flash_attention/ir/"

archive="unified-interpreter-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m).tar.gz"
cd "$release_dir"
tar -czf "$archive" unified-interpreter
sha256sum "$archive" > "$archive.sha256"
