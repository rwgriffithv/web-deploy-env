# Deploy Script Walkthrough

The `deploy.sh` script orchestrates the multi-stage Docker build and service startup. It is symlinked to the project root by `bootstrap.sh`.

## Stages

| # | Stage | Lines | What It Does |
|---|-------|-------|--------------|
| 1 | Env Validation | 39–52 | Checks `DOMAIN` and `TUNNEL_TOKEN` are set |
| 2 | Certificate Check | 58–64 | Verifies `data/certs/origin.pem` and `data/certs/privkey.pem` exist |
| 3 | Compose Detection | 70–78 | Picks `docker compose` (plugin) or `docker-compose` (standalone) |
| 4 | Build | 84–86 | Runs `docker compose build --pull` with inline cache |
| 5 | Start Services | 88–90 | Runs `docker compose up -d` |
| 6 | Health Check | 96–109 | Sleeps 5s, then checks each service shows `Up` status |
| 7 | Summary | 115–121 | Prints success or instructions for troubleshooting |

## Stage Details

### 1. Env Validation
Required variables: `DOMAIN`, `TUNNEL_TOKEN`. If either is missing, the script exits with a warning listing which variables are unset. Define them in `.env` at the project root.

### 2. Certificate Check
The script checks for `data/certs/origin.pem` and `data/certs/privkey.pem`. Without these, Caddy cannot terminate TLS. See `docs/cloudflare-setup.md` for generation instructions.

### 3. Compose Detection
Prefer `docker compose` (v2 plugin). Falls back to `docker-compose` (v1 standalone). If neither is found, exits with an install prompt.

### 4. Build
Runs `docker compose build --pull --build-arg BUILDKIT_INLINE_CACHE=1`. The `--pull` flag ensures base images are fresh. The `BUILDKIT_INLINE_CACHE=1` arg embeds cache metadata into the image for faster subsequent builds.

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
| 1 | Missing env vars, certs, or Docker Compose |
| 0 (with warnings) | Build/start succeeded but some services unhealthy |

## Common Failure Modes

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `TLS certificates not found` | Cert files missing or wrong path | Place `origin.pem` and `privkey.pem` in `data/certs/` |
| `Required env var 'X' not set` | Missing `.env` or variable | Add to `.env` at project root |
| `Docker Compose not found` | Docker Compose not installed | Install Docker Compose v2 plugin |
| Tunnel shows `Connected` but site returns 502 | Caddy not running or health check failing | `docker compose logs caddy` |
| Build fails on `npm install` | Network issue or package lock conflict | Check network, try `npm install` locally first |
