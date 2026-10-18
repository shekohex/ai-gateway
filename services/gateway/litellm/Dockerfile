ARG LITELLM_IMAGE=ghcr.io/berriai/litellm:v1.105.0@sha256:60947db020b57e204823d3fbc8bb295c85be890d7c9adcc77fb4f5fc2fe410b2
FROM ${LITELLM_IMAGE}

COPY transcription_cleanup.py /app/transcription_cleanup.py
ENV LITELLM_WORKER_STARTUP_HOOKS=transcription_cleanup:install

# websockets rejects `ssl=` for ws:// URIs; only pass the ssl context for wss://
RUN python - <<'PY'
import litellm.llms.custom_httpx.llm_http_handler as m
p = m.__file__
s = open(p).read()
old = "ssl=ssl_context,"
assert s.count(old) == 2, s.count(old)
s = s.replace(old, 'ssl=ssl_context if url.startswith("wss://") else None,', 1)
s = s.replace(old, 'ssl=ssl_context if ws_url.startswith("wss://") else None,', 1)
open(p, "w").write(s)
PY
RUN python -m py_compile /app/.venv/lib/python3.13/site-packages/litellm/llms/custom_httpx/llm_http_handler.py
