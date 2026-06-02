docker build . -t trading_agent

docker run -it --rm \
  --env-file docker-env-remote \
  -v ~/.config/gcloud:/root/.config/gcloud:ro \
  -p 8080:8080 trading_agent
