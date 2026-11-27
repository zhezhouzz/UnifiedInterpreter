FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates curl git libgmp-dev libsqlite3-dev opam pkg-config \
    python3 python3-venv unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN mkdir -p /build/_build/task-tmp
ENV TMPDIR=/build/_build/task-tmp
ENV OPAMROOT=/opt/opam
ENV OPAMYES=1
ENV OPAMJOBS=2
RUN opam init --bare --disable-sandboxing --no-setup \
    && opam switch create build ocaml-base-compiler.5.3.0

COPY dune-project unified_interpreter.opam ./
RUN opam repository add coq-released https://coq.inria.fr/opam/released --switch=build \
    && opam install rocq-core.9.1.0 rocq-stdlib.9.1.0 rocq-runtime.9.1.0 rocq-stdpp.1.13.0 \
    && opam install . --deps-only --with-test

COPY requirements-attention.txt ./
COPY scripts/bootstrap_attention.sh scripts/bootstrap_attention.sh
RUN ATTENTION_PYTHON=python3 sh scripts/bootstrap_attention.sh

COPY . .
RUN opam exec -- dune runtest \
    && opam exec -- sh scripts/package_binary.sh

FROM builder AS offline-builder
RUN apt-get update && apt-get install -y --no-install-recommends busybox-static bubblewrap time \
    && rm -rf /var/lib/apt/lists/*
ENV BISHENGIR_OPT=/opt/vendor/triton/backends/ascend/bishengir/bin/bishengir-opt
RUN .venv-attention/bin/python -m pip install --no-deps --target /opt/vendor \
    --index-url https://mirrors.huaweicloud.com/ascend/repos/pypi triton-ascend==3.6.0.post2 \
    && opam exec -- .venv-attention/bin/python scripts/build_offline.py --bishengir-opt "$BISHENGIR_OPT"

FROM ubuntu:24.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libgmp10 libsqlite3-0 python3 python3-venv \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --uid 10001 --create-home interpreter

WORKDIR /opt/unified-interpreter
COPY --from=builder /build/_build/release/unified-interpreter/ ./
RUN ATTENTION_PYTHON=python3 sh scripts/bootstrap_attention.sh \
    && chown -R interpreter:interpreter /opt/unified-interpreter

ENV ATTENTION_ROOT=/opt/unified-interpreter
ENV TMPDIR=/opt/unified-interpreter/_build/task-tmp
ENV PATH=/opt/unified-interpreter/bin:$PATH
USER interpreter
ENTRYPOINT ["attention"]
CMD ["--stage", "both"]
