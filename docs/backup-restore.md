# Backup & Restore

## Creating a Backup

```bash
./backup.sh
```

This creates a compressed tarball of the SQLite data directory at `./data/backups/` with a timestamped filename:

```
data/backups/
├── db_backup_20260629_120000.tar.gz
├── db_backup_20260629_120000.tar.gz.sha256
└── ...
```

Each backup is accompanied by a SHA-256 checksum for integrity verification. Backups older than 7 days are automatically rotated (deleted).

### Configuration

The script respects these environment variables (can be set in `.env`):

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKUP_DIR` | `./data/backups` | Where backup files are stored |
| `SOURCE_DIR` | `./data/sqlite` | The data directory to back up |
| `BACKUP_ROTATION_KEEP` | `7` | Days of backups to retain |
| `BACKUP_DRY_RUN` | `false` | Set to `true` to preview without creating |

### Dry Run

```bash
BACKUP_DRY_RUN=true ./backup.sh
```

Shows what would be backed up and rotated without writing any files.

## Listing Backups

Backup files are stored as plain `.tar.gz` files in `./data/backups/`. List them with:

```bash
ls -lh ./data/backups/
```

Each backup pair consists of:
- `db_backup_YYYYMMDD_HHMMSS.tar.gz` — the compressed data
- `db_backup_YYYYMMDD_HHMMSS.tar.gz.sha256` — integrity checksum

## Verifying Backup Integrity

```bash
sha256sum -c ./data/backups/db_backup_20260629_120000.tar.gz.sha256
```

This recomputes the SHA-256 of the backup file and compares it against the stored checksum.

## Restoring from a Backup

1. **Stop the running services** to prevent data corruption:

   ```bash
   docker compose down
   ```

2. **Extract the backup to a temporary location**:

   ```bash
   mkdir -p /tmp/db-restore
   tar -xzf ./data/backups/db_backup_20260629_120000.tar.gz -C /tmp/db-restore
   ```

3. **Replace the current data directory**:

   ```bash
   cp -a /tmp/db-restore/. ./data/sqlite/
   ```

4. **Start the services**:

   ```bash
   ./deploy.sh
   ```

5. **Verify the data** is accessible:

   ```bash
   docker compose exec webapp node -e "require('http').get('http://localhost:3000/api/health', r => process.exit(r.statusCode === 200 ? 0 : 1))"
   ```

6. **Clean up** the temporary directory:

   ```bash
   rm -rf /tmp/db-restore
   ```
