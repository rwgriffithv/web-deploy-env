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

# Set defaults images
export DEV_BASE_IMAGE="${DEV_BASE_IMAGE:-${IMAGE_REGISTRY}/agent-dev-env:latest}"
export PROD_BASE_IMAGE="${PROD_BASE_IMAGE:-${IMAGE_REGISTRY}/web-deploy-base:latest}"

FORCE_OVERWRITE="${FORCE_OVERWRITE:-false}"
if [[ "${1:-}" == "--force" ]]; then FORCE_OVERWRITE=true; fi

log() { printf "[web-deploy-env] %s\n" "$*"; }

# 1. Build Base Image (Idempotent with --force support)
image_exists=$(docker images -q "${PROD_BASE_IMAGE}" 2> /dev/null || true)

if [[ -z "$image_exists" || "$FORCE_OVERWRITE" == true ]]; then
    log "Building base image: ${PROD_BASE_IMAGE}..."
    docker build -t "${PROD_BASE_IMAGE}" -f "${SUBMODULE_DIR}/Dockerfile.base" "${SUBMODULE_DIR}"
else
    log "Base image ${PROD_BASE_IMAGE} already exists. Skipping build."
fi

# 2. Process Dockerfile Template
mkdir -p "${PARENT_DIR}/deploy"
DOCKERFILE_DEST="${PARENT_DIR}/deploy/Dockerfile"

if [[ ! -f "$DOCKERFILE_DEST" || "$FORCE_OVERWRITE" == true ]]; then
    log "Generating ./deploy/Dockerfile from template..."
    # Note: ensure variables used in templates/Dockerfile are exported
    export DEV_BASE_IMAGE PROD_BASE_IMAGE
    envsubst < "${SUBMODULE_DIR}/templates/Dockerfile" > "$DOCKERFILE_DEST"
else
    log "Dockerfile already exists. Skipping."
fi

# 3. Sync infrastructure templates
log "Syncing infrastructure templates..."
ln -sf "${SUBMODULE_DIR}/templates/docker-compose.yml" "${PARENT_DIR}/"
ln -sf "${SUBMODULE_DIR}/templates/Caddyfile" "${PARENT_DIR}/"

# 4. Expose utility scripts
log "Linking utility scripts..."
for script in deploy backup; do
    ln -sf "${SUBMODULE_DIR}/scripts/${script}.sh" "${PARENT_DIR}/${script}.sh"
    chmod +x "${SUBMODULE_DIR}/scripts/${script}.sh"
done

log "Bootstrap complete."
