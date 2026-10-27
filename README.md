# AI Gateway

A production-grade AI gateway providing unified access to multiple LLM providers with robust observability, security, and identity management. Powered by LiteLLM, Langfuse, and Cloudflare Tunnel.

## Core Components

- **LiteLLM Proxy**: Unified OpenAI-compatible API gateway for 100+ LLMs.
- **Langfuse**: Open-source observability, tracing, and prompt management.
- **CLIProxyAPI**: High-performance backend for specialized coding models.
- **Cloudflared**: Cloudflare Tunnel connector that exposes the gateway publicly without opening any inbound ports.
- **Data Stack**: Postgres (Persistence), Redis (Caching/Routing), Clickhouse (Analytics), Minio (Blob Storage).

## Prerequisites

- Linux or macOS
- Docker and Docker Compose (v2+)
- curl, openssl, and jq

## Getting Started

The project includes a comprehensive CLI tool for onboarding and management.

### 1. Installation

Clone the repository and run the onboarding script:

```bash
./setup.sh onboard
```

The script will:
- Verify system dependencies.
- Guide you through security and database configuration.
- Automatically generate cryptographically secure secrets (e.g., `sk-...` for LiteLLM, `pk-lf-...`/`sk-lf-...` for Langfuse) if you leave inputs empty.
- Create a tailored `.env` file with production-ready defaults.

### 2. Launching the Stack

Start all services in detached mode:

```bash
./setup.sh up -d
```

### 3. Verification

Check the availability of models through the proxy:

```bash
curl "http://localhost:4000/v1/models" \
     -H "Authorization: Bearer <LITELLM_MASTER_KEY>"
```

## Management CLI

The `setup.sh` utility provides several commands for lifecycle management:

| Command | Description |
| :--- | :--- |
| `onboard` | Interactive setup and configuration |
| `up` | Start the stack (supports all docker compose flags) |
| `down` | Stop and remove service containers |
| `restart` | Restart all active services |
| `update` | Pull latest images and restart the stack |
| `cleanup` | Remove orphans and stop services |
| `reset` | **Destructive**: Wipe all data volumes and configuration |

## Cloudflare Tunnel

The `cloudflared` container (`services/tunnel/compose.yml`) runs on the `ai-gateway-connect` network. The only configuration it needs is the tunnel token in `.env`:

```bash
CLOUDFLARE_TUNNEL_TOKEN="<your tunnel token>"
```

Create the tunnel in the Cloudflare Zero Trust dashboard (Networks → Tunnels), copy its token, then add these **Public Hostnames** to it:

- `ai-gateway.0iq.xyz` → `http://litellm:4000`
- `cliproxyapi.0iq.xyz` → `http://cli-proxy-api:8317`
- `executor.0iq.xyz` → `http://executor:4788`
- Optional, if observability is enabled: Langfuse → `http://langfuse-web:3000`, Prometheus → `http://prometheus:9090`

Cloudflare terminates TLS at the edge, so no certificates or DNS API tokens are needed. Other services (Postgres, Redis, Clickhouse, Minio) stay isolated within the internal Docker network.

## Observability and UI


- **LiteLLM Admin UI**: `http://localhost:4000/ui` (Management of keys, models, and budgets)
- **Langfuse Dashboard**: `http://localhost:3000` (Tracing and analytics)
- **Prometheus**: `http://localhost:9090` (System metrics)

## Configuration Reference

- **LiteLLM Proxy**: Located in `config/litellm/config.yaml`.
- **CLIProxyAPI**: Located in `config/cliproxyapi/config.yaml`.
- **Environment Variables**: Managed via the root `.env` file.

## Service Maintenance

Logs are automatically rotated with a maximum size of 100MB per service and 3-day retention for request/response logs within the database.

## Integration Examples

### Claude Code

Configure your `~/.claude/settings.json` to route through the gateway:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:4000",
    "ANTHROPIC_AUTH_TOKEN": "your-master-key",
    "ANTHROPIC_MODEL": "gemini-claude-opus-4-5-thinking"
  }
}
```

## License

MIT
