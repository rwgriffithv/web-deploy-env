#!/usr/bin/env bash
#
# scripts/deploy.sh
#
# Builds and deploys the web app deployment container.
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
# Devcontainer guard
########################################

if [[ -n "${REMOTE_CONTAINERS:-}" ]] || [[ -n "${CODESPACES:-}" ]]; then
    fail "Devcontainer environment detected. Deploy must run on host."
fi

########################################
# Environment Variables
########################################

REQUIRED_VARS=("DOMAIN" "TUNNEL_TOKEN")
missing_vars=false

for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        warn "Required environment variable '$var' is not set.
Please ensure it is defined in your .env file or set manually."
        missing_vars=true
    fi
done

if [[ "$missing_vars" == true ]]; then
    fail "Missing required environment variables"
fi

########################################
# Certificates
########################################

CERTS_DIR="./data/certs"
if [[ ! -f "${CERTS_DIR}/origin.pem" ]] || [[ ! -f "${CERTS_DIR}/privkey.pem" ]]; then
    fail "TLS certificates not found in ${CERTS_DIR}/.
       Place origin.pem and privkey.pem in that directory.
       See web-deploy-env/docs/cloudflare-setup.md for instructions."
fi
success "TLS certificates found."

########################################
# Compose Command Detection
########################################

COMPOSE_CMD=""
if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
else
    fail "Docker Compose not found. Please install Docker Compose."
fi
info "Using: ${COMPOSE_CMD}"

########################################
# Build and Deploy
########################################

info "Building images for ${DOMAIN}..."
$COMPOSE_CMD build --pull --build-arg BUILDKIT_INLINE_CACHE=1
success "Build complete."

info "Starting services..."
$COMPOSE_CMD up -d
success "Services started."

########################################
# Health Check
########################################

info "Waiting for services to be ready..."
sleep 5

SERVICES=$($COMPOSE_CMD ps --services 2>/dev/null)
HEALTHY=true
for svc in $SERVICES; do
    status=$($COMPOSE_CMD ps "$svc" --format '{{.Status}}' 2>/dev/null)
    if echo "$status" | grep -q "^Up"; then
        success "$svc is running."
    else
        warn "$svc is not running (status: ${status:-unknown})."
        HEALTHY=false
    fi
done

########################################
# Final Summary
########################################

echo -e "\n----------------------------------------"
if [[ "$HEALTHY" == true ]]; then
    success "Deployment complete."
else
    warn "Deployment finished but some services are not running."
    info "Check logs with: $COMPOSE_CMD logs <service>"
fi
