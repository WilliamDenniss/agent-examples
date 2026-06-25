import os
import google.auth
import vertexai
from dotenv import load_dotenv
from trading_agent.agent import app

load_dotenv('trading_agent/.env')
load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

# Project ID is read from your environment / Application Default Credentials.
_, PROJECT_ID = google.auth.default()
if not PROJECT_ID:
    raise ValueError("No project found. Set GOOGLE_CLOUD_PROJECT or run: gcloud config set project <id>")
LOCATION = "us-west1"

# Defaults to gs://$PROJECT_ID-trading-agent; override if needed.
STAGING_BUCKET = f"gs://{PROJECT_ID}-trading-agent"

vertexai.init(project=PROJECT_ID, location=LOCATION, staging_bucket=STAGING_BUCKET)

print(f"Deploying ADK Trading Agent with Memory Bank to project {PROJECT_ID}...")
client = vertexai.Client(project=PROJECT_ID, location=LOCATION)
remote_agent = client.agent_engines.create(
    agent=app,
    config={
        "staging_bucket": STAGING_BUCKET,
        "display_name": "Trading Agent ADK (Deterministic Memories)",
        "description": "An ADK agent that analyzes financial news and makes paper trades on Alpaca, with Memory Bank for cross-session recall.",
        "requirements": "trading_agent/requirements.txt",
        "extra_packages": ["trading_agent/agent.py"],
        "env_vars": {
            "APCA_API_KEY_ID": os.getenv("APCA_API_KEY_ID", ""),
            "APCA_API_SECRET_KEY": os.getenv("APCA_API_SECRET_KEY", ""),
            "GOOGLE_GENAI_USE_VERTEXAI": "TRUE",
        },
    },
)

resource_name = remote_agent.api_resource.name
resource_id = resource_name.split("/")[-1]

print()
print("Deployment complete!")
print(f"View in the console: https://console.cloud.google.com/agent-platform/runtimes/locations/{LOCATION}/agent-engines/{resource_id}/playground?project={PROJECT_ID}")
print()
print("To trade, export the resource name and run trade.sh:")
print(f"  export RESOURCE_NAME={resource_name}")
print("  ./trade.sh")