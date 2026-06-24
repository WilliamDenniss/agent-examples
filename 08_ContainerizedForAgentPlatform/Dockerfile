FROM python:3.12-slim

WORKDIR /app

COPY trading_agent/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN mkdir -p trading_agent

COPY trading_agent/agent.py trading_agent/
COPY main.py .

# Agent Runtime injects $PORT. Serve the BYOC FastAPI wrapper (not adk api_server)
# so the container speaks the :query / :streamQuery contract. Sessions + Memory
# come from SESSION_SERVICE_URI / MEMORY_SERVICE_URI in the deployment env.
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}"]

