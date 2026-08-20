#!/usr/bin/env bash
set -e

# Import optional host-provided corporate roots before Ollama makes TLS calls.
for cert in /opt/local-certs/*.crt /opt/local-certs/*.pem; do
    [ -f "$cert" ] || continue
    cert_name="$(basename "${cert%.*}").crt"
    cp "$cert" "/usr/local/share/ca-certificates/$cert_name"
done
update-ca-certificates >/dev/null

# ── 1. Start Ollama daemon in the background ──────────────────────────────────
OLLAMA_BIN="/usr/local/bin/ollama"

echo "[1/4] Starting Ollama service..."
"$OLLAMA_BIN" serve &
OLLAMA_PID=$!

# ── 2. Wait until the Ollama API is responsive ───────────────────────────────
echo "[1/4] Waiting for Ollama to be ready..."
WAIT=0
until "$OLLAMA_BIN" list >/dev/null 2>&1; do
    sleep 2
    WAIT=$((WAIT + 1))
    if [ "$WAIT" -ge 30 ]; then
        echo "ERROR: Ollama did not become ready within 60 seconds."
        kill "$OLLAMA_PID" 2>/dev/null || true
        exit 1
    fi
done
echo "[1/4] Ollama is ready."

# ── 3. Pull the embedding model (used by the RAG search index) ───────────────
echo "[2/4] Checking nomic-embed-text..."
if "$OLLAMA_BIN" list | awk 'NR>1{print $1}' | grep -Eq '^nomic-embed-text(:|$)'; then
    echo "[2/4] nomic-embed-text already present."
else
    echo "[2/4] Pulling nomic-embed-text (this may take a few minutes)..."
    "$OLLAMA_BIN" pull nomic-embed-text
fi

# ── 4. Create the CTF assistant model from the local Modelfile ───────────────
echo "[3/4] Checking qwen3-ctf model..."
if "$OLLAMA_BIN" list | awk 'NR>1{print $1}' | grep -Eq '^qwen3-ctf(:|$)'; then
    echo "[3/4] qwen3-ctf already present."
else
    echo "[3/4] Creating qwen3-ctf from Modelfile..."
    echo "      First run will download the base model (~1.4 GB). Please wait."
    python /app/generate_modelfile.py > /tmp/Modelfile_generated
    "$OLLAMA_BIN" create qwen3-ctf -f /tmp/Modelfile_generated
    rm -f /tmp/Modelfile_generated
fi

# ── 5. Start the application server ─────────────────────────────────────────
APP_PORT="${APP_PORT:-20001}"
echo "[4/4] Starting application server on port ${APP_PORT}..."
exec python -m uvicorn backend.server:app --host 0.0.0.0 --port "$APP_PORT"
