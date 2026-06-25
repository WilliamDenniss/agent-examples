Read the blog post: https://wdenniss.com/adk-stock-trading-agent

Required steps:

1. Create the file `trading_agent/.env` and populate it with a [Gemini API key](https://aistudio.google.com/api-keys) (for local testing) and [Alpaca keys](https://alpaca.markets/).

Don't use quotes, just `KEY=value`

```
# Google AI Studio / Vertex AI Key for the ADK Agent
GOOGLE_API_KEY=your-key

# Alpaca API keys
APCA_API_KEY_ID=your-key-id
APCA_API_SECRET_KEY=your-key
```

2. Create a Python environment

Install venv if needed
```
apt update
apt install python3.12-venv
```

Create the environment on the first run:
```
python3 -m venv trading-env
source trading-env/bin/activate
pip install -r trading_agent/requirements.txt
```

Use the environment on subsequent runs:
```
source trading-env/bin/activate
```


3. Run locally

```
adk run trading_agent
```

4. Deploy to Agent Platform

```
python deploy.py
```

5. Connect

`deploy.py` prints a playground link — open it to chat with the deployed agent.

To drive it from the command line instead, export the resource name (also
printed by `deploy.py`) and reuse the sibling trade script, which runs a cycle
and then re-queries in a fresh session to demonstrate memory recall:

```
export RESOURCE_NAME=projects/.../locations/us-west1/reasoningEngines/...
../03_DeterministicMemories/trade.sh
```
