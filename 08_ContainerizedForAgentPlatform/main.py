"""FastAPI runtime that exposes the trading agent over the Agent Runtime
Bring Your Own Container (BYOC) contract.

Unlike ../05_Containerized (which runs `adk api_server` and serves the ADK REST
API at /run, /apps/.../sessions), Agent Runtime forwards every :query /
:streamQuery call to a custom container at two fixed routes, passing the agent
method name in the request body:

    POST /api/reasoning_engine          { "class_method": "...", "input": {...} }   (:query)
    POST /api/stream_reasoning_engine   { "class_method": "...", "input": {...} }   (:streamQuery)

This wrapper dispatches those calls to the AdkApp wrapping our root_agent. The
class methods exposed here must match the `classMethods` declared at deploy time
(see ../09_DeployContainerToAgentPlatform/deploy_byoc.sh).
"""

import inspect
import json
import logging
import os

import uvicorn
from fastapi import FastAPI, Request, encoders, responses
from pydantic import BaseModel
from vertexai import agent_engines

from trading_agent.agent import root_agent

app = FastAPI()

# Wrap the agent in the standard ADK interface. Sessions + Memory are wired by
# AdkApp.set_up() from GOOGLE_CLOUD_AGENT_ENGINE_ID:
#   - deployed on Agent Runtime, the platform injects it (the engine's own id),
#     so the agent is self-contained (sessions + Memory Bank in its own resource).
#   - locally, set GOOGLE_CLOUD_AGENT_ENGINE_ID (+ GOOGLE_CLOUD_PROJECT /
#     GOOGLE_CLOUD_LOCATION) in your docker-env file to point at a backend engine.
# When it's set, AdkApp auto-wires VertexAiSessionService + VertexAiMemoryBankService
# (the latter supports the agent's add_memory writes). With nothing set (a quick
# local docker run), AdkApp falls back to in-memory services.
adk_app = agent_engines.AdkApp(agent=root_agent)


class QueryRequest(BaseModel):
    input: dict | None = None
    class_method: str | None = None


def _encode_chunk_to_json(chunk):
    """Encodes a streaming chunk to a JSON string with a trailing newline."""
    try:
        return json.dumps(encoders.jsonable_encoder(chunk)) + "\n"
    except Exception:
        logging.exception("Failed to encode chunk")
        return None


async def json_generator(output):
    # stream_query yields a sync generator; async_stream_query yields an async
    # generator. Handle either so both class methods stream correctly.
    if hasattr(output, "__aiter__"):
        async for chunk in output:
            encoded = _encode_chunk_to_json(chunk)
            if encoded is None:
                break
            yield encoded
    else:
        for chunk in output:
            encoded = _encode_chunk_to_json(chunk)
            if encoded is None:
                break
            yield encoded


async def _invoke_callable_or_raise(invocation_callable, payload):
    if inspect.iscoroutinefunction(invocation_callable):
        return await invocation_callable(**payload)
    return invocation_callable(**payload)


async def _parse_request(http_request: Request) -> QueryRequest:
    """Read the request body into a QueryRequest.

    Agent Runtime forwards the sync :query body to the container as a
    JSON-encoded *string* (not an object), so parse defensively: decode once,
    and if the result is still a string, decode again.
    """
    payload = await http_request.json()
    if isinstance(payload, str):
        payload = json.loads(payload)
    return QueryRequest(**payload)


@app.post("/api/reasoning_engine")
async def query(http_request: Request) -> responses.JSONResponse:
    """Handles synchronous (:query) calls, e.g. create_session."""
    request = await _parse_request(http_request)
    method = getattr(adk_app, request.class_method)
    output = await _invoke_callable_or_raise(method, request.input or {})
    return responses.JSONResponse(
        content=encoders.jsonable_encoder({"output": output})
    )


@app.post("/api/stream_reasoning_engine")
async def stream_query(http_request: Request) -> responses.StreamingResponse:
    """Handles streaming (:streamQuery) calls, e.g. stream_query."""
    request = await _parse_request(http_request)
    method = getattr(adk_app, request.class_method)
    output = await _invoke_callable_or_raise(method, request.input or {})
    return responses.StreamingResponse(
        content=json_generator(output),
        media_type="application/json",
    )


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
