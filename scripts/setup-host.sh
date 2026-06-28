#!/usr/bin/env bash
#
# scripts/setup-host.sh
#
# Sets up a host environment to support web-deploy-env deployment.
#
set -euo pipefail

# Load .env file if it exists
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

########################################
# State
########################################

changed=false

########################################
# Logging
########################################

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m"

info()    { echo -e "${BLUE}==>${NC} $*"; }
success() { echo -e "${GREEN}*${NC} $*"; }
warn()    { echo -e "${YELLOW}*${NC} $*"; }
fail()    { echo -e "${RED}*${NC} $*"; exit 1; }

########################################
# Devcontainer guard
########################################

if [[ -n "${REMOTE_CONTAINERS:-}" ]] || [[ -n "${CODESPACES:-}" ]] || [[ -n "${DEVCONTAINER:-}" ]]; then
    fail "Devcontainer environment detected. Host setup must run on host."
fi

########################################
# Parse Arguments
########################################

FORCE_OVERWRITE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE_OVERWRITE=true
    info "Forcing overwrites..."
fi

########################################
# Detect OS
########################################

if [[ ! -f /etc/os-release ]]; then fail "Unsupported Linux distribution."; fi
source /etc/os-release
[[ "$ID" =~ ^(debian|ubuntu)$ ]] || fail "This script currently supports Debian and Ubuntu."

########################################
# Install apt packages if missing
########################################

install_if_missing() {
    local pkg="$1"

    if [ "$FORCE_OVERWRITE" = false ] && dpkg -s "$pkg" >/dev/null 2>&1; then
        success "$pkg already installed."
    else
        info "Installing $pkg..."
        sudo apt-get install -y "$pkg"
        changed=true
    fi
}

install_if_missing gettext

########################################
# Docker
########################################

if command -v docker >/dev/null; then
    success "Docker installed."
else
    fail "Docker not found. Please install Docker."
fi

########################################
# Pre-cache Images
########################################

pull_image() {
    local image="$1"

    # If not forcing, check if image exists
    if [ "$FORCE_OVERWRITE" = false ] && docker image inspect "$image" >/dev/null 2>&1; then
        success "Image $image already cached."
    else
        info "Pulling $image..."
        docker pull "$image"
        changed=true
    fi
}

info "Caching deployment infrastructure images (Force: ${FORCE_OVERWRITE})..."
pull_image "caddy:2.8-alpine"
pull_image "cloudflare/cloudflared:2024.6.1"

########################################
# Final Summary
########################################

echo -e "\n----------------------------------------"
if [ "$changed" = true ] || [ "$FORCE_OVERWRITE" = true ]; then
    success "Host setup completed."
else
    success "Host already configured."
fi
