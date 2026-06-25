import os
import vertexai
from dotenv import load_dotenv
from trading_agent.agent import app

load_dotenv('trading_agent/.env')
load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

# Replace with your project ID and preferred region.
PROJECT_ID = "your-project-id"
LOCATION = "us-west1"

if PROJECT_ID == "your-project-id":
    raise ValueError("Set PROJECT_ID to your Google Cloud project ID in deploy.py")

# Defaults to gs://$PROJECT_ID-trading-agent; override if needed.
STAGING_BUCKET = f"gs://{PROJECT_ID}-trading-agent"

vertexai.init(project=PROJECT_ID, location=LOCATION, staging_bucket=STAGING_BUCKET)

print("Deploying ADK Trading Agent with Memory Bank...")
client = vertexai.Client(project=PROJECT_ID, location=LOCATION)
remote_agent = client.agent_engines.create(
    agent=app,
    config={
        "staging_bucket": STAGING_BUCKET,
        "display_name": "Trading Agent ADK (Memory)",
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

print()
print("Deployment complete!")
print(f"Resource name: {remote_agent.api_resource.name}")