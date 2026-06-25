#!/bin/bash
set -e

if [[ -z "$SERVICE_URL" ]]; then
  echo "Error: SERVICE_URL environment variable must be set (see deploy_cloudrun.sh output)." >&2
  echo "  e.g. export SERVICE_URL=\$(gcloud run services describe trading-agent --region us-west1 --format='value(status.url)')" >&2
  exit 1
fi

APP_NAME="trading_agent"
USER_ID="user1"
TOKEN=$(gcloud auth print-identity-token)

echo "Creating session..."
SESSION_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"state": {}}' \
  "$SERVICE_URL/apps/$APP_NAME/users/$USER_ID/sessions")

echo "Response:"
echo "$SESSION_RESPONSE"

SESSION_ID=$(echo "$SESSION_RESPONSE" | jq -r '.id // empty')
if [[ -z "$SESSION_ID" ]]; then
  echo "Error: no session id in response (see above)." >&2
  exit 1
fi
echo "Session: $SESSION_ID"

echo ""
echo "Running trading cycle..."
RUN_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"appName\": \"$APP_NAME\",
    \"userId\": \"$USER_ID\",
    \"sessionId\": \"$SESSION_ID\",
    \"newMessage\": {
      \"role\": \"user\",
      \"parts\": [{\"text\": \"Run the trading cycle\"}]
    }
  }" \
  "$SERVICE_URL/run")

echo "Response:"
echo "$RUN_RESPONSE"

echo ""
echo "Model reply:"
echo "$RUN_RESPONSE" | jq -r '[.[] | select(.content.role == "model") | .content.parts[]? | select(.text) | .text] | last'
