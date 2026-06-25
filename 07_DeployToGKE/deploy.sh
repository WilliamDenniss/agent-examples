#!/bin/bash
set -e

# Deploy the trading agent to GKE.
#
# The Alpaca keys and the Agent Platform Session + Memory service URIs are all
# injected via a Kubernetes Secret rather than hardcoded in deploy.yaml.
#
# Prereq: make sure kubectl points at your GKE cluster
# (gcloud container clusters get-credentials ...).

NAMESPACE="trading"
SECRET_NAME="trading-agent-secrets"

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

# Namespace (ignore error if it already exists).
kubectl create namespace "$NAMESPACE" 2>/dev/null || true

# --- Step 1: Credentials + service URIs as a Secret ---
# Recreate idempotently so re-running picks up rotated keys or new URIs.
echo "Creating secret ${NAMESPACE}/${SECRET_NAME}..."
kubectl create secret generic "$SECRET_NAME" \
  --namespace "$NAMESPACE" \
  --from-literal=APCA_API_KEY_ID="$APCA_API_KEY_ID" \
  --from-literal=APCA_API_SECRET_KEY="$APCA_API_SECRET_KEY" \
  --from-literal=SESSION_SERVICE_URI="$SESSION_SERVICE_URI" \
  --from-literal=MEMORY_SERVICE_URI="$MEMORY_SERVICE_URI" \
  --dry-run=client -o yaml | kubectl apply -f -

# --- Step 2: Workload Identity ---
# Bind the trading-agent KSA to a GSA with roles/aiplatform.user so the pod can
# reach the agentengine:// Sessions + Memory services without keys. Idempotent,
# so it's safe to re-run on every deploy.
echo "Configuring Workload Identity..."
./configure_workload_identity.sh

# --- Step 3: Apply the Deployment ---
echo "Applying deploy.yaml..."
kubectl apply -f deploy.yaml

echo ""
echo "Deployment complete!"
echo "Forward traffic with:"
echo "  kubectl port-forward -n ${NAMESPACE} deploy/trading-agent 8080:8080"
