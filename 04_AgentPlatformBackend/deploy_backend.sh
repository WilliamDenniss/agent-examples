# 1. Set your variables
PROJECT_ID=$(gcloud config get-value project)
LOCATION="us-west1" # Replace with your target region
RESOURCE_DISPLAY_NAME="Agent Backend Resource"

# 2. Build the request payload
SETTINGS="{
    \"displayName\": \"${RESOURCE_DISPLAY_NAME}\"
  }"

# 3. Execute the REST API request, capturing the response body
RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  "https://${LOCATION}-aiplatform.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/reasoningEngines" \
  -d "${SETTINGS}")

# 4. Check for errors in the response
if [ -z "$RESPONSE" ]; then
  echo "Error: empty response from API" >&2
  exit 1
fi

if echo "$RESPONSE" | grep -q '"error"'; then
  echo "Error: API request failed" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

# 5. Parse the "name" field from the response
NAME=$(echo "$RESPONSE" | jq -r '.name')

if [ -z "$NAME" ] || [ "$NAME" = "null" ]; then
  echo "Error: could not parse 'name' from response" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

echo "Operation name: $NAME"

# 6. Derive the engine resource name from the operation name
ENGINE_NAME="${NAME%/operations/*}"

# 6b. Wait for the create operation to complete (engine is provisioned async)
echo "Waiting for engine to be created..."
until [ "$(curl -s \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://${LOCATION}-aiplatform.googleapis.com/v1/${NAME}" | jq -r '.done')" = "true" ]; do
  sleep 5
done
echo "Engine ready: $ENGINE_NAME"

echo
echo "Add these env variables to your deployment:"
echo "SESSION_SERVICE_URI=agentengine://${ENGINE_NAME}"
echo "MEMORY_SERVICE_URI=agentengine://${ENGINE_NAME}"
echo

# 7. Create a memory under the engine
echo "Creating a test memory"
MEMORY="{
    \"fact\": \"My first memory.\",
    \"scope\": {\"placeholder\": \"true\"}
  }"
curl -s -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  "https://${LOCATION}-aiplatform.googleapis.com/v1/${ENGINE_NAME}/memories" \
  -d "${MEMORY}"

# 8. Create a session under the engine
echo "Creating a test session"
SESSION="{
    \"userId\": \"example-user\"
  }"
curl -s -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  "https://${LOCATION}-aiplatform.googleapis.com/v1/${ENGINE_NAME}/sessions" \
  -d "${SESSION}"
