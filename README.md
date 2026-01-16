# AIProxy-LiteLLM

AI coding backends powered by [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) and [LiteLLM](https://github.com/BerriAI/litellm)

## Features

- Persistent dashboard with LiteLLM
- Cost and usage tracking with LiteLLM
- Codex and Gemini backend as coding API with CLIProxyAPI
- Customizable
- Free and open-source

## Docs

- [CLIProxyAPI](https://help.router-for.me)
- [LiteLLM Proxy](https://docs.litellm.ai/docs/simple_proxy)

## Configuration

- [CLIProxyAPI](https://help.router-for.me/configuration/options.html), [file](./config/cliproxyapi/config.example.yaml)
- [LiteLLM Proxy](https://docs.litellm.ai/docs/proxy/config_settings), [file](./config/litellm/config.example.yaml)

## Requires

- Docker installed
- Read docs mentioned above
- AI coding subscription

## Running

- Configure [`.env`](./.env.example) file
- Just run `docker-compose up` and enjoy

## Check

```bash
curl "http://localhost:4000/v1/models" \
     -H 'Authorization: Bearer $LITELLM_MASTER_KEY'
```

## Usage

### Claude Code

1. Edit `~/.claude/settings.json`
2. Add `env` field like

```json
{
   "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:4000",
    "ANTHROPIC_AUTH_TOKEN": "sk-dummy", // LITELLM_MASTER_KEY should be
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-5-20251101",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.7",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5",
    "ANTHROPIC_MODEL": "opusplan",
    "CLAUDE_CODE_SUBAGENT_MODEL": "glm-4.7",
    "API_TIMEOUT_MS": "3000000"
   }
}
```

### Kilo Code

1. Add custom provider
2. Set Base URL as `http://127.0.0.1:400`
3. Set your preferred model

## License

MIT
