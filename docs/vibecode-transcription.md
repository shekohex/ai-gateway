# Vibecode transcription

Three model aliases on `POST /v1/audio/transcriptions` (also `/audio/transcriptions`):

| Alias | STT | Cleanup | Thinking |
| --- | --- | --- | --- |
| `vibecode-1-transcribe` | `parakeet-ultra` | `gpt-6-luna` | Off |
| `vibecode-1-multilang-mini-transcribe` | `gpt-4o-mini-transcribe` | `gpt-6-luna` | Off |
| `vibecode-1-multilang-transcribe` | `gpt-4o-transcribe` | `gemini-flash-latest` | Low |

Audio `file` remains required. Extra text and screenshots provide context, not replacement transcripts.

## Output

- Default: `response_format=json` returns `{"text":"Cleaned transcript."}`.
- `response_format=text` returns plain UTF-8 text.
- `stream=true` returns SSE, regardless of `response_format`. STT completes first; cleanup runs once on final transcript. Only cleaned text is streamed.
- Streaming emits `transcript.text.delta`, then `transcript.text.done` containing full cleaned text. Failures emit an `error` event without a successful done event.
- No upstream STT partials are exposed. This is file-upload transcription, not Realtime WebSocket audio/commit handling.
- Timestamp/subtitle formats are unsupported: cleanup changes original wording and alignment.

## Context

- `prompt`: standard STT hint, also provided to cleanup as context.
- `context`: extra text for cleanup only.
- `context_images`: JSON array of image URLs or `data:image/...;base64,...` URLs for cleanup only.
- Alternatively, repeat multipart `context_images[]` fields to upload PNG, JPEG, WebP, or GIF images. Do not mix uploaded-image fields with `context_images` JSON in one request.

Images are sent to final cleanup model as image content, not transcribed by STT. Supported image limits depend on provider.

```bash
curl "$LITELLM_BASE_URL/v1/audio/transcriptions" \
  -H "Authorization: Bearer $LITELLM_API_KEY" \
  -F model=vibecode-1-transcribe \
  -F file=@recording.wav \
  -F response_format=text \
  -F 'context=React component using useState; file: SearchPanel.tsx' \
  -F 'context_images[]=@screenshot.png;type=image/png'
```

For streaming, add `-N -F stream=true`. An event looks like:

```text
event: transcript.text.delta
data: {"type":"transcript.text.delta","delta":"Cleaned "}

event: transcript.text.done
data: {"type":"transcript.text.done","text":"Cleaned transcript."}
```

## Applying configuration

Merge aliases and callback from `config/litellm/config.example.yaml` into live config, then rebuild LiteLLM image. Bundled startup hook wraps transcription routes while keeping existing authentication and STT processing. No separate service required.

Cleanup uses same caller metadata for spend attribution. Cleanup model calls use gateway router internally; granting access to a Vibecode alias grants its configured cleanup stage as part of that operation.
