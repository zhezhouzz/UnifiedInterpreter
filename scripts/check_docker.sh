#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
image=$1
mkdir -p reports
docker run --rm --entrypoint unified-interpreter "$image"
docker run --rm --entrypoint kernel-example "$image" --kernel vector-add
docker run --rm --entrypoint kernel-example "$image" --kernel row-sum
docker run --rm --entrypoint kernel-example "$image" --kernel vector-add --stage mixed
docker run --rm --entrypoint kernel-example "$image" --kernel row-sum --stage mixed
docker run --rm --user "$(id -u):$(id -g)" \
  --mount "type=bind,source=$PWD/reports,target=/output" "$image" \
  --stage both --output /output/attention.json --trace /output/attention.jsonl
python3 scripts/check_attention_output.py
docker run --rm --user "$(id -u):$(id -g)" \
  --mount "type=bind,source=$PWD/reports,target=/output" "$image" \
  --stage mixed --ir examples/attention_mixed.mlir \
  --output /output/attention-mixed.json --trace /output/attention-mixed.jsonl
python3 scripts/check_attention_mixed_output.py
