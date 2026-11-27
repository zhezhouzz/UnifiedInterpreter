# Binary distribution and Docker

## Build and run locally

Build this distribution from a configured project checkout, then verify and
extract the archive. GitHub Actions publishes the [offline executable](offline-executable.md).

```sh
opam exec -- sh scripts/package_binary.sh
cd _build/release
sha256sum --check unified-interpreter-linux-x86_64.tar.gz.sha256
tar -xzf unified-interpreter-linux-x86_64.tar.gz
cd unified-interpreter
```

The executables target Ubuntu 24.04 (glibc 2.39 or newer). Install Python 3.12
or newer, Python's venv support, and the GMP and SQLite runtimes. On Ubuntu 24.04:

```sh
sudo apt-get update
sudo apt-get install -y python3 python3-venv libgmp10 libsqlite3-0
ATTENTION_PYTHON=python3 sh scripts/bootstrap_attention.sh
bin/unified-interpreter
bin/kernel-example --kernel vector-add
bin/kernel-example --kernel row-sum
bin/attention --stage both --output reports/attention.json
bin/attention --stage mixed --ir examples/attention_mixed.mlir \
  --output reports/attention-mixed.json
```

Run these commands from the extracted directory so the default IR paths resolve.
The archive contains all three native executables, the Python/xDSL frontend,
its pinned requirements, and the example IR files. Python dependencies are
installed into `.venv-attention` by the bootstrap command. OCaml and Rocq are
build dependencies; the downloaded executables run without installing them.

To build the same archive locally, install the project's OCaml/Rocq dependencies
and execute:

```sh
opam exec --switch=unified-interpreter -- sh scripts/package_binary.sh
```

Output is written to `_build/release/`, including a SHA-256 checksum. The script
requires that `_build/release/unified-interpreter` does not already exist.
Move or remove the previous distribution directory before packaging again.

## Docker

Build the image from the repository root:

```sh
docker build -t unified-interpreter .
docker run --rm unified-interpreter
```

The Dockerfile builds with OCaml 5.3.0 and Rocq 9.1.0, runs the Dune tests,
and copies the packaged executables into an Ubuntu 24.04 runtime image.
Python/xDSL dependencies are installed during image creation. Container
execution uses a non-root user and requires no network access.

The default command executes `attention --stage both`. Pass attention options
after the image name, and mount a directory to retain results:

```sh
mkdir -p reports
docker run --rm --user "$(id -u):$(id -g)" \
  --mount "type=bind,source=$PWD/reports,target=/output" \
  unified-interpreter --stage mixed --ir examples/attention_mixed.mlir \
  --output /output/attention-mixed.json --trace /output/attention-mixed.jsonl
```

Use an explicit entry point for the other executables:

```sh
docker run --rm --entrypoint unified-interpreter unified-interpreter
docker run --rm --entrypoint kernel-example unified-interpreter --kernel row-sum
```

Mount custom input files into `/input` and pass their absolute container paths
with `--ir` or `--input`. Keep the default working directory so the bundled
examples remain available.
