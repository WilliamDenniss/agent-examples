docker build . -t trading_agent
docker run -it --rm --env-file docker-env -p 8080:8080 trading_agent
