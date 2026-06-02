# Containerized agent

## Setup

This agent can be run in Docker entirely locally (no memory storage), or connected to a memory store backend.

For local use, create `docker-env` populated with:

```
# Alpaca API keys
APCA_API_KEY_ID=your-key-id
APCA_API_SECRET_KEY=your-key

# Google AI Studio / Vertex AI Key for the ADK Agent
GOOGLE_API_KEY=your-key
```

Then run `docker.sh`.

For a remote setup, first deploy the backend agent (see ../04_AgentPlatformBackend), then populate `docker-env-remote` with:

```
# Alpaca API keys
APCA_API_KEY_ID=your-key-id
APCA_API_SECRET_KEY=your-key

GOOGLE_GENAI_USE_VERTEXAI=TRUE
GOOGLE_CLOUD_PROJECT=your-project
GOOGLE_CLOUD_LOCATION=us-west1

SESSION_SERVICE_URI=agentengine://projects/555OOO555/locations/us-west1/reasoningEngines/5272175847371964416
MEMORY_SERVICE_URI=agentengine://projects/555OOO555/locations/us-west1/reasoningEngines/5272175847371964416
```

Note: ensure that GEMINI_API_KEY is NOT present in `docker-env-remote`

and run

`docker-remote.sh`

# Trading

With our agent running locally in docker, and exposed on port 8080, run it with

`trade-local.sh`.

