#!/bin/bash
set -e

# Run the BYOC container locally first:
#   docker build -t trade-byoc .
#   docker run -it --rm --env-file docker-env -p 8080:8080 trade-byoc
#
# Unlike ../05_Containerized, this container serves the Agent Runtime BYOC
# contract (/api/reasoning_engine + /api/stream_reasoning_engine) rather than the
# ADK REST API, so we exercise the same class_method protocol Agent Runtime uses.
SERVICE_URL="http://localhost:8080"
USER_ID="user1"
MESSAGE="${1:-Run the trading cycle}"

echo "Creating session..."
if ! SESSION_RESPONSE=$(curl -sS -X POST \
  -H "Content-Type: application/json" \
  -d "{\"class_method\": \"create_session\", \"input\": {\"user_id\": \"$USER_ID\"}}" \
  "$SERVICE_URL/api/reasoning_engine" 2>&1); then
  echo "Error: could not reach the container at $SERVICE_URL." >&2
  echo "  ${SESSION_RESPONSE}" >&2
  echo "  Is it running?  docker ps   (start it with ./docker.sh)" >&2
  exit 1
fi

SESSION_ID=$(echo "$SESSION_RESPONSE" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin)['output']['id'])
except Exception:
    pass
")

if [[ -z "$SESSION_ID" ]]; then
  echo "Error: could not create session. Raw response:" >&2
  echo "${SESSION_RESPONSE:-<empty — is the container running on $SERVICE_URL?>}" >&2
  exit 1
fi
echo "Session: $SESSION_ID"

echo ""
echo "Running trading cycle..."
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"class_method\": \"stream_query\", \"input\": {\"user_id\": \"$USER_ID\", \"session_id\": \"$SESSION_ID\", \"message\": \"$MESSAGE\"}}" \
  "$SERVICE_URL/api/stream_reasoning_engine" \
  | python3 -c "
import sys, json
last = None
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    event = json.loads(line)
    content = event.get('content', {})
    if content.get('role') != 'model':
        continue
    for part in content.get('parts', []):
        if 'text' in part:
            last = part['text']
if last:
    print(last)
"
