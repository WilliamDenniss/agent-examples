# Deploy the Agent Platform Backend

Steps:

1. Create a Python environment

Install venv if needed
```
apt update
apt install python3.12-venv
```

Create the environment on the first run:
```
python3 -m venv agent-env
source agent-env/bin/activate
pip install -r backend_agent/requirements.txt
```

Use the environment on subsequent runs:
```
source agent-env/bin/activate
```


3. Deploy to Agent Platform

```
python deploy_backend.py
```

4. Note the resource paths

Make a note of the resource URI (printed as `SESSION_SERVICE_URI` and `MEMORY_SERVICE_URI`), these will be needed later to utilize the backend.
