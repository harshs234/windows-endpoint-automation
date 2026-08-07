# Windows Endpoint Automation API

A lightweight REST API that exposes Windows disk and cache cleanup operations
as HTTP endpoints, built to be called by Zia Agent Studio (or any other
OpenAPI-compatible AI agent / automation client) as a custom tool.

The service wraps native PowerShell operations behind a FastAPI layer,
returning structured JSON so an AI agent can reason about disk state,
preview a cleanup, and execute it — without shelling out to PowerShell
directly or parsing unstructured console output.

---

## Table of Contents

- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [API Reference](#api-reference)
- [Requirements](#requirements)
- [Setup](#setup)
- [Running the Service](#running-the-service)
- [Authentication](#authentication)
- [Connecting to Zia Agent Studio](#connecting-to-zia-agent-studio)
- [Testing](#testing)
- [Design Notes & Known Limitations](#design-notes--known-limitations)
- [Logging](#logging)

---

## Architecture

```
AI Agent (Zia) ──HTTPS──▶ FastAPI (this service) ──subprocess──▶ PowerShell ──▶ Windows OS
                              │
                              ├─ validates request (Pydantic)
                              ├─ enforces API key auth
                              ├─ invokes the relevant .ps1 script
                              ├─ parses PowerShell's JSON stdout
                              └─ maps it to a typed response model
```

The API is a thin orchestration layer. All actual system interaction —
inspecting disk usage, clearing temp/cache locations, emptying the Recycle
Bin — is implemented in PowerShell under `scripts/`, not in Python. FastAPI's
role is to expose those scripts safely over HTTP with authentication,
input validation, and a stable response contract.

**This service must run natively on the target Windows machine.** It shells
out to `powershell.exe` and touches Windows-only paths and services
(`C:\Windows\Temp`, `wuauserv`, `Clear-RecycleBin`, etc.), so it cannot run
inside a Linux container. A `Dockerfile` is included for reference/future
use with a Windows container base image, but is not the supported
deployment path today.

---

## Project Structure

```
windows-endpoint-automation-api/
├── app/
│   ├── main.py                  # FastAPI app entrypoint, router registration
│   ├── routes/
│   │   ├── health.py            # GET /health
│   │   ├── disk.py              # GET /disk/status
│   │   └── cleanup.py           # POST /disk/cleanup
│   ├── models/
│   │   ├── health_response.py   # HealthResponse
│   │   ├── disk_response.py     # DiskStatusResponse
│   │   ├── cleanup_models.py    # CleanupRequest
│   │   └── response_models.py   # CleanupResponse
│   ├── services/
│   │   └── powershell_services.py  # subprocess wrapper: invokes scripts, parses JSON
│   ├── security/
│   │   └── auth.py              # X-API-KEY header verification
│   └── utils/
│       ├── response_mapper.py   # maps raw PowerShell JSON → response models
│       └── logger.py            # file-based request/error logging
├── scripts/
│   ├── disk-check-api.ps1       # backs GET /disk/status
│   ├── cleanup-preview.ps1      # backs POST /disk/cleanup (dry_run: true)
│   └── cleanup-api.ps1          # backs POST /disk/cleanup (dry_run: false)
├── windows_endpoint.yaml        # OpenAPI 3.0 spec — import this into Zia as a Custom Tool
├── requirements.txt
├── Dockerfile                   # reference only — see Architecture note above
├── docker-compose.yml
└── .env                         # API_KEY, PORT
```

---

## API Reference

### `GET /health`

No authentication required. Used for liveness checks.

**Response**
```json
{
  "status": "online",
  "version": "1.1.0"
}
```

### `GET /disk/status`

Requires `X-API-KEY` header. Returns usage statistics for the Windows
system drive.

**Response**
```json
{
  "drive": "C:",
  "totalSpaceGB": 237.0,
  "usedSpaceGB": 181.5,
  "freeSpaceGB": 55.5,
  "percentUsed": 76.6
}
```

### `POST /disk/cleanup`

Requires `X-API-KEY` header.

**Request body**
```json
{
  "cleanup_level": "safe",
  "dry_run": true
}
```

| Field           | Type   | Default | Notes                                   |
|-----------------|--------|---------|------------------------------------------|
| `cleanup_level` | string | `safe`  | One of `safe`, `standard`. Currently, both values invoke the same cleanup routine. The parameter is retained for future expansion. |
| `dry_run`       | bool   | `false` | Preview only — no files are deleted.     |

**Response**
```json
{
  "status": "success",
  "computerName": "DESKTOP-001",
  "spaceRecoveredGB": 3.2,
  "cleanupPerformed": true,
  "lockedFiles": 0,
  "message": "Disk cleanup completed successfully."
}
```

With `dry_run: true`, `status` is `"preview"`, `spaceRecoveredGB` is `0`,
and `cleanupPerformed` is `false` — no destructive action is taken, but the
response shape is identical, so the calling agent can handle both cases
with one response model.

The full machine-readable contract is in [`windows_endpoint.yaml`](./windows_endpoint.yaml).

---

## Requirements

- Windows 10/11 or Windows Server, running natively (not inside a Linux
  container)
- Python 3.11+
- PowerShell 5.1+ (built into Windows) — no external PowerShell install
  required
- Some cleanup operations require Administrator privileges. Running
  without elevation may reduce the amount of data that can be cleaned,
  but the API will continue to return structured responses rather than
  failing

---

## Setup

```powershell
git clone <this-repo>
cd windows-endpoint-automation-api

python -m venv venv
.\venv\Scripts\Activate.ps1

pip install -r requirements.txt
```

Create `.env` in the project root (or edit the existing one):

```
API_KEY=your-secret-key-here
PORT=8500
```

---

## Running the Service

From the project root, as Administrator:

```powershell
uvicorn app.main:app --host 0.0.0.0 --port 8500
```

Interactive API docs (Swagger UI) are available at:

```
http://localhost:8500/docs
```

To expose the service to an external caller like Zia (which runs in the
cloud and needs a public URL to reach a machine on your local network),
tunnel it — e.g. with ngrok:

```powershell
ngrok http 8500
```

Use the resulting `https://*.ngrok-free.app` URL as the `servers.url` in
`windows_endpoint.yaml` before importing it into Zia.

---

## Authentication

All endpoints except `/health` require a static API key, sent as a header:

```
X-API-KEY: your-secret-key-here
```

The key is read from `.env` (`API_KEY`) at startup via `app/security/auth.py`.
Requests with a missing or incorrect key receive `403 Forbidden`.

This is a shared-secret scheme intended for a single trusted caller (the
Zia Connection). It is not a substitute for network-level access control —
the tunnel/endpoint should still not be treated as public.

---

## Connecting to Zia Agent Studio

1. In Agent Studio, go to **Tools → Create Custom Tools**.
2. Under **Add Schema**, select **Custom Service** and upload
   `windows_endpoint.yaml`.
3. Click **Validate**, then save the tool group.
4. Go to **Settings → Connections** and create a new connection using
   **API Key** auth — header name `X-API-KEY`, value matching `API_KEY`
   in `.env`.
5. Back in the tool group, select each tool (`getDiskStatus`,
   `runDiskCleanup`) and associate them with that Connection.
6. Under **Test Tools**, run each tool once to confirm a live `200`
   response — this is required before the tools can be marked ready and
   attached to an agent.
7. Under **Set Parameters** when deploying the agent, map `dry_run` to
   **Model** (the agent decides this per conversation turn) and
   `cleanup_level` to a fixed **Constant** (e.g. `"safe"`), since the
   agent is not expected to ask the user which level to use.

---

## Testing

**Backend, standalone** — verify each endpoint responds correctly before
wiring it into Zia:

```powershell
curl http://localhost:8500/health

curl http://localhost:8500/disk/status `
  -H "X-API-KEY: your-secret-key-here"

curl -X POST http://localhost:8500/disk/cleanup `
  -H "X-API-KEY: your-secret-key-here" `
  -H "Content-Type: application/json" `
  -d '{"cleanup_level":"safe","dry_run":true}'
```

**End-to-end** — confirm a call actually reaches the backend (rather than
failing inside Zia before the request is sent) by watching the ngrok
request log while testing from Agent Studio. A `200 OK` line for
`/disk/status` or `/disk/cleanup` confirms the round trip; if nothing
appears in the log, the failure is on the Connection/auth side within Zia,
not in this service.

---

## Design Notes & Known Limitations

- **Docker support is not currently implemented.** The `Dockerfile` and
  `docker-compose.yml` are present in the repo, but running
  `docker compose up` will not work — the PowerShell scripts depend on
  native Windows components (`Get-CimInstance`, `Clear-RecycleBin`,
  Windows services) that don't exist inside the Linux base image
  currently used. They're kept for a possible future Windows-container
  deployment. Run the service natively on Windows as described below.
- **Single shared API key.** Sufficient for one Zia Connection calling
  this service; not designed for multi-tenant or per-user auth.
- **`cleanup_level: "standard"` is accepted but not yet differentiated
  in `cleanup-api.ps1`** — the script currently applies the same
  safe-tier operations regardless of level. Extend the script's logic
  if tiered cleanup depth is required.
- **No queuing or async execution.** Each request blocks on its
  PowerShell subprocess for the duration of the operation. Fine for
  single-machine, on-demand use; would need a task queue for fleet-wide
  or long-running cleanup jobs.

---

## Logging

Requests and errors are logged to `logs/cleanup.api.log` (created relative
to the working directory the service is started from) via
`app/utils/logger.py`. Check this file first when diagnosing a failure
that isn't visible in the API response — FastAPI returns a generic
`500 Internal Server Error` to the caller without the underlying
exception, but the full traceback is written here.
