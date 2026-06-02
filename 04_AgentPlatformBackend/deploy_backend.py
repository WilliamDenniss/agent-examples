"""Deploy the minimal backend agent to Agent Engine.

This agent does nothing on its own — its purpose is to exist as an Agent
Engine resource that provides managed Sessions and a Memory Bank. The
containerized trading agent connects to those services via the printed
SESSION_SERVICE_URI / MEMORY_SERVICE_URI (agentengine://<resource_id>).

Run from the 04_Containerized directory:

    python3 backend_deploy.py
"""

import json

import vertexai
from vertexai.agent_engines import AdkApp

from backend_agent.agent import root_agent

# Replace with your project ID, bucket name and preferred region.
PROJECT_ID = "your-project-id"
STAGING_BUCKET = "gs://your-bucket-name"
LOCATION = "us-west1"

if PROJECT_ID == "your-project-id":
    raise ValueError("Set PROJECT_ID to your Google Cloud project ID in backend_deploy.py")
if STAGING_BUCKET == "gs://your-bucket-name":
    raise ValueError("Set STAGING_BUCKET to your GCS bucket in backend_deploy.py")

vertexai.init(project=PROJECT_ID, location=LOCATION, staging_bucket=STAGING_BUCKET)
client = vertexai.Client(project=PROJECT_ID, location=LOCATION)

print("Deploying Sessions + Memory backend agent (this takes 5-10 minutes)...")
remote_agent = client.agent_engines.create(
    agent=AdkApp(agent=root_agent),
    config={
        "staging_bucket": STAGING_BUCKET,
        "display_name": "Trading Agent Sessions+Memory Backend",
        "description": "Minimal agent providing managed Sessions and Memory services.",
        "requirements": "backend_agent/requirements.txt",
        "extra_packages": ["backend_agent"],
        "env_vars": {
            "GOOGLE_GENAI_USE_VERTEXAI": "TRUE",
        },
    },
)

resource_name = remote_agent.api_resource.name

print()
print("Deployment complete!")
print(f"Resource name: {resource_name}")
print()
print("Add these to your docker-env (or deploy env):")
print(f"SESSION_SERVICE_URI=agentengine://{resource_name}")
print(f"MEMORY_SERVICE_URI=agentengine://{resource_name}")
