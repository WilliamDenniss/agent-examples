# Deploy the trading agent to GKE

Run the containerized trading agent on GKE, with sessions and memory backed by
Agent Platform. Config stays out of the manifest — the Alpaca keys and the
Session + Memory service URIs all go in a Kubernetes Secret.

First set up Workload Identity, so the pod can reach Vertex AI without keys:

```
./configure_workload_identity.sh
```

Then export your config and deploy:

```
export APCA_API_KEY_ID=...
export APCA_API_SECRET_KEY=...
export SESSION_SERVICE_URI=agentengine://projects/PROJECT/locations/REGION/reasoningEngines/ENGINE_ID
export MEMORY_SERVICE_URI=$SESSION_SERVICE_URI
./deploy.sh
```

These four vars can also live in the repo-root `.env` — `deploy.sh` sources it
automatically, so you can just set them once there and run `./deploy.sh`.

`deploy.sh` checks those four vars are set, (re)creates the `trading-agent-secrets`
Secret from them, and applies `deploy.yaml`.

Note: update the `image:` in `deploy.yaml` to point at your own build if you like.

To forward traffic:

```
kubectl port-forward -n trading deploy/trading-agent 8080:8080
```
