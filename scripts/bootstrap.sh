#!/usr/bin/env bash
#
# scripts/bootstrap.sh
#
# Bootstraps a parent repository using the shared web-deploy-env submodule.
#
set -euo pipefail

# Load .env file if it exists
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

########################################
# Logging
########################################

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

info() { echo -e "${BLUE}==>${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; exit 1; }

########################################
# Devcontainer guard
########################################

if [[ -n "${REMOTE_CONTAINERS:-}" ]] || [[ -n "${CODESPACES:-}" ]]; then
    fail "Devcontainer environment detected. Bootstrap must run on host."
fi

########################################
# Pathing
########################################

SUBMODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$(pwd)"
SUBMODULE_REL="${SUBMODULE_DIR#"${PROJECT_DIR}/"}"

[[ "$PROJECT_DIR" == "$SUBMODULE_DIR" ]] && fail "Bootstrap must be run from the parent repository."

########################################
# Parse Arguments
########################################

FORCE_OVERWRITE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE_OVERWRITE=true
    info "Forcing overwrites..."
fi

########################################
# Environment Variables
########################################

REQUIRED_VARS=("DOMAIN" "TUNNEL_TOKEN")

for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        warn "Required environment variable '$var' is not set.
Please ensure it is defined in your .env file or set manually."
    fi
done

########################################
# Build Default Prod Base Image
########################################

# Set default images
IMAGE_REGISTRY="${IMAGE_REGISTRY:-local}"
DEFAULT_PROD_BASE_IMAGE="${IMAGE_REGISTRY}/web-deploy-base:latest"
export DEV_BASE_IMAGE="${DEV_BASE_IMAGE:-${IMAGE_REGISTRY}/agent-dev-env:latest}"
export PROD_BASE_IMAGE="${PROD_BASE_IMAGE:-${DEFAULT_PROD_BASE_IMAGE}}"

# Check if the output of docker images -q is empty
if [[ "$FORCE_OVERWRITE" == true ]] || [[ -z "$(docker images -q "${DEFAULT_PROD_BASE_IMAGE}")" ]]; then
    info "Building default prod base image: ${DEFAULT_PROD_BASE_IMAGE}..."
    docker build -t "${DEFAULT_PROD_BASE_IMAGE}" -f "${SUBMODULE_DIR}/Dockerfile.base" "${SUBMODULE_DIR}"
    success "Built base image."
else
    success "Default prod base image ${DEFAULT_PROD_BASE_IMAGE} already exists."
fi

########################################
# Process Dockerfile Template
########################################

mkdir -p "${PROJECT_DIR}/deploy"
DOCKERFILE_DEST="${PROJECT_DIR}/deploy/Dockerfile"

if [[ ! -f "$DOCKERFILE_DEST" || "$FORCE_OVERWRITE" == true ]]; then
    info "Generating ./deploy/Dockerfile from template..."
    envsubst < "${SUBMODULE_DIR}/templates/Dockerfile" > "$DOCKERFILE_DEST"
    success "Generated Dockerfile."
else
    success "Dockerfile already exists. Skipping."
fi

########################################
# Sync infrastructure templates
########################################

info "Syncing infrastructure templates..."
ln -sf "${SUBMODULE_REL}/templates/docker-compose.yml" "${PROJECT_DIR}/docker-compose.yml"
ln -sf "${SUBMODULE_REL}/templates/Caddyfile" "${PROJECT_DIR}/Caddyfile"
success "Templates synchronized."

########################################
# Expose utility scripts
########################################

info "Linking utility scripts..."
for script in deploy backup; do
    ln -sf "${SUBMODULE_REL}/scripts/${script}.sh" "${PROJECT_DIR}/${script}.sh"
    chmod +x "${SUBMODULE_DIR}/scripts/${script}.sh"
done
success "Utility scripts linked."

########################################
# Final Summary
########################################

echo -e "\n----------------------------------------"
success "Bootstrap complete."
