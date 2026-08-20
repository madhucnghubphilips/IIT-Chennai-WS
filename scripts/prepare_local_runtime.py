#!/usr/bin/env python3
"""Prepare the native Python and Ollama runtime used by the launch scripts."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
VENV_DIR = PROJECT_ROOT / ".venv"
RUNTIME_DIR = PROJECT_ROOT / ".runtime"
REQUIREMENTS = PROJECT_ROOT / "backend" / "requirements.txt"
MODELFILE_GENERATOR = PROJECT_ROOT / "generate_modelfile.py"
OLLAMA_API = "http://127.0.0.1:11434"
REQUIRED_IMPORTS = ("fastapi", "uvicorn", "httpx", "faiss", "numpy", "cryptography", "PIL")
OLLAMA_MISSING = 20


def venv_python() -> Path:
    if os.name == "nt":
        return VENV_DIR / "Scripts" / "python.exe"
    return VENV_DIR / "bin" / "python"


def run(command: list[str], *, check: bool = True, **kwargs: object) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, cwd=PROJECT_ROOT, check=check, **kwargs)


def find_ollama() -> Path | None:
    configured = os.environ.get("OLLAMA_BIN")
    candidates: list[Path] = []
    if configured:
        candidates.append(Path(configured).expanduser())
    discovered = shutil.which("ollama")
    if discovered:
        candidates.append(Path(discovered))
    if os.name == "nt":
        local_app_data = os.environ.get("LOCALAPPDATA")
        if local_app_data:
            candidates.append(Path(local_app_data) / "Programs" / "Ollama" / "ollama.exe")
    else:
        candidates.extend(
            (
                Path("/usr/local/bin/ollama"),
                Path("/usr/bin/ollama"),
                Path("/Applications/Ollama.app/Contents/Resources/ollama"),
            )
        )
    return next((path for path in candidates if path.is_file()), None)


def ollama_tags() -> dict[str, object] | None:
    try:
        with urllib.request.urlopen(f"{OLLAMA_API}/api/tags", timeout=3) as response:
            if response.status != 200:
                return None
            payload = json.load(response)
            return payload if isinstance(payload, dict) else None
    except (OSError, urllib.error.URLError, ValueError):
        return None


def model_is_installed(tags: dict[str, object] | None, model: str) -> bool:
    if not tags:
        return False
    models = tags.get("models", [])
    if not isinstance(models, list):
        return False
    for item in models:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or item.get("model") or "")
        if name == model or name.startswith(f"{model}:"):
            return True
    return False


def start_ollama(ollama: Path) -> bool:
    RUNTIME_DIR.mkdir(exist_ok=True)
    log_path = RUNTIME_DIR / "ollama.log"
    log_file = log_path.open("ab")
    kwargs: dict[str, object] = {
        "cwd": PROJECT_ROOT,
        "stdin": subprocess.DEVNULL,
        "stdout": log_file,
        "stderr": subprocess.STDOUT,
    }
    if os.name == "nt":
        kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS
    else:
        kwargs["start_new_session"] = True
    try:
        process = subprocess.Popen([str(ollama), "serve"], **kwargs)
    except OSError as exc:
        print(f"Unable to start Ollama: {exc}")
        return False
    finally:
        log_file.close()

    (RUNTIME_DIR / "ollama.pid").write_text(str(process.pid), encoding="utf-8")
    print("[1/5] Starting Ollama and waiting for its local API...")
    for _ in range(30):
        if ollama_tags() is not None:
            print("[1/5] Ollama is ready.")
            return True
        if process.poll() is not None:
            print(f"Ollama exited during startup. See {log_path}")
            return False
        time.sleep(2)
    print(f"Ollama did not become ready within 60 seconds. See {log_path}")
    return False


def ensure_ollama() -> Path | None:
    ollama = find_ollama()
    if ollama is None:
        print("Ollama is not installed or could not be found on PATH.")
        return None
    if ollama_tags() is not None:
        print("[1/5] Ollama is already running.")
        return ollama
    return ollama if start_ollama(ollama) else None


def dependencies_are_importable(python: Path) -> bool:
    imports = "; ".join(f"import {module}" for module in REQUIRED_IMPORTS)
    result = run([str(python), "-c", imports], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return result.returncode == 0


def python_is_312(python: Path) -> bool:
    result = run(
        [str(python), "-c", "import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 12) else 1)"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def ensure_python_environment() -> Path:
    python = venv_python()
    if not python.is_file():
        print("[2/5] Creating the local Python environment...")
        run([sys.executable, "-m", "venv", str(VENV_DIR)])
    elif not python_is_312(python):
        raise RuntimeError(
            f"{VENV_DIR} was created with another Python version. "
            "Move or remove that environment, then rerun the launcher with Python 3.12."
        )

    requirements_hash = hashlib.sha256(REQUIREMENTS.read_bytes()).hexdigest()
    stamp_path = RUNTIME_DIR / "requirements.sha256"
    installed_hash = stamp_path.read_text(encoding="utf-8").strip() if stamp_path.exists() else ""
    if installed_hash != requirements_hash or not dependencies_are_importable(python):
        print("[2/5] Installing Python dependencies...")
        run([str(python), "-m", "pip", "install", "--disable-pip-version-check", "-r", str(REQUIREMENTS)])
        stamp_path.write_text(requirements_hash, encoding="utf-8")
    else:
        print("[2/5] Python dependencies are already installed.")
    return python


def ensure_embedding_model(ollama: Path) -> None:
    if model_is_installed(ollama_tags(), "nomic-embed-text"):
        print("[3/5] nomic-embed-text is already installed.")
        return
    print("[3/5] Downloading nomic-embed-text...")
    run([str(ollama), "pull", "nomic-embed-text"])


def generated_modelfile(python: Path) -> bytes:
    completed = run([str(python), str(MODELFILE_GENERATOR)], stdout=subprocess.PIPE)
    return completed.stdout


def ensure_chat_model(ollama: Path, python: Path) -> None:
    content = generated_modelfile(python)
    current_hash = hashlib.sha256(content).hexdigest()
    stamp_path = RUNTIME_DIR / "qwen3-ctf.sha256"
    installed_hash = stamp_path.read_text(encoding="utf-8").strip() if stamp_path.exists() else ""
    installed = model_is_installed(ollama_tags(), "qwen3-ctf")

    if installed and (not installed_hash or installed_hash == current_hash):
        stamp_path.write_text(current_hash, encoding="utf-8")
        print("[4/5] qwen3-ctf is already installed.")
        return

    if installed:
        print("[4/5] The model definition changed; rebuilding qwen3-ctf...")
    else:
        print("[4/5] Creating qwen3-ctf (the base model is downloaded on first use)...")

    temp_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(prefix="labs-modelfile-", delete=False, dir=RUNTIME_DIR) as temp_file:
            temp_file.write(content)
            temp_path = Path(temp_file.name)
        run([str(ollama), "create", "qwen3-ctf", "-f", str(temp_path)])
        stamp_path.write_text(current_hash, encoding="utf-8")
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)


def main() -> int:
    if sys.version_info[:2] != (3, 12):
        print("Python 3.12 is required to match the application and release bytecode.")
        return 1

    RUNTIME_DIR.mkdir(exist_ok=True)
    ollama = ensure_ollama()
    if ollama is None:
        return OLLAMA_MISSING if find_ollama() is None else 1

    try:
        python = ensure_python_environment()
        ensure_embedding_model(ollama)
        ensure_chat_model(ollama, python)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"Local runtime setup failed: {exc}")
        return 1

    print("[5/5] Local runtime is ready.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
