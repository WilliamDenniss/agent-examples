from google.adk.agents import Agent

# Minimal placeholder agent. Its only purpose is to be deployed to Agent
# Engine so that the deployment provides managed Sessions and a Memory Bank.
# The containerized trading agent connects to those services via
# SESSION_SERVICE_URI / MEMORY_SERVICE_URI (agentengine://<resource_id>).
root_agent = Agent(
    name="session_backend",
    model="gemini-2.0-flash",
    instruction="You are a placeholder. You only exist to host managed Sessions and Memory. Whatever the user asks, just reply 'I am a placeholder'.",
)
