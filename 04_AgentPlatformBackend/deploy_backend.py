import google.auth

# Project ID is read from your environment / Application Default Credentials.
_, PROJECT_ID = google.auth.default()
if not PROJECT_ID:
    raise ValueError("No project found. Set GOOGLE_CLOUD_PROJECT or run: gcloud config set project <id>")
LOCATION = "us-west1"

import vertexai

client = vertexai.Client(project=PROJECT_ID, location=LOCATION)

# create the resource
memory_bank = client.agent_engines.create(
    config={
        "display_name": "Agent Backend Resource",
    }
)
engine_name = memory_bank.api_resource.name
print(engine_name)

client.agent_engines.memories.create(
    name=engine_name,
    fact="My first memory.",
    scope={"placeholder": "true"},
)

client.agent_engines.sessions.create(
    name=engine_name,
    user_id="example-user",
)
print()
print("Deployment complete!")
print(f"Resource name: {engine_name}")
print()
print("Add these to your docker-env (or deploy env):")
print(f"SESSION_SERVICE_URI=agentengine://{engine_name}")
print(f"MEMORY_SERVICE_URI=agentengine://{engine_name}")
