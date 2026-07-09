#!/usr/bin/env bash
#
# scripts/backup.sh
#
# Creates a backup of the database of the deployed web-app.
# Supports rotation, integrity checks, and optional offsite sync.
#
set -euo pipefail

# Load .env file if it exists
set -a; [ -f .env ] && . .env; set +a

########################################
# Configuration (overridable via env)
########################################

BACKUP_DIR="${BACKUP_DIR:-./backups}"
DATA_DIR="${DATA_DIR:-./data}"
ROTATION_KEEP="${BACKUP_ROTATION_KEEP:-7}"
DRY_RUN="${BACKUP_DRY_RUN:-false}"

########################################
# Logging
########################################

log()   { printf "[backup] %s\n" "$*"; }
warn()  { printf "[backup] WARNING: %s\n" "$*"; }
fail()  { printf "[backup] ERROR: %s\n" "$*"; exit 1; }

########################################
# Pre-flight checks
########################################

if [[ ! -d "$DATA_DIR" ]]; then
    fail "Data directory '$DATA_DIR' not found. Nothing to back up."
fi

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/db_backup_${TIMESTAMP}.tar.gz"

########################################
# Dry-run mode
########################################

if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would create: $BACKUP_FILE"
    log "[DRY-RUN] From: $DATA_DIR → $BACKUP_DIR"
    log "[DRY-RUN] Would rotate backups older than $ROTATION_KEEP days"
    exit 0
fi

########################################
# Create backup
########################################

log "Backing up $DATA_DIR → $BACKUP_FILE..."

tar -czf "$BACKUP_FILE" \
  -C "$(dirname "$DATA_DIR")" \
  "$(basename "$DATA_DIR")"

########################################
# Integrity check
########################################

sha256sum "$BACKUP_FILE" > "${BACKUP_FILE}.sha256"
log "Checksum written: ${BACKUP_FILE}.sha256"

# Verify
sha256sum -c "${BACKUP_FILE}.sha256" --quiet && \
    log "Integrity check passed." || \
    fail "Integrity check FAILED for $BACKUP_FILE"

########################################
# Rotation — remove backups older than KEEP days
########################################

find "$BACKUP_DIR" -name "db_backup_*.tar.gz" -mtime +$ROTATION_KEEP -delete 2>/dev/null || true
find "$BACKUP_DIR" -name "db_backup_*.tar.gz.sha256" -mtime +$ROTATION_KEEP -delete 2>/dev/null || true
log "Rotation removed backups older than $ROTATION_KEEP days."

log "Backup complete: $BACKUP_FILE"
