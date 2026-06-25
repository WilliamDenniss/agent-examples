#!/bin/bash
set -e

# Deploy the containerized trading agent to Agent Runtime using
# Bring Your Own Container (BYOC).
#
# Unlike 06_DeployToCloudRun / 07_DeployToGKE (which run the same container on a
# generic platform and talk back to an Agent Platform backend for sessions +
# memory), BYOC deploys the container to Agent Runtime *itself* as a
# reasoningEngine. Agent Runtime pulls the image from Artifact Registry and runs
# it, then exposes it via the standard :query / :streamQuery endpoints (see
# trade.sh).

# Configuration via env vars, with fallbacks so you don't have to edit this file.
# PROJECT_ID defaults to your active gcloud project.
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-us-west1}"
DISPLAY_NAME="${DISPLAY_NAME:-Trading Agent (BYOC)}"

# Build + push this image from ../08_ContainerizedForAgentPlatform (the FastAPI/BYOC
# variant that serves the :query / :streamQuery contract), e.g.:
#   gcloud builds submit ../08_ContainerizedForAgentPlatform --tag "$IMAGE"
# Derived from PROJECT_ID/REGION; override by exporting IMAGE.
IMAGE="${IMAGE:-${REGION}-docker.pkg.dev/${PROJECT_ID}/trading-agent/trading-agent/agent-byoc:1}"

if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: no project set. Run 'gcloud config set project YOUR_PROJECT' or export PROJECT_ID." >&2
  exit 1
fi

# Verify Alpaca credentials
if [[ -z "$APCA_API_KEY_ID" || -z "$APCA_API_SECRET_KEY" ]]; then
  echo "Error: APCA_API_KEY_ID and APCA_API_SECRET_KEY environment variables must be set." >&2
  exit 1
fi

# Fail fast if the image isn't in Artifact Registry yet: Agent Runtime would
# otherwise accept the deploy and only fail the image pull minutes later.
echo "Checking image ${IMAGE}..."
if ! gcloud artifacts docker images describe "$IMAGE" >/dev/null 2>&1; then
  echo "Error: image not found in Artifact Registry: ${IMAGE}" >&2
  echo "Build + push it first, e.g.:" >&2
  echo "  gcloud builds submit ../08_ContainerizedForAgentPlatform --tag ${IMAGE}" >&2
  exit 1
fi

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

# Dedicated runtime identity (custom service account) for the agent, scoped to
# Vertex AI so it can reach the Agent Platform Sessions + Memory backend.
GSA="trading-agent"
GSA_EMAIL="${GSA}@${PROJECT_ID}.iam.gserviceaccount.com"

# --- Step 2: Runtime identity (custom service account) ---
echo "Configuring service account ${GSA_EMAIL}..."
gcloud iam service-accounts create "$GSA" --project "$PROJECT_ID" 2>/dev/null || true

# Sessions + Memory Bank access for the agent at runtime.
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:${GSA_EMAIL}" \
  --role roles/aiplatform.user \
  --condition=None

# To deploy with a custom service account you need Service Account User on it.
DEPLOYER=$(gcloud config get-value account 2>/dev/null)
gcloud iam service-accounts add-iam-policy-binding "$GSA_EMAIL" \
  --member "user:${DEPLOYER}" \
  --role roles/iam.serviceAccountUser \
  --condition=None

# --- Step 3: Let Agent Runtime pull the image ---
# Agent Runtime uses the Reasoning Engine service agent to pull your container.
echo "Ensuring the Reasoning Engine service agent exists..."
gcloud beta services identity create \
  --service=aiplatform.googleapis.com \
  --project="$PROJECT_ID" 2>/dev/null || true

RE_SA="service-${PROJECT_NUMBER}@gcp-sa-aiplatform-re.iam.gserviceaccount.com"
echo "Granting Artifact Registry Reader to ${RE_SA}..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:${RE_SA}" \
  --role roles/artifactregistry.reader \
  --condition=None

# --- Step 4: Create the agent on Agent Runtime (BYOC) ---
# containerSpec only carries the imageUri; the container must listen on the port
# Agent Runtime injects via $PORT (the 06_Containerized-BYOC CMD honors it).
# Env vars, resource limits, and scaling live under deploymentSpec.
# GOOGLE_CLOUD_PROJECT / GOOGLE_CLOUD_LOCATION are reserved (Agent Runtime injects
# them automatically), so they must not be listed in env.
#
# classMethods declares the agent's API surface so the platform can route
# :query / :streamQuery to the container's /api/* routes. The names + api_mode
# must match the methods main.py dispatches via AdkApp (api_mode: "" = sync,
# "async", "stream", "async_stream"). agentFramework enables the console playground.
echo "Creating the BYOC agent on Agent Runtime..."

PAYLOAD=$(cat <<JSON
{
  "displayName": "${DISPLAY_NAME}",
  "spec": {
    "serviceAccount": "${GSA_EMAIL}",
    "agentFramework": "google-adk",
    "deploymentSpec": {
      "resourceLimits": {"cpu": "2", "memory": "2Gi"},
      "env": [
        {"name": "GOOGLE_GENAI_USE_VERTEXAI", "value": "TRUE"},
        {"name": "APCA_API_KEY_ID", "value": "${APCA_API_KEY_ID}"},
        {"name": "APCA_API_SECRET_KEY", "value": "${APCA_API_SECRET_KEY}"}
      ]
    },
    "containerSpec": {
      "imageUri": "${IMAGE}"
    },
    "classMethods": [
      {"api_mode": "", "name": "get_session"},
      {"api_mode": "", "name": "list_sessions"},
      {"api_mode": "", "name": "create_session"},
      {"api_mode": "", "name": "delete_session"},
      {"api_mode": "async", "name": "async_get_session"},
      {"api_mode": "async", "name": "async_list_sessions"},
      {"api_mode": "async", "name": "async_create_session"},
      {"api_mode": "async", "name": "async_delete_session"},
      {"api_mode": "async", "name": "async_add_session_to_memory"},
      {"api_mode": "async", "name": "async_search_memory"},
      {"api_mode": "stream", "name": "stream_query"},
      {"api_mode": "async_stream", "name": "async_stream_query"},
      {"api_mode": "async_stream", "name": "streaming_agent_run_with_events"}
    ]
  }
}
JSON
)

RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  "https://${REGION}-aiplatform.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/reasoningEngines" \
  -d "${PAYLOAD}")

if echo "$RESPONSE" | grep -q '"error"'; then
  echo "Error: create request failed" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

OP_NAME=$(echo "$RESPONSE" | jq -r '.name')
if [[ -z "$OP_NAME" || "$OP_NAME" == "null" ]]; then
  echo "Error: could not parse operation name from response" >&2
  echo "$RESPONSE" >&2
  exit 1
fi
ENGINE_NAME="${OP_NAME%/operations/*}"

echo "Waiting for the agent to be created (this can take several minutes)..."
until [ "$(curl -s \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://${REGION}-aiplatform.googleapis.com/v1/${OP_NAME}" | jq -r '.done')" = "true" ]; do
  sleep 10
done

echo ""
echo "Deployment complete!"
echo "Resource name: ${ENGINE_NAME}"
echo ""
echo "Run the agent with:"
echo "  export RESOURCE_NAME=${ENGINE_NAME}"
echo "  ./trade.sh"
