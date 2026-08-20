<div align="center">

# OWASP Top 10 for LLM Applications

### Interactive Healthcare AI Security Labs

Explore prompt injection, sensitive-data disclosure, poisoning, insecure output handling, prompt leakage, vector weaknesses, misinformation, and unbounded consumption in one local training environment.

![OWASP LLM](https://img.shields.io/badge/OWASP-LLM%20Top%2010-2F6DB0?style=for-the-badge)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Required-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Local AI](https://img.shields.io/badge/AI-Local%20with%20Ollama-20A66A?style=for-the-badge)

**41 guided challenges · 9 vulnerability categories · local models · synthetic healthcare data**

</div>

> [!IMPORTANT]
> This project is intentionally vulnerable. Run it only in a controlled training environment, keep it bound to a trusted machine, and never use real patient data, credentials, or production system information.

## Overview

This repository contains a combined, hands-on environment for studying security risks in applications powered by large language models. The scenarios use synthetic healthcare workflows to demonstrate how vulnerable AI systems behave, why common defenses fail, and which controls reduce risk.

The experience includes:

- A browser-based challenge interface with progress tracking
- Local inference through Ollama, with no cloud model API required
- Intent-based challenge evaluation that accepts equivalent wording
- RAG, vector retrieval, poisoning, disclosure, and output-handling exercises
- Vulnerable and secure modes for side-by-side control testing
- Docker launchers for Windows, Linux, macOS, and WSL

## Lab Map

| Category | Topic | Challenges | What you explore |
|---|---|---:|---|
| **LLM01** | Prompt Injection | 6 | Instruction overrides, identity claims, authority framing, and escalation context |
| **LLM02** | Sensitive Information Disclosure | 4 | Credential extraction, role impersonation, and contextual disclosure |
| **LLM04** | Data and Model Poisoning | 3 | Balanced roadside traffic-sign poisoning, lane-change replay poisoning, and emergency-braking distance poisoning |
| **LLM05** | Insecure Output Handling | 4 | Retail order-card HTML, poisoned reviews, warehouse commands, and refund SQL |
| **LLM06** | Excessive Agency | 2 | Contextual transformer and fictional cooling-advisory requests triggering unauthorized control |
| **LLM07** | System Prompt Leakage | 8 | Transformations, indirect injection, sharded leakage, canaries, and secure architecture |
| **LLM08** | Vector and Embedding Weaknesses | 8 | Retrieval poisoning, hidden content, conflicts, privacy leakage, and provenance controls |
| **LLM09** | Misinformation | 5 | Trusted-source poisoning, unsafe reassurance, and misleading clinical framing |
| **LLM10** | Unbounded Consumption | 1 | Excessive generation, missing limits, and resource exhaustion |

## Quick Start

### Prerequisites

- A working Docker installation **or** Python 3.12 and Ollama for native local mode
- Internet access during the first setup
- Approximately **6 GB** of free space for Ollama, Python dependencies, and the first model downloads
- A modern browser

Docker is optional. The launcher uses it when the Docker CLI, Compose plugin, and daemon are healthy; otherwise it automatically prepares and starts a native Ollama/Python environment.

### Windows

Double-click `launch.bat`, or run:

```powershell
.\launch.bat
```

Ollama for Windows runs natively and does not require WSL. If Python 3.12 or Ollama is missing in local mode, the launcher asks before using the official installers.

### Linux, macOS, or WSL

```bash
bash launch.sh
```

The default `auto` mode will:

1. Check whether the application is already running.
2. Test Docker CLI, Docker Compose, and daemon availability with bounded timeouts.
3. Use Docker when healthy, or switch to native local mode when Docker is missing or its backend is unavailable.
4. In local mode, create `.venv`, install the Python dependencies, start Ollama, and prepare `nomic-embed-text` and `qwen3-ctf`.
5. Open `http://localhost:<APP_PORT>/labs` when the application is ready.

You can explicitly select a mode:

```powershell
.\launch.bat docker
.\launch.bat local
```

```bash
./launch.sh docker
./launch.sh local
```

Local mode runs Uvicorn in the launcher terminal. Press **Ctrl+C** to stop the application. A launcher-started Ollama service may remain available for later runs, and downloaded models remain in Ollama's normal per-user model cache.

### Application port

Change `x-app-port` in `backend/config.yml` before starting the lab. This single value configures the published host port, the container port, Uvicorn, and the URL opened by both launch scripts. Change `x-container-name` in the same file to rename the Docker container.

Direct Compose commands use the same backend config automatically:

```powershell
docker compose up --build -d
```

The launch scripts wait for `/labs` to return HTTP 200 and then open the configured URL in the system default browser.

> [!NOTE]
> The first startup can take several minutes while approximately 1.7 GB of model data and the Python dependencies are downloaded. Later Docker starts reuse the persistent Docker volume; later local starts reuse `.venv` and Ollama's user model cache.

### Corporate TLS certificates

If your network uses TLS inspection, export the corporate root CA as a PEM-encoded `.crt` or `.pem` file and place it in `certs/` before starting the container. The directory is mounted read-only, and certificates are imported before Ollama starts. TLS verification remains enabled; do not disable verification or add private keys or client certificates.

Native local mode uses the host trust store. Ask your system administrator to install the corporate root CA there; the launcher deliberately does not make privileged trust-store changes.

```powershell
docker compose up --build
```

An Ollama model-pull error containing `x509: certificate signed by unknown authority` means the required root CA is missing from `certs/` or is not PEM encoded.

## Useful Commands

```bash
# Start or rebuild
docker compose up --build -d

# Follow startup and model-download progress
docker logs -f LLMWorkshop_Labs

# Stop the application
docker compose down

# Stop and remove the downloaded-model volume
docker compose down -v

# Force native local mode
./launch.sh local
```

## LLM07: System Prompt Leakage

The eight levels progress from direct disclosure to architecture-focused defense:

| Level | Challenge |
|---|---|
| `sp_1` | MRI Workflow Disclosure |
| `sp_2` | Transformation Trap |
| `sp_3` | Policy Oracle |
| `sp_4` | Support Ticket Trojan |
| `sp_5` | Invisible HTML |
| `sp_6` | Sharded Reconstruction |
| `sp_7` | Canary Hunt |
| `sp_8` | Secure Architecture Boss |

## LLM08: Vector and Embedding Weaknesses

These levels demonstrate why similarity is not the same as trust, truth, or authorization:

| Level | Challenge |
|---|---|
| `ve_1` | The Poisoned Hospital Directory |
| `ve_2` | Hidden Loader Payload |
| `ve_3` | Cross-Modal Clinical Conflict |
| `ve_4` | Semantic Retrieval Hijack |
| `ve_5` | Evidence Conflict |
| `ve_6` | Embedding Privacy Leak |
| `ve_7` | Poison Traceback |
| `ve_8` | Build the Clinical Gate |

> `ve_1` uses a downloadable `hospital-directory.json` instead of a text template: download it, change only Dr. Smith's `room` and `building` fields, upload the modified JSON, then load it into the vector database. The other levels use the text-template loader commands below.

## Learner Command Reference

LLM08 scenarios reconstruct their state from scenario-local chat history. Commands must use the forms below.

### Load a template

```text
load antibiotic template
load hidden PDF template
load cardiac template
load insulin template
load multimodal template
load privacy template
```

### Ingest a synthetic document

```text
ingest document
title: Example Notes
source: simulated
tenant: TENANT-A
trust: 60
approved: yes
text: synthetic training data
hidden: no
tags: test
```

### Select operating mode and tenant

```text
use vulnerable mode
use secure mode
authorized tenant TENANT-A
authorized tenant TENANT-B
minimum trust 70
```

### Configure secure retrieval controls

Each control supports both `enable` and `disable` forms.

```text
enable approved sources
enable hidden stripping
enable conflict detection
enable corroboration
enable PHI redaction
enable tenant isolation
enable human review
```

### Inspect attribution

```text
show poison traceback
```

Diagnostics are scenario-local and redact sensitive values.

## Progress and Reset

Progress and per-scenario conversation history are stored in browser local storage. Use **Reset progress** in the top bar to clear:

- Challenge completion state
- Per-scenario chat history
- Reconstructed ingestions and controls
- The last active scenario
- MRI upload state

If the interface still appears stale, run the reset again before manually clearing browser storage.

## Core Security Lessons

- **Similarity is not authority.** A high embedding score does not establish truth, trust, or access rights.
- **Prompts are not secret stores.** Assume system prompts and model context can eventually be exposed.
- **Authorization belongs server-side.** Do not delegate access control to model instructions or client state.
- **Provenance changes retrieval decisions.** Source approval, tenant, trust, and conflict metadata must influence whether evidence is used.
- **High-risk output needs friction.** Corroboration, validation, redaction, rate limits, and human review reduce impact.
- **Resource limits are security controls.** Bound request sizes, output length, concurrency, and execution time.

## Project Structure

```text
.
├── backend/                 FastAPI server, evaluators, lab logic, and data
│   ├── knowledge_base/     RAG documents, metadata, and FAISS index
│   └── requirements.txt    Python runtime dependencies
├── frontend/               Browser-based lab interface
├── scripts/                Asset encryption and release tooling
│   └── prepare_local_runtime.py  Shared native-runtime bootstrap
├── tests/                  Unit, API, matcher, and UI contract tests
├── Dockerfile              Application and Ollama runtime image
├── docker-compose.yml      Local service and persistent model volume
├── launch.bat              Windows launcher
└── launch.sh               Linux, macOS, and WSL launcher
```

## Development

Use Python 3.12 to match Docker and release bundles, then create an environment and install the backend dependencies:

```bash
python -m venv .venv
```

```powershell
# Windows PowerShell
.\.venv\Scripts\Activate.ps1
python -m pip install -r backend\requirements.txt
python -m pytest -q
```

```bash
# Linux or macOS
source .venv/bin/activate
python -m pip install -r backend/requirements.txt
python -m pytest -q
```

## Troubleshooting

| Symptom | What to do |
|---|---|
| Docker is not found | Run the launcher normally and it will switch to local mode, or install Docker and use the `docker` mode explicitly. |
| Docker or its WSL backend is unavailable | Use `launch.bat local` on Windows to bypass both Docker and WSL. |
| Local mode cannot find Python | Install 64-bit Python 3.12. Release bundles use Python 3.12 bytecode and cannot use another minor version. |
| Local mode cannot reach Ollama | Verify `http://localhost:11434/api/tags`, then review `.runtime/ollama.log`. |
| Startup appears stuck | In Docker mode, run `docker logs -f LLMWorkshop_Labs`; in local mode, review the launcher output and `.runtime/ollama.log`. |
| Configured port is busy | Stop the conflicting service or change `x-app-port` in `backend/config.yml`, then restart with the launcher or `docker compose up --build -d`. |
| A scenario looks stale | Use **Reset progress**, then verify command spelling against the scenario UI. |
| Docker models need a clean download | Run `docker compose down -v`, then start again. Local models are managed through the Ollama CLI or application. |

## Safety and Scope

> [!CAUTION]
> The application contains intentionally insecure patterns for education. It is not a clinical system, security product, or source of medical advice.

- Use synthetic data only.
- Never upload protected health information (PHI).
- Never paste real passwords, API keys, tokens, certificates, or production logs.
- Do not expose this service to an untrusted network.
- For real symptoms or urgent medical concerns, contact a qualified clinician or local emergency service.

## Facilitator Notes

Challenge scoring is deterministic and intent-based. When extending a challenge, define the objectives and required components rather than a single exact prompt. Equivalent wording should remain acceptable, while feedback should identify missing concepts without revealing a complete solution.

Do not publish canary literals or facilitator-only answers in learner materials.

## Credits

Designed and developed by **CN Madhu** (`madhu.cn@philips.com`) for OWASP Top 10 for LLM Applications (2025) security training in healthcare-oriented environments.

---

<div align="center">

**Learn the failure mode. Trace the impact. Build the control.**

</div>
