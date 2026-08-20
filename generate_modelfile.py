#!/usr/bin/env python3
"""Generates Modelfile content to stdout from the embedded encrypted copy.

Used by entrypoint.sh:
    python /app/generate_modelfile.py | ollama create qwen3-ctf -f -
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from backend.crypto_utils import get_modelfile_content

print(get_modelfile_content(), end="")
