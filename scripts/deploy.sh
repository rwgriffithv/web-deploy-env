#!/usr/bin/env bash
#
# scripts/deploy.sh
#
# Builds and deploys the web app deployment container.
#
set -euo pipefail

# 1. Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# 2. Build and Deploy
# We use the --build flag to ensure it picks up changes in the Dockerfile
# We specify the context as '.' and the file as 'deploy/Dockerfile'
log() { printf "[deploy] %s\n" "$*"; }

log "Starting deployment for ${DOMAIN}..."

docker compose build --build-arg BUILDKIT_INLINE_CACHE=1
docker compose up -d

log "Deployment complete."