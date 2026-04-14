# Executor Docker Setup

This directory contains a simple Dockerized Executor deployment fronted by Caddy.

## What It Does

- installs `executor` globally from npm
- starts `executor web` in the background
- runs Caddy as the main container process
- exposes Executor over HTTP on port `80`
- rewrites the `Host` header to `localhost` so Executor accepts proxied requests

## Files

- `Dockerfile` builds the image
- `Caddyfile` proxies HTTP traffic to the local Executor process
- `start.sh` launches Executor and then Caddy
- `compose.yaml` runs the container with persistent bind mounts

## Build

```bash
docker build \
  --build-arg EXECUTOR_VERSION=1.4.6 \
  -t dotai-executor-proxy \
  src/extensions/executor/docker
```

## Run With Docker

```bash
docker run --rm \
  -p 8080:80 \
  -v "$PWD/executor-data:/var/lib/executor" \
  -v "$PWD/executor-scope:/workspace" \
  dotai-executor-proxy
```

## Run With Compose

```bash
cd src/extensions/executor/docker
docker compose up -d --build
```

## Defaults

- `EXECUTOR_VERSION=latest`
- `EXECUTOR_HTTP_PORT=8080`
- `EXECUTOR_PORT=4788`
- state volume: `./executor-data`
- scope volume: `./executor-scope`

## Override Example

```bash
cd src/extensions/executor/docker
EXECUTOR_VERSION=1.4.6 EXECUTOR_HTTP_PORT=8090 docker compose up -d --build
```

## Endpoints

- `http://localhost:8080/`
- `http://localhost:8080/api/scope`
- `http://localhost:8080/mcp`

## Persistence

- `/var/lib/executor` stores Executor SQLite/state files
- `/workspace` is the Executor scope directory and can contain `executor.jsonc`
