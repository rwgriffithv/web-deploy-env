# Web Deployment Environment

A version-controlled **infrastructure deployment toolkit** designed to be included as a **Git submodule** in web projects.

Rather than duplicating Docker configurations, Caddyfile reverse-proxy rules, and deployment scripts across multiple websites, `web-deploy-env` provides a centralized foundation for production-ready deployments.

The result is a consistent, secure, and easily maintainable deployment stack that evolves independently of the applications it hosts.

---

## Architecture

### Caddy's Role — Security Gateway, Not TLS Terminator

Caddy sits between the Cloudflare Tunnel and the application as a **security gateway**. It does not terminate TLS — Cloudflare handles that at the edge. Instead, Caddy provides defense-in-depth:

- **Network isolation** — The webapp is locked on the `backend` network (no internet access). Caddy bridges `frontend` and `backend`, so the tunnel can only reach the webapp through Caddy.
- **Security headers** — HSTS, CSP, X-Frame-Options, and others are injected at the proxy layer. Done here, they work regardless of what the application framework does.
- **Future flexibility** — The same setup works with any reverse proxy or CDN without application changes.

A typical project using this submodule looks like this:

```text
parent-project/
├── .dockerignore           # Symlinked from submodule (reduces build context)
├── Dockerfile              # Symlinked from submodule (multi-stage build)
├── data/                   # Persistent storage
│   ├── sqlite/             # SQLite database volume
│   └── backups/            # Automated backup snapshots
├── .env                    # Secrets and configuration
├── docker-compose.yml      # Symlinked from submodule
├── Caddyfile               # Symlinked from submodule
├── deploy.sh               # Symlinked utility
├── down.sh                 # Symlinked utility
├── backup.sh               # Symlinked utility
│
└── web-deploy-env/         # Git submodule
    ├── templates/          # Source templates (Caddy, Docker, etc.)
    ├── scripts/            # Orchestration logic
    └── docs/               # Architecture & setup guides
```

### Service Architecture

Three Docker services connected over two isolated networks:

```
                    Cloudflare Edge
                          |
                    Cloudflare Tunnel
                          |
                    ┌─────┘
              [frontend network]
                    |
          Caddy (security gateway — reverse proxy, security headers)
                    |
              [backend network] (internal, no internet)
                    |
         webapp (application server on :3000)
                    |
               SQLite (/app/data)
```

| Service | Image | Networks | Purpose |
|---------|-------|----------|---------|
| **tunnel** | `cloudflare/cloudflared:2026.6.1` | frontend only | Outbound-only connection to Cloudflare edge |
| **caddy** | `caddy:2.11.4-alpine` | frontend + backend | Security gateway — reverse proxy, security headers, network isolation |
| **webapp** | Build from `Dockerfile` | backend only | Application server (Next.js on :3000), isolated from internet |

The **frontend** network has external access (for tunnel outbound). The **backend** network is `internal: true` — the webapp has no internet connectivity, only caddy can reach it.

### Caddy Configuration

The template `Caddyfile` (at project root, symlinked from `templates/Caddyfile`) configures:

| Setting | Value |
|---------|-------|
| TLS | None — Cloudflare terminates TLS at the edge. Traffic arrives at Caddy over HTTP through the tunnel. |
| Reverse proxy | `webapp:3000` |
| Compression | `gzip` |
| HSTS | `max-age=31536000; includeSubDomains; preload` |
| X-Content-Type-Options | `nosniff` |
| X-Frame-Options | `DENY` |
| Referrer-Policy | `strict-origin-when-cross-origin` |
| Permissions-Policy | `camera=(), microphone=(), geolocation=()` |
| CSP | `default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'` |

### Health Checks

Each service has a Docker health check configured in `docker-compose.yml`:

| Service | Test | Interval | Retries | Start Period |
|---------|------|----------|---------|-------------|
| **webapp** | `GET /api/health` → expect 200 | 30s | 3 | 15s |
| **caddy** | `wget --spider http://localhost:80/healthz` | 30s | 3 | 10s |

Check health status at any time:

```bash
docker compose ps                    # See overall status
docker compose inspect --format='{{json .State.Health}}' webapp  # JSON health details
docker compose logs webapp           # Review application logs
```

---

## What This Repository Provides

| Component | Purpose |
| --- | --- |
| **Configuration** | Setup the host with dependencies and bootstrap project configs. |
| **Templates** | Standardized `Caddyfile`, `docker-compose.yml`, `Dockerfile`, and `.dockerignore`. |
| **Deployment** | Multi-stage build and container orchestration logic. |
| **Backup** | Automated snapshots with rotation and integrity verification. |

Because these components live in a shared repository, improvements can be rolled out across multiple projects simply by updating the Git submodule.

---

## Installing into a Project

Add the submodule to your repository:

```bash
git submodule add <repository-url> web-deploy-env
git submodule update --init --recursive
```

### 1. Configuration

Create/update the `.env` file in your project root with the following requirements:

```text
DOMAIN=yourdomain.com
TUNNEL_TOKEN=your_cloudflare_tunnel_token
```

### 2. Cloudflare Setup

Before deploying, you need to configure Cloudflare:

1. [Create a tunnel](docs/cloudflare-setup.md#1-create-a-tunnel) and copy the tunnel token.
2. Point the tunnel's public hostname to `http://caddy:80`.

See [docs/cloudflare-setup.md](docs/cloudflare-setup.md) for detailed instructions.

### 3. Setup and Bootstrap

Run these two scripts in order **on the host machine** (not inside a devcontainer):

```bash
./web-deploy-env/scripts/setup-host.sh
./web-deploy-env/scripts/bootstrap.sh
```

Both scripts are idempotent — running them multiple times is safe.

#### `setup-host.sh`

| Step | Action |
|------|--------|
| 1 | **OS check** — Requires Debian or Ubuntu |
| 2 | **Verify Docker** — Checks `docker` is installed; exits if missing |
| 3 | **Cache images** — Pre-pulls `caddy:2.11.4-alpine` and `cloudflare/cloudflared:2026.6.1` for faster deploys |

#### `bootstrap.sh`

| Step | Action |
|------|--------|
| 1 | **Path validation** — Ensures script is run from the parent repo, not the submodule |
| 2 | **Build default base image** — Builds `web-deploy-base:latest` from `Dockerfile.base` (skips if already exists, unless `--force`) |
| 3 | **Create `data/` directories** — Ensures directories for SQLite and backups exist |
| 4 | **Symlink infrastructure templates** — Links `Dockerfile`, `.dockerignore`, `docker-compose.yml`, `Caddyfile` to project root |
| 5 | **Link utility scripts** — Symlinks `deploy.sh`, `down.sh`, and `backup.sh` to project root |

> **Important:** These scripts run on the **host machine**, not inside a devcontainer.
> They install system packages, pull Docker images, build base images, and symlink
> infrastructure templates — all operations that belong on the host. If you attempt
> to run them inside a devcontainer, they will abort with a clear error message.
>
> Container initialization is handled by the project's own build and runtime
> configuration (e.g., `Dockerfile`, `docker-compose.yml`, devcontainer
> `postCreateCommand`).

### 4. Deploy

```bash
./deploy.sh
```

---

## Deployment Checklist

Before deploying, verify these items:

1. **DOMAIN** and **TUNNEL_TOKEN** are set in `.env`
2. **Ports 80** is not in use on the host
3. **Docker Compose** is available (`docker compose version`)
4. **Base images** are built (run `bootstrap.sh` if not)
5. **Cloudflare tunnel** is created and pointing to `caddy:80` (HTTP)
6. **DNS** resolves the domain to Cloudflare (nameservers or proxied DNS)
7. **Backup** of existing data has been created (`./backup.sh`)

---

## Operation

Day-to-day commands for managing the deployment:

```bash
# View all service statuses
docker compose ps

# Follow all logs
docker compose logs -f

# Follow logs for a specific service
docker compose logs -f caddy

# Check health status
docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Health}}'

# Execute a command inside a running container
docker compose exec webapp ls /app/data

# Restart a single service
docker compose restart caddy

# Rebuild and restart a single service
docker compose build --no-cache webapp && docker compose up -d webapp

# Stop all services
docker compose down

# Stop all services and remove volumes (destructive)
docker compose down -v
```

### Running Commands Inside the Container

The production image includes Node.js and your application's installed dependencies. Use `docker compose run` to execute one-off commands or scripts inside the container, with full access to the mounted database volume:

```bash
# Run an ad-hoc Node.js command
docker compose run --rm webapp node -e "
  const db = require('better-sqlite3')('/app/data/prod.db');
  const row = db.prepare('SELECT COUNT(*) as count FROM users').get();
  console.log('User count:', row.count);
"

# Run a local script by mounting it at runtime (no need to rebuild the image)
docker compose run --rm \
  -v "$(pwd)/path/to/script.ts:/tmp/script.ts" \
  webapp npx tsx /tmp/script.ts
```

`docker compose run` creates a temporary container linked to the same networks and volumes as the service. The `--rm` flag cleans it up automatically. The working directory is `/app`, and `node_modules` is available at `/app/node_modules`.

---

## Maintenance Workflow

The deployment environment acts as a "Toolkit" that projects consume to remain up to date.

### Updating Infrastructure

When you improve the `web-deploy-env` (e.g., adding security headers to the `Caddyfile` or optimizing the `Dockerfile`), update the submodule in your project:

```bash
git submodule update --remote
./web-deploy-env/scripts/bootstrap.sh
```

This non-destructive update refreshes your infrastructure symlinks while leaving your project-specific data and `.env` configuration untouched.

### Image Version Policy

Infrastructure images (`caddy`, `cloudflare/cloudflared`) are pinned to specific version tags in `templates/docker-compose.yml`. They do not auto-update. To update them:

1. Check the latest stable tags on Docker Hub.
2. Update the tag in `templates/docker-compose.yml`.
3. Run `./deploy.sh` to pull and deploy the new versions.

### Deployment & Backups

The toolkit exposes standard commands to the project root:

* **Deploy:** `./deploy.sh` (Builds the app and starts the containers)
* **Down:** `./down.sh` (Stops the containers)
* **Backup:** `./backup.sh` (Snapshots your data volume to `./data/backups/`)
* **Restore:** See [docs/backup-restore.md](docs/backup-restore.md) (decompress backup, stop services, restore data, redeploy)

---

## Design Philosophy

`web-deploy-env` separates **infrastructure plumbing** from **application logic**.

* **Parent Repo:** Owns the application source code and business logic.
* **`web-deploy-env`:** Owns the "how-to-deploy" standard — ensuring that all your projects are equally secure, consistently proxied, and easily backed up.

This separation ensures that when you learn a "better way" to deploy (e.g., adding advanced rate-limiting or automated offsite backups), you update the submodule once, and every project you manage instantly gains those capabilities.

---

## Documentation

* **`docs/deployment-strategy.md`**: Architectural lineage and template injection strategy.
* **`docs/cloudflare-setup.md`**: Step-by-step Cloudflare configuration guide.
* **`docs/deploy-script.md`**: Detailed walkthrough of the `deploy.sh` script stages, exit codes, and troubleshooting.
* **`docs/backup-restore.md`**: Creating backups, listing snapshots, verifying integrity, and restoring from a backup.
