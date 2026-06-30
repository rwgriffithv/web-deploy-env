# Deploy Script Walkthrough

The `deploy.sh` script orchestrates the multi-stage Docker build and service startup. It is symlinked to the project root by `bootstrap.sh`.

## Stages

| # | Stage | Lines | What It Does |
|---|-------|-------|--------------|
| 1 | Env Validation | 39–52 | Checks `DOMAIN` and `TUNNEL_TOKEN` are set |
| 2 | Compose Detection | 70–78 | Picks `docker compose` (plugin) or `docker-compose` (standalone) |
| 3 | Build | 84–86 | Runs `docker compose build` with `BUILDKIT_INLINE_CACHE=1` (skipped with `--skip-build`) |
| 4 | Database Init | 95–108 | Creates `data/sqlite/prod.db` if missing |
| 5 | Start Services | 111–113 | Runs `docker compose up -d` |
| 6 | Health Check | 119–132 | Sleeps 5s, then checks each service shows `Up` status |
| 7 | Summary | 138–144 | Prints success or instructions for troubleshooting |

## Options

| Flag | Effect |
|------|--------|
| `--skip-build` | Skip Docker build, restart existing images |

## Stage Details

### 1. Env Validation
Required variables: `DOMAIN`, `TUNNEL_TOKEN`. If either is missing, the script exits with a warning listing which variables are unset. Define them in `.env` at the project root.

### 2. Compose Detection
Prefer `docker compose` (v2 plugin). Falls back to `docker-compose` (v1 standalone). If neither is found, exits with an install prompt.

### 3. Build
Runs `docker compose build --build-arg BUILDKIT_INLINE_CACHE=1`. The `BUILDKIT_INLINE_CACHE=1` arg embeds cache metadata into the image for faster subsequent builds. Pass `--skip-build` to reuse existing images (useful after config changes or crashes).

### 4. Database Init
If `data/sqlite/prod.db` does not exist, the script runs `DATABASE_URL="file:${DB_FILE}" npm run db:init` to auto-initialize.

The parent project **must** define a `db:init` script in `package.json` for this to work:

```json
"db:init": "tsx scripts/db-init.ts"
```

The toolkit delegates the *how* of database initialization entirely to the parent — it only provides the `DATABASE_URL` pointing to the production database path and calls the npm script. If the script is missing or fails, a warning is printed instructing the user to define `db:init` in `package.json`.

### 5. Start Services
Runs `docker compose up -d`. Containers start in dependency order: `webapp` → `caddy` → `tunnel`.

### 6. Health Check
After a 5-second settling period, the script enumerates all services and checks each for an `Up` status. Non-running services are flagged as warnings.

### 7. Summary
- **All services Up** → "Deployment complete."
- **Some services not running** → "Deployment finished but some services are not running." with a hint to run `docker compose logs <service>`.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All services running |
| 1 | Missing env vars or Docker Compose |
| 0 (with warnings) | Build/start succeeded but some services unhealthy |

## Common Failure Modes

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `Required env var 'X' not set` | Missing `.env` or variable | Add to `.env` at project root |
| `Docker Compose not found` | Docker Compose not installed | Install Docker Compose v2 plugin |
| Tunnel shows `Connected` but site returns 502 | Caddy not running or health check failing | `docker compose logs caddy` |
| Redirect loop (too many redirects) | Caddyfile uses `{$DOMAIN}` instead of `http://{$DOMAIN}` | Run `bootstrap.sh` to refresh the template |
| Build fails on `npm install` | Network issue or package lock conflict | Check network, try `npm install` locally first |
