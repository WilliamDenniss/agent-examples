#!/bin/bash
set -e

# Set RESOURCE_NAME to the resource name printed by deploy.py
# (see https://console.cloud.google.com/agent-platform/runtimes).
if [[ -z "$RESOURCE_NAME" ]]; then
  echo "Error: RESOURCE_NAME is not set. Export it like:" >&2
  echo "  export RESOURCE_NAME=projects/555OOO555/locations/us-west1/reasoningEngines/5272175847371964416" >&2
  exit 1
fi

REGION=$(echo "$RESOURCE_NAME" | sed 's|.*/locations/\([^/]*\)/.*|\1|') # derive region from resource name
BASE_URL="https://${REGION}-aiplatform.googleapis.com/v1/${RESOURCE_NAME}"
USER_ID="test-user"
MESSAGE="${1:-Run the trading cycle.}"

TOKEN=$(gcloud auth print-access-token)

echo "Creating session..."
SESSION_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${BASE_URL}:query" \
  -d "{\"classMethod\":\"create_session\",\"input\":{\"user_id\":\"${USER_ID}\"}}")

SESSION_ID=$(echo "${SESSION_RESPONSE}" | jq -r '.output.id')
echo "Session created: ${SESSION_ID}"

echo "Sending query: ${MESSAGE}"
curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${BASE_URL}:streamQuery" \
  -d "{\"classMethod\":\"stream_query\",\"input\":{\"user_id\":\"${USER_ID}\",\"session_id\":\"${SESSION_ID}\",\"message\":\"${MESSAGE}\"}}" \
  | jq -rj 'select(.content.parts) | .content.parts[] | select(.text) | .text'

echo
