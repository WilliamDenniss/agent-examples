#!/bin/bash
set -e

# project where Cloud Run runs (and the reasoning engine lives)
PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
  echo "Error: no gcloud project configured. Run 'gcloud config set project PROJECT_ID'." >&2
  exit 1
fi

REGION="us-west1"
SERVICE_NAME="trading-agent"

# Load config from ../.env if present (exports each KEY=value line).
if [[ -f ../.env ]]; then
  set -a
  source ../.env
  set +a
fi

# Require Alpaca credentials.
if [[ -z "$APCA_API_KEY_ID" || -z "$APCA_API_SECRET_KEY" ]]; then
  echo "Error: APCA_API_KEY_ID and APCA_API_SECRET_KEY environment variables must be set." >&2
  exit 1
fi

# Require the Agent Platform Session + Memory service URIs.
if [[ -z "$SESSION_SERVICE_URI" || -z "$MEMORY_SERVICE_URI" ]]; then
  echo "Error: SESSION_SERVICE_URI and MEMORY_SERVICE_URI environment variables must be set." >&2
  echo "  e.g. export SESSION_SERVICE_URI=agentengine://projects/PROJECT/locations/REGION/reasoningEngines/ENGINE_ID" >&2
  exit 1
fi

# Dedicated service account (Google Service Account) for the Cloud Run deployment.
GSA="trading-agent"
GSA_EMAIL="${GSA}@${PROJECT_ID}.iam.gserviceaccount.com"

# --- Step 1: Service account + IAM ---
# Run the agent as a dedicated identity (not the default Compute SA) scoped to
# just Vertex AI, so it can reach the Agent Platform Sessions + Memory Bank.
echo "Configuring service account ${GSA_EMAIL}..."

# Create the runtime service account (ignore error if it already exists)
gcloud iam service-accounts create "$GSA" --project "$PROJECT_ID" 2>/dev/null || true

# Grant Vertex AI access (Sessions + Memory Bank)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:${GSA_EMAIL}" \
  --role roles/aiplatform.user \
  --condition=None

# --- Step 2: Deploy to Cloud Run ---
echo "Deploying to Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
  --image docker.io/wdenniss/trading-agent:1 \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --service-account "$GSA_EMAIL" \
  --no-allow-unauthenticated \
  --set-env-vars "APCA_API_KEY_ID=${APCA_API_KEY_ID},APCA_API_SECRET_KEY=${APCA_API_SECRET_KEY},GOOGLE_GENAI_USE_VERTEXAI=TRUE,GOOGLE_CLOUD_PROJECT=${PROJECT_ID},GOOGLE_CLOUD_LOCATION=${REGION},SESSION_SERVICE_URI=${SESSION_SERVICE_URI},MEMORY_SERVICE_URI=${MEMORY_SERVICE_URI}" \
  --memory 2Gi \
  --cpu 2 \
  --timeout 300

echo ""
echo "Deployment complete!"
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region "$REGION" --project "$PROJECT_ID" --format="value(status.url)")
echo "Run the agent with:"
echo "  export SERVICE_URL=${SERVICE_URL}"
echo "  ./run_trade.sh"
