#!/bin/bash
set -e

PROJECT_ID="your-project-id"
REGION="us-west1"
SERVICE_NAME="trading-agent"

MEMORY_SERVICE_URI=agentengine://projects/555OOO555/locations/us-west1/reasoningEngines/5272175847371964416
SESSION_SERVICE_URI=$MEMORY_SERVICE_URI

if [[ "$MEMORY_SERVICE_URI" == *"555OOO555"* ]]; then
  echo "Error: Update MEMORY_SERVICE_URI your Agent resource." >&2
  exit 1
fi

set -a
source ../05_Containerized/docker-env
set +a

# Require Alpaca credentials (sourced from docker-env above).
if [[ -z "$APCA_API_KEY_ID" || -z "$APCA_API_SECRET_KEY" ]]; then
  echo "Error: APCA_API_KEY_ID and APCA_API_SECRET_KEY must be set (see ../05_Containerized/docker-env)." >&2
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
echo "Service URL:"
gcloud run services describe "$SERVICE_NAME" --region "$REGION" --project "$PROJECT_ID" --format="value(status.url)"
