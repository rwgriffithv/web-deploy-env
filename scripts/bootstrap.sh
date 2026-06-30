#!/usr/bin/env bash
#
# scripts/bootstrap.sh
#
# Bootstraps a parent repository using the shared web-deploy-env submodule.
#
set -euo pipefail

# Load .env file if it exists
set -a; [ -f .env ] && . .env; set +a

########################################
# Logging
########################################

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RED="\033[0;31m"
NC="\033[0m"

info()    { echo -e "${BLUE}==>${NC} $*"; }
success() { echo -e "${GREEN}*${NC} $*"; }
warn()    { echo -e "${YELLOW}*${NC} $*"; }
fail()    { echo -e "${RED}*${NC} $*"; exit 1; }

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
# Devcontainer guard
########################################

if [[ -n "${REMOTE_CONTAINERS:-}" ]] || [[ -n "${CODESPACES:-}" ]]; then
    fail "Devcontainer environment detected. Bootstrap must run on host."
fi

########################################
# Build Default Prod Base Image
########################################

IMAGE_REGISTRY="${IMAGE_REGISTRY:-local}"
DEFAULT_PROD_BASE_IMAGE="${IMAGE_REGISTRY}/web-deploy-base:latest"

if [[ "$FORCE_OVERWRITE" == true ]] || [[ -z "$(docker images -q "${DEFAULT_PROD_BASE_IMAGE}")" ]]; then
    info "Building default prod base image: ${DEFAULT_PROD_BASE_IMAGE}..."
    docker build -t "${DEFAULT_PROD_BASE_IMAGE}" -f "${SUBMODULE_DIR}/Dockerfile.base" "${SUBMODULE_DIR}"
    success "Built base image."
else
    success "Default prod base image ${DEFAULT_PROD_BASE_IMAGE} already exists."
fi

########################################
# Create data directories
########################################

mkdir -p "${PROJECT_DIR}/data/sqlite" "${PROJECT_DIR}/data/backups"

########################################
# Sync infrastructure templates
########################################

info "Syncing infrastructure templates..."
ln -sf "${SUBMODULE_REL}/templates/Dockerfile" "${PROJECT_DIR}/Dockerfile"
ln -sf "${SUBMODULE_REL}/templates/docker-compose.yml" "${PROJECT_DIR}/docker-compose.yml"
ln -sf "${SUBMODULE_REL}/templates/Caddyfile" "${PROJECT_DIR}/Caddyfile"
ln -sf "${SUBMODULE_REL}/templates/.dockerignore" "${PROJECT_DIR}/.dockerignore"
success "Templates synchronized."

########################################
# Expose utility scripts
########################################

info "Linking utility scripts..."
for script in deploy backup down; do
    ln -sf "${SUBMODULE_REL}/scripts/${script}.sh" "${PROJECT_DIR}/${script}.sh"
    chmod +x "${SUBMODULE_DIR}/scripts/${script}.sh"
done
success "Utility scripts linked."

########################################
# Final Summary
########################################

echo -e "\n----------------------------------------"
success "Bootstrap complete."
echo "  Next steps:"
echo "   1. Create a Cloudflare tunnel and set DOMAIN + TUNNEL_TOKEN in .env"
echo "   2. Run ./deploy.sh to build and start"
echo "      Use ./deploy.sh --skip-build to restart with existing images"
echo "   3. Run ./down.sh to stop all services"
