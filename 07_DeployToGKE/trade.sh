#!/bin/bash
set -e

# Run the agent locally in Docker first:
#   docker build -t trade .
#   docker run -it --rm --env-file docker-env -p 8080:8080 trade
SERVICE_URL="http://localhost:8080"
APP_NAME="trading_agent"
USER_ID="user1"
MESSAGE="${1:-Run the trading cycle}"

echo "Creating session..."
SESSION_ID=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"state": {}}' \
  "$SERVICE_URL/apps/$APP_NAME/users/$USER_ID/sessions" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
echo "Session: $SESSION_ID"

echo ""
echo "Running trading cycle..."
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"appName\": \"$APP_NAME\",
    \"userId\": \"$USER_ID\",
    \"sessionId\": \"$SESSION_ID\",
    \"newMessage\": {
      \"role\": \"user\",
      \"parts\": [{\"text\": \"$MESSAGE\"}]
    }
  }" \
  "$SERVICE_URL/run" \
  | python3 -c "
import sys, json
events = json.loads(sys.stdin.read())
for event in reversed(events):
    content = event.get('content', {})
    parts = content.get('parts', [])
    for part in parts:
        if 'text' in part and content.get('role') == 'model':
            print(part['text'])
            exit()
"


