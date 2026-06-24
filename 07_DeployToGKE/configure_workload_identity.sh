#!/bin/bash
set -e

# project where GKE runs (and the reasoning engine lives)
PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
  echo "Error: no gcloud project configured. Run 'gcloud config set project PROJECT_ID'." >&2
  exit 1
fi

# Kubernetes namespace where the agent will be deployed
NAMESPACE="trading"

# Sets up Workload Identity so the trading-agent pod can authenticate to
# Vertex AI (the agentengine:// Sessions + Memory services) without keys.

GSA="trading-agent"               # Google service account
KSA="trading-agent"               # Kubernetes service account (matches deploy.yaml)
GSA_EMAIL="${GSA}@${PROJECT_ID}.iam.gserviceaccount.com"

# 0. Namespace (ignore error if it already exists)
kubectl create namespace "$NAMESPACE" 2>/dev/null || true

# 1. Create the Google service account (ignore error if it already exists)
gcloud iam service-accounts create "$GSA" --project "$PROJECT_ID" 2>/dev/null || true

# 2. Grant it Vertex AI access (Sessions + Memory)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:${GSA_EMAIL}" \
  --role roles/aiplatform.user \
  --condition=None

# 3. Create the Kubernetes service account (ignore error if it already exists)
kubectl create serviceaccount "$KSA" --namespace "$NAMESPACE" 2>/dev/null || true

# 4. Let the KSA impersonate the GSA
gcloud iam service-accounts add-iam-policy-binding "$GSA_EMAIL" \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${KSA}]" \
  --condition=None

# 5. Annotate the KSA to link it to the GSA
kubectl annotate serviceaccount "$KSA" --namespace "$NAMESPACE" \
  iam.gke.io/gcp-service-account="$GSA_EMAIL" --overwrite

echo ""
echo "Workload Identity configured for ${NAMESPACE}/${KSA} -> ${GSA_EMAIL}"
