#!/usr/bin/env bash
#
# scripts/backup.sh
#
# Creates a backup of the database of the deployed web-app.
#
set -euo pipefail

BACKUP_DIR="./data/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
mkdir -p "$BACKUP_DIR"

echo "Backing up SQLite database..."
# Assuming you use a volume mapping like ./data/sqlite:/app/data
tar -czf "$BACKUP_DIR/db_backup_$TIMESTAMP.tar.gz" -C ./data/sqlite .

echo "Backup created at $BACKUP_DIR/db_backup_$TIMESTAMP.tar.gz"
