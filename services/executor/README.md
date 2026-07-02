# Executor Self-Host Setup

This directory runs the upstream self-hosted Executor image.

## What It Does

- uses `ghcr.io/rhyssullivan/executor-selfhost:latest`
- exposes Executor on port `4788`
- persists self-host data in `/data`
- serves API, MCP, auth, execution, and web UI from one container

## Files

- `compose.yaml` runs the upstream self-host image with persistent data

## Run With Compose

```bash
docker compose up -d executor
```

## Run With Docker

```bash
docker run -d \
  --name executor-selfhost \
  -p 4788:4788 \
  -v executor-data:/data \
  ghcr.io/rhyssullivan/executor-selfhost:latest
```

## Defaults

- `EXECUTOR_IMAGE=ghcr.io/rhyssullivan/executor-selfhost:latest`
- `EXECUTOR_HTTP_PORT=4788`
- `EXECUTOR_WEB_BASE_URL=http://localhost:4788`
- data volume: `../../data/executor/data:/data`

## Override Example

```bash
EXECUTOR_HTTP_PORT=8090 EXECUTOR_WEB_BASE_URL=http://localhost:8090 docker compose up -d executor
```

## Endpoints

- `http://localhost:4788/`
- `http://localhost:4788/api/health`
- `http://localhost:4788/mcp`

## Persistence

- `/data` stores Executor SQLite/state files
