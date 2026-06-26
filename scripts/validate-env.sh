#!/usr/bin/env bash
#
# scripts/validate-env.sh
#
# Validate required environment variables are set.
#
set -euo pipefail

log() { printf "[web-deploy-env:validate] %s\n" "$*"; }

log "Validating environment requirements..."

# 1. Check for system dependencies
if ! command -v envsubst &> /dev/null; then
    echo "Error: 'envsubst' is not installed. Please install 'gettext'."
    exit 1
fi

# 2. Check for required variables
REQUIRED_VARS=("DOMAIN" "TUNNEL_TOKEN" "IMAGE_REGISTRY")

for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo "Error: Required environment variable '$var' is not set."
        echo "Please ensure it is defined in your .env file."
        exit 1
    fi
done

log "Environment validation passed."
