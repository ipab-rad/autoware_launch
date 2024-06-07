# Build docker image up to dev stage
DOCKER_BUILDKIT=1 docker build \
    --ssh default=$SSH_AUTH_SOCK \
    -t av_autoware:latest-dev \
    -f Dockerfile --target dev .


# DOCKER_BUILDKIT=1 docker build \
#     -t av_autoware:latest \
#     -f Dockerfile --target runtime .