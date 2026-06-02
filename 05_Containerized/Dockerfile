FROM python:3.12-slim

WORKDIR /app

COPY trading_agent/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN mkdir -p trading_agent

COPY trading_agent/agent.py trading_agent/

CMD ["sh", "-c", "adk api_server --host 0.0.0.0 --port ${PORT:-8080} ${SESSION_SERVICE_URI:+--session_service_uri $SESSION_SERVICE_URI} ${MEMORY_SERVICE_URI:+--memory_service_uri $MEMORY_SERVICE_URI} --no-reload /app"]
