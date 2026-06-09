# Replace with your project ID, bucket name and preferred region.
PROJECT_ID = "your-project-id"
LOCATION = "us-west1"

if PROJECT_ID == "your-project-id":
    raise ValueError("Set PROJECT_ID to your Google Cloud project ID in backend_deploy.py")

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
