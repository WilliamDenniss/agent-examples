#!/bin/bash
set -e

# Invoke the BYOC agent deployed to Agent Runtime. A BYOC deployment is a
# reasoningEngine like any other Agent Runtime agent, so it is queried with the
# same :query / :streamQuery contract as the managed deployments (02_Memories,
# 03_DeterministicMemories).

# Update with the resource name printed by deploy_byoc.sh
# (see https://console.cloud.google.com/agent-platform/runtimes).
RESOURCE_NAME=projects/555OOO555/locations/us-west1/reasoningEngines/7348792672426917888

if [[ "$RESOURCE_NAME" == *"555OOO555"* ]]; then
  echo "Error: Update RESOURCE_NAME in trade.sh with the resource printed by deploy_byoc.sh." >&2
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
if [[ -z "$SESSION_ID" || "$SESSION_ID" == "null" ]]; then
  echo "Error: no session id in response (see below)." >&2
  echo "${SESSION_RESPONSE}" >&2
  exit 1
fi
echo "Session created: ${SESSION_ID}"

echo "Sending query: ${MESSAGE}"
curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${BASE_URL}:streamQuery" \
  -d "{\"classMethod\":\"stream_query\",\"input\":{\"user_id\":\"${USER_ID}\",\"session_id\":\"${SESSION_ID}\",\"message\":\"${MESSAGE}\"}}" \
  | jq -rj 'select(.content.parts) | .content.parts[] | select(.text) | .text'

echo
