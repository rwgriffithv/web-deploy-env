#!/usr/bin/env bash
#
# scripts/deploy.sh
#
# Builds (or skips build with --skip-build) and deploys the web app.
#   ./deploy.sh          — full build + deploy
#   ./deploy.sh --skip-build — quick restart using existing images
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
# Parse Arguments
########################################

SKIP_BUILD=false
for arg in "$@"; do
    case "$arg" in
        --skip-build) SKIP_BUILD=true ;;
        *) warn "Unknown argument: $arg" ;;
    esac
done

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
# Build
########################################

if [[ "$SKIP_BUILD" == true ]]; then
    info "Skipping build (--skip-build). Using existing images."
else
    info "Building images for ${DOMAIN}..."
    $COMPOSE_CMD build --build-arg BUILDKIT_INLINE_CACHE=1
    success "Build complete."
fi

########################################
# Database initialization
########################################

DB_FILE="./data/sqlite/prod.db"
mkdir -p "$(dirname "$DB_FILE")"

if [[ ! -f "$DB_FILE" ]]; then
    info "No production database found. Initializing..."
    if DATABASE_URL="file:${DB_FILE}" npm run db:init 2>/dev/null; then
        success "Database initialized at ${DB_FILE}."
    else
        warn "Could not auto-initialize database (tsx not available?)."
        warn "Make sure db:init is defined in your package.json for auto initialization."
    fi
else
    success "Production database found at ${DB_FILE}."
fi

########################################
# Deploy
########################################

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
