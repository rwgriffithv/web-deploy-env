#!/usr/bin/env bash
#
# scripts/bootstrap.sh
#
# Bootstraps a parent repository using the shared agent-dev-env submodule.
#
set -euo pipefail

SUBMODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT_DIR="$(pwd)"

# 0. Validate Environment
# 0. Invoke the validator
# Ensure the .env file is loaded if it exists
if [ -f "${PARENT_DIR}/.env" ]; then
    export $(grep -v '^#' "${PARENT_DIR}/.env" | xargs)
fi
"${SUBMODULE_DIR}/scripts/validate-env.sh"

# Set defaults
export DEV_BASE_IMAGE="${DEV_BASE_IMAGE:-my-org/agent-dev-env:latest}"
export PROD_BASE_IMAGE="${PROD_BASE_IMAGE:-my-org/web-deploy-base:latest}"

FORCE_OVERWRITE="${FORCE_OVERWRITE:-false}"
if [[ "${1:-}" == "--force" ]]; then FORCE_OVERWRITE=true; fi

log() { printf "[web-deploy-env] %s\n" "$*"; }

# 1. Process Dockerfile Template
mkdir -p "${PARENT_DIR}/deploy"
DOCKERFILE_DEST="${PARENT_DIR}/deploy/Dockerfile"

if [[ ! -f "$DOCKERFILE_DEST" || "$FORCE_OVERWRITE" == true ]]; then
    log "Generating ./deploy/Dockerfile from template..."
    # envsubst replaces ${VARIABLES} in the file with their exported values
    envsubst < "${SUBMODULE_DIR}/templates/Dockerfile" > "$DOCKERFILE_DEST"
else
    log "Dockerfile already exists. Skipping."
fi

# 2. Copy/Link helper scripts and configs
log "Syncing infrastructure templates..."

ln -sf "${SUBMODULE_DIR}/templates/docker-compose.yml" "${PARENT_DIR}/"
ln -sf "${SUBMODULE_DIR}/templates/Caddyfile" "${PARENT_DIR}/"

# 3. Expose deployment and backup scripts
log "Linking utility scripts..."
for script in deploy backup; do
    ln -sf "${SUBMODULE_DIR}/scripts/${script}.sh" "${PARENT_DIR}/${script}.sh"
    chmod +x "${SUBMODULE_DIR}/scripts/${script}.sh"
done

log "Bootstrap complete."
