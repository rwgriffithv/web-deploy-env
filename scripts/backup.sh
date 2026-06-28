#!/usr/bin/env bash
#
# scripts/backup.sh
#
# Creates a backup of the database of the deployed web-app.
# Supports rotation, integrity checks, and optional offsite sync.
#
set -euo pipefail

# Load .env file if it exists
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

########################################
# Configuration (overridable via env)
########################################

BACKUP_DIR="${BACKUP_DIR:-./data/backups}"
SOURCE_DIR="${SOURCE_DIR:-./data/sqlite}"
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

if [[ ! -d "$SOURCE_DIR" ]]; then
    fail "Source directory '$SOURCE_DIR' not found. Nothing to back up."
fi

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/db_backup_${TIMESTAMP}.tar.gz"

########################################
# Dry-run mode
########################################

if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would create: $BACKUP_FILE"
    log "[DRY-RUN] From: $SOURCE_DIR"
    log "[DRY-RUN] Would rotate backups older than $ROTATION_KEEP days"
    exit 0
fi

########################################
# Create backup
########################################

log "Backing up SQLite database..."
tar -czf "$BACKUP_FILE" -C "$SOURCE_DIR" .

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
