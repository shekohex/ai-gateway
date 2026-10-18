import base64
import json
from contextvars import ContextVar
from functools import wraps
from html import escape

from fastapi import HTTPException
from starlette.datastructures import UploadFile
from starlette.responses import PlainTextResponse, StreamingResponse

from litellm.integrations.custom_logger import CustomLogger


_transcription_request = ContextVar("vibecode_transcription_request", default=None)
_context_fields = {"context", "context_images", "context_images[]"}
_image_types = {"image/png", "image/jpeg", "image/webp", "image/gif"}


class TranscriptionCleanup(CustomLogger):
    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        state = _transcription_request.get()
        if state is None or call_type not in ("transcription", "audio_transcription"):
            return data

        state["metadata"] = dict(data.get("metadata") or {})
        state["user"] = data.get("user")
        for field in _context_fields | {"stream", "response_format"}:
            data.pop(field, None)
        # Finish STT before cleanup, even when client requests streamed output.
        data["response_format"] = "json"
        return data


async def _context_parts(form):
    context = "\n\n".join(
        str(form[field]) for field in ("prompt", "context") if form.get(field)
    )
    images = form.get("context_images", [])
    if isinstance(images, str):
        try:
            images = json.loads(images)
        except json.JSONDecodeError as error:
            raise HTTPException(400, "context_images must be a JSON array of image URLs.") from error
    if not isinstance(images, list):
        raise HTTPException(400, "context_images must be a JSON array of image URLs.")

    parts = [{"type": "text", "text": f"<CONTEXT_INFORMATION>\n{escape(context)}"}]
    for image in images:
        if isinstance(image, UploadFile):
            if image.content_type not in _image_types:
                raise HTTPException(400, "Context images must be PNG, JPEG, WebP, or GIF.")
            image_data = base64.b64encode(await image.read()).decode("ascii")
            image_url = f"data:{image.content_type};base64,{image_data}"
        elif isinstance(image, str) and image.startswith(("https://", "http://", "data:image/")):
            image_url = image
        else:
            raise HTTPException(400, "Context images must be image uploads or image URLs.")
        parts.append({"type": "image_url", "image_url": {"url": image_url}})
    return parts


def _stream_event(event_type, **fields):
    payload = json.dumps({"type": event_type, **fields}, ensure_ascii=False)
    return f"event: {event_type}\ndata: {payload}\n\n"


async def _stream_transcript(completion):
    fragments = []
    try:
        async for chunk in completion:
            if not chunk.choices:
                continue
            delta = chunk.choices[0].delta.content
            if delta:
                fragments.append(delta)
                yield _stream_event("transcript.text.delta", delta=delta)
        text = "".join(fragments)
        if not text.strip():
            raise ValueError("Vibecode cleanup returned no text.")
        yield _stream_event("transcript.text.done", text=text)
    except Exception as error:
        yield _stream_event("error", error={"message": str(error), "type": "cleanup_error"})
    finally:
        await completion.aclose()


def _wrap_transcription(endpoint):
    @wraps(endpoint)
    async def transcribe(request, fastapi_response, file, user_api_key_dict):
        from litellm.proxy import proxy_server
        from litellm.proxy.common_utils.http_parsing_utils import get_form_data

        form = await get_form_data(request)
        cleanup = next((
            model["model_info"]["transcription_cleanup"]
            for model in proxy_server.llm_router.model_list
            if model["model_name"] == form.get("model")
            and model.get("model_info", {}).get("transcription_cleanup")
        ), None)
        if cleanup is None:
            return await endpoint(request, fastapi_response, file, user_api_key_dict)

        response_format = form.get("response_format", "json")
        if response_format not in ("json", "text"):
            raise HTTPException(400, "Vibecode transcription supports response_format=json or text.")
        stream_value = form.get("stream", "false")
        if stream_value not in (True, False, "true", "false"):
            raise HTTPException(400, "stream must be true or false.")
        stream = stream_value in (True, "true")
        context_parts = await _context_parts(form)

        state = {}
        token = _transcription_request.set(state)
        try:
            transcript = await endpoint(request, fastapi_response, file, user_api_key_dict)
        finally:
            _transcription_request.reset(token)

        context_parts.append({
            "type": "text",
            "text": f"\n</CONTEXT_INFORMATION>\n<TRANSCRIPT>\n{escape(transcript.text)}\n</TRANSCRIPT>",
        })
        headers = {
            key: value for key, value in fastapi_response.headers.items()
            if key.lower() not in {"content-type", "content-length", "transfer-encoding"}
        }
        if transcript.text.strip():
            try:
                completion = await proxy_server.llm_router.acompletion(
                    model=cleanup["model"],
                    reasoning_effort=cleanup["reasoning_effort"],
                    messages=[
                        {"role": "system", "content": cleanup["prompt"]},
                        {"role": "user", "content": context_parts},
                    ],
                    stream=stream,
                    metadata=state.get("metadata", {}),
                    user=state.get("user"),
                )
                if not stream:
                    cleaned_text = completion.choices[0].message.content
                    if not cleaned_text or not cleaned_text.strip():
                        raise ValueError("Vibecode cleanup returned no text.")
                    transcript.text = cleaned_text.strip()
            except Exception as error:
                raise proxy_server.ProxyException(
                    message=str(error),
                    type=getattr(error, "type", "cleanup_error"),
                    param=getattr(error, "param", None),
                    code=getattr(error, "status_code", 502),
                ) from error
            if stream:
                return StreamingResponse(
                    _stream_transcript(completion),
                    media_type="text/event-stream",
                    headers={**headers, "cache-control": "no-cache", "x-accel-buffering": "no"},
                )
        elif stream:
            return StreamingResponse(
                iter([_stream_event("transcript.text.done", text=transcript.text)]),
                media_type="text/event-stream",
                headers=headers,
            )
        if response_format == "text":
            return PlainTextResponse(transcript.text, headers=headers)
        return transcript

    return transcribe


def install():
    from litellm.proxy import proxy_server

    # Retain stock route dependencies: authentication, model access, and budgets.
    for route in [*proxy_server.router.routes, *proxy_server.app.routes]:
        if getattr(route, "path", None) not in {"/audio/transcriptions", "/v1/audio/transcriptions"}:
            continue
        if getattr(route.endpoint, "_vibecode_wrapped", False):
            continue
        wrapped = _wrap_transcription(route.endpoint)
        wrapped._vibecode_wrapped = True
        route.endpoint = wrapped
        route.dependant.call = wrapped


handler = TranscriptionCleanup()
