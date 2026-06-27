#!/usr/bin/env bash
#
# scripts/bootstrap.sh
#
# Bootstraps a parent repository using the shared agent-dev-env submodule.
#
set -euo pipefail

# Load .env file if it exists
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

SUBMODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT_DIR="$(pwd)"

# 0. Validate Environment
"${SUBMODULE_DIR}/scripts/validate-env.sh"

# Set defaults images
# NOTE: find agent-dev-env images from https://github.com/rwgriffithv/agent-dev-env
# NOTE: if changing PROD_BASE_IMAGE, DEV_BASE_IMAGE should be rebuilt off of it
DEFAULT_PROD_BASE_IMAGE="${IMAGE_REGISTRY}/web-deploy-base:latest"
export DEV_BASE_IMAGE="${DEV_BASE_IMAGE:-${IMAGE_REGISTRY}/agent-dev-env:latest}"
export PROD_BASE_IMAGE="${PROD_BASE_IMAGE:-${DEFAULT_PROD_BASE_IMAGE}}"

FORCE_OVERWRITE="${FORCE_OVERWRITE:-false}"
if [[ "${1:-}" == "--force" ]]; then FORCE_OVERWRITE=true; fi

log() { printf "[web-deploy-env] %s\n" "$*"; }

# 1. Build Default Prod Base Image (Idempotent with --force support)
image_exists=$(docker images -q "${DEFAULT_PROD_BASE_IMAGE}" 2> /dev/null || true)

if [[ -z "$image_exists" || "$FORCE_OVERWRITE" == true ]]; then
    log "Building default prod base image: ${DEFAULT_PROD_BASE_IMAGE}..."
    docker build -t "${DEFAULT_PROD_BASE_IMAGE}" -f "${SUBMODULE_DIR}/Dockerfile.base" "${SUBMODULE_DIR}"
else
    log "Default prod base image ${DEFAULT_PROD_BASE_IMAGE} already exists. Skipping build."
fi

# 2. Process Dockerfile Template
mkdir -p "${PARENT_DIR}/deploy"
DOCKERFILE_DEST="${PARENT_DIR}/deploy/Dockerfile"

if [[ ! -f "$DOCKERFILE_DEST" || "$FORCE_OVERWRITE" == true ]]; then
    log "Generating ./deploy/Dockerfile from template..."
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
