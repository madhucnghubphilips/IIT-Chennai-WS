# syntax=docker/dockerfile:1

FROM python:3.12-slim

# ── Stage 1: pull the verified Ollama binary from the official image ──────────
FROM ollama/ollama@sha256:4dea9fb511947e24a84237bb636b0203abcb2ff0d3fbc7b4ff865deb91362131 AS ollama-stage

# ── Stage 2: Python 3.12 application ─────────────────────────────────────────
FROM python:3.12-slim

# Copy Ollama binary + all runtime libraries (llama-server, libggml, etc.)
COPY --from=ollama-stage /usr/bin/ollama      /usr/local/bin/ollama
COPY --from=ollama-stage /usr/lib/ollama      /usr/lib/ollama

# Symlink the lib directory to where Ollama searches relative to its binary
RUN mkdir -p /usr/local/lib/ollama \
    && ln -sf /usr/lib/ollama/llama-server /usr/local/lib/ollama/llama-server

ENV LD_LIBRARY_PATH=/usr/lib/ollama

# ── System CA certificates ────────────────────────────────────────────────────
# Optional corporate roots are mounted and imported by entrypoint.sh.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates

WORKDIR /app

# ── Python dependencies (cached layer) ───────────────────────────────────────
COPY backend/requirements.txt ./requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

# ── Application source ────────────────────────────────────────────────────────
COPY backend/  ./backend/
COPY frontend/ ./frontend/

# ── Entrypoint: starts Ollama, pulls models, then launches uvicorn ────────────
COPY entrypoint.sh ./entrypoint.sh
COPY generate_modelfile.py ./generate_modelfile.py
RUN sed -i 's/\r$//' ./entrypoint.sh \
    && chmod +x ./entrypoint.sh

# Persist downloaded Ollama models across container restarts
VOLUME ["/root/.ollama"]

ENTRYPOINT ["./entrypoint.sh"]
