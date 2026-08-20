#!/usr/bin/env bash
# OWASP LLM Top10 2026 Workshop - Docker/local launcher
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT_CONFIG="$SCRIPT_DIR/backend/config.yml"
APP_PORT="$(awk '/^x-app-port:/ { gsub(/\r/, "", $3); print $3 }' "$PORT_CONFIG" | tail -n 1)"
CONTAINER_NAME="$(awk '/^x-container-name:/ { gsub(/\r/, "", $3); print $3 }' "$PORT_CONFIG" | tail -n 1)"
APP_PORT="${APP_PORT:-20001}"
CONTAINER_NAME="${CONTAINER_NAME:-LLMWorkshop_Labs}"
APP_URL="http://localhost:${APP_PORT}/labs"
MODE="${1:-auto}"
MODE="${MODE#--}"

if [[ "$MODE" != "auto" && "$MODE" != "docker" && "$MODE" != "local" ]]; then
    echo "Usage: ./launch.sh [auto|docker|local]"
    exit 2
fi

echo "OWASP LLM Top10 2026 Workshop"
echo "By - Madhu CN"
echo "=========================="
echo

open_url() {
    local url="$1"
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url" >/dev/null 2>&1 &
    elif command -v open >/dev/null 2>&1; then
        open "$url" >/dev/null 2>&1 &
    elif command -v wslview >/dev/null 2>&1; then
        wslview "$url" >/dev/null 2>&1 &
    elif command -v cmd.exe >/dev/null 2>&1; then
        cmd.exe /c start "" "$url" >/dev/null 2>&1 &
    else
        echo "Open this URL in your browser: $url"
    fi
}

app_is_ready() {
    command -v curl >/dev/null 2>&1 && curl --silent --fail --max-time 2 "$APP_URL" >/dev/null 2>&1
}

# Portable timeout for macOS, Linux, and WSL. Commands used here are read-only.
command_succeeds_with_timeout() {
    local seconds="$1"
    shift
    "$@" >/dev/null 2>&1 &
    local command_pid=$!
    local elapsed=0
    while kill -0 "$command_pid" >/dev/null 2>&1; do
        if (( elapsed >= seconds )); then
            kill "$command_pid" >/dev/null 2>&1 || true
            wait "$command_pid" >/dev/null 2>&1 || true
            return 124
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    wait "$command_pid"
}

docker_is_healthy() {
    command -v docker >/dev/null 2>&1 || return 1
    command_succeeds_with_timeout 12 docker compose version || return 1
    command_succeeds_with_timeout 12 docker info || return 1
}

wait_and_open() {
    local count=0
    while (( count < 240 )); do
        if app_is_ready; then
            echo "App is ready! Opening browser..."
            open_url "$APP_URL"
            return 0
        fi
        if (( count % 10 == 0 )); then
            echo "Waiting for the app... $((count * 3)) seconds"
        fi
        sleep 3
        count=$((count + 1))
    done
    echo "Timed out waiting for the app. Open manually: $APP_URL"
    return 1
}

find_python() {
    local candidate
    for candidate in python3.12 python3 python; do
        if command -v "$candidate" >/dev/null 2>&1 &&
           "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 12) else 1)' >/dev/null 2>&1; then
            PYTHON_BIN="$candidate"
            return 0
        fi
    done
    return 1
}

offer_python_install() {
    local answer=""
    if [[ ! -t 0 ]]; then
        return 1
    fi
    if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
        read -r -p "Python was not found. Install Python with Homebrew? [Y/n]: " answer
        [[ "$answer" =~ ^([nN]|[nN][oO])$ ]] && return 1
        brew install python@3.12 || return 1
        find_python
        return $?
    fi
    if command -v apt-get >/dev/null 2>&1; then
        read -r -p "Python was not found. Install Python 3 with apt? [Y/n]: " answer
        [[ "$answer" =~ ^([nN]|[nN][oO])$ ]] && return 1
        sudo apt-get update && sudo apt-get install -y python3 python3-venv python3-pip || return 1
        find_python
        return $?
    fi
    return 1
}

offer_ollama_install() {
    local answer=""
    echo "Ollama was not found. The official installer will be downloaded from ollama.com."
    if [[ "$(uname -r)" == *Microsoft* || "$(uname -r)" == *microsoft* ]]; then
        echo "WSL detected. You may instead run launch.bat local for a native Windows setup."
    fi
    if [[ ! -t 0 ]]; then
        return 1
    fi
    read -r -p "Download and install Ollama now? [Y/n]: " answer
    [[ "$answer" =~ ^([nN]|[nN][oO])$ ]] && return 1
    command -v curl >/dev/null 2>&1 || {
        echo "curl is required to download the Ollama installer."
        return 1
    }
    curl -fsSL https://ollama.com/install.sh | sh
}

if app_is_ready; then
    echo "The application is already running. Opening the browser..."
    open_url "$APP_URL"
    exit 0
fi

cd "$SCRIPT_DIR"

if [[ "$MODE" != "local" ]]; then
    if docker_is_healthy; then
        echo "Mode: Docker"
        echo "Building image and starting container..."
        if ! docker compose up --build -d; then
            echo
            echo "Docker is available, but the application build or startup failed."
            echo "Review the Docker output above. To bypass Docker, run: ./launch.sh local"
            exit 1
        fi
        echo
        echo "Container started. Waiting for the application to be ready..."
        echo "(First run downloads about 1.7 GB of model files and may take several minutes.)"
        echo
        wait_and_open || true
        echo "To watch startup progress:  docker logs -f $CONTAINER_NAME"
        echo "To stop the demo:           docker compose down"
        exit 0
    fi

    if [[ "$MODE" == "docker" ]]; then
        echo "Docker mode was requested, but Docker is not usable."
        echo "Verify Docker, Docker Compose, and the Docker daemon, then try again."
        exit 1
    fi

    echo "Docker is missing, stopped, or unable to reach its backend."
    echo "Switching to native local mode."
    echo
fi

echo "Mode: Native local"
echo

PYTHON_BIN=""
if ! find_python; then
    offer_python_install || true
fi
if [[ -z "$PYTHON_BIN" ]]; then
    echo "Python 3.12 is required for local mode."
    echo "Install Python 3.12 and rerun this launcher."
    exit 1
fi

"$PYTHON_BIN" scripts/prepare_local_runtime.py
PREPARE_EXIT=$?
if (( PREPARE_EXIT == 20 )); then
    if ! offer_ollama_install; then
        echo "Ollama is required for local mode."
        exit 1
    fi
    "$PYTHON_BIN" scripts/prepare_local_runtime.py
    PREPARE_EXIT=$?
fi
if (( PREPARE_EXIT != 0 )); then
    echo
    echo "Local runtime preparation failed. Review the message above and .runtime/ollama.log."
    exit "$PREPARE_EXIT"
fi

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) VENV_PYTHON="$SCRIPT_DIR/.venv/Scripts/python.exe" ;;
    *) VENV_PYTHON="$SCRIPT_DIR/.venv/bin/python" ;;
esac

if [[ ! -x "$VENV_PYTHON" ]]; then
    echo "Local Python environment was not created successfully."
    exit 1
fi

echo
echo "Starting the application on $APP_URL"
echo "Press Ctrl+C to stop the local application."
echo
wait_and_open &
WAITER_PID=$!
cleanup_waiter() {
    kill "$WAITER_PID" >/dev/null 2>&1 || true
    wait "$WAITER_PID" >/dev/null 2>&1 || true
}
trap cleanup_waiter EXIT
"$VENV_PYTHON" -m uvicorn backend.server:app --host 127.0.0.1 --port "$APP_PORT"
APP_EXIT=$?
exit "$APP_EXIT"
