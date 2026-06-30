#!/usr/bin/env bash
#
# scripts/down.sh
#
# Tears down the deployed services started by deploy.sh.
# Counterpart to deploy.sh — stops containers and cleans up.
#
set -euo pipefail

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
    fail "Devcontainer environment detected. Must run on host."
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
    fail "Docker Compose not found."
fi
info "Using: ${COMPOSE_CMD}"

########################################
# Stop Services
########################################

info "Stopping services..."
$COMPOSE_CMD down
success "Services stopped."

########################################
# Final Summary
########################################

echo -e "\n----------------------------------------"
success "Teardown complete."
info "To restart, run ./deploy.sh"
