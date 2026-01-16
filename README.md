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

Just run `docker-compose up` and enjoy

## Usage

```bash
curl "http://localhost:4000/v1/models" \
     -H 'Authorization: Bearer $LITELLM_MASTER_KEY'
```

## License

MIT
