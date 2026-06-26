#!/usr/bin/env bash
#
# scripts/deploy.sh
#
# Builds and deploys the web app deployment container.
#
set -euo pipefail

# Build and deploy the project using the standard multi-stage target
docker compose build --build-arg TARGET=prod
docker compose up -d
