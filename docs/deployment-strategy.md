# Deployment & Environment Inheritance Strategy

This document outlines the architectural approach for maintaining parity between development and deployment environments while leveraging our modular `web-deploy-env` submodule.

## 1. Architectural Philosophy

Our platform follows a "Common Base → Agent-Enabled Dev → Project-Specific" lineage, managed through centralized templates.

* **Consistency:** Infrastructure is generated from a single source of truth, ensuring parity across all projects.
* **Maintainability:** Infrastructure logic is centralized in the submodule; updates propagate instantly to all parent repositories.
* **Efficiency:** Deployment images are automatically "stripped" of agentic bloat via multi-stage Docker builds.

## 2. The Lineage Hierarchy

1. **`web-deploy-base`**: The foundational layer (OS, Node.js, system-level libs).
2. **`project-repo` (build stage `dev-base`)**: Inherits from `web-deploy-base`. Installs project dependencies and runs the build. Does **not** include agent/dev tooling — those are reserved for the separate `agent-dev-env` image.
3. **`project-repo` (prod stage)**: Copies only the build artifacts from `dev-base` into a fresh `web-deploy-base` layer for the smallest possible production image and framework for extensibility.

> **Optional override:** Set `DEV_BASE_IMAGE` in `.env` to use a custom build base for including extra dependencies at build time. Set `PROD_BASE_IMAGE` in `.env` to use a custom production image instead of the image provided by this toolkit.

## 3. Implementation: Templates & Variable Injection

We use Docker `ARG` defaults for build-time configuration and runtime environment variables for configuration:

* **Dockerfile ARGs** — The `templates/Dockerfile` is a static file symlinked to the project root `Dockerfile`. It declares `DEV_BASE_IMAGE` and `PROD_BASE_IMAGE` as `ARG`s with defaults, avoiding any template processing step.
* **Runtime environment variables** — `docker-compose.yml` and `Caddyfile` receive `${DOMAIN}` and `${TUNNEL_TOKEN}` directly from the container environment at runtime. These files are symlinked, not processed.

| Template | Configuration Method | Variables |
|---|---|---|---|
| `Dockerfile` | Docker `ARG` defaults in template | `DEV_BASE_IMAGE`, `PROD_BASE_IMAGE` (both default to `${IMAGE_REGISTRY}/web-deploy-base:latest`) |
| `.dockerignore` | Static exclusion list | — |
| `docker-compose.yml` | Build args (from `.env`) + Runtime env | `DEV_BASE_IMAGE`, `PROD_BASE_IMAGE` (build), `DOMAIN`, `TUNNEL_TOKEN` (runtime) |
| `Caddyfile` | Caddy native `{$DOMAIN}` | `DOMAIN` |

The `IMAGE_REGISTRY` ARG controls the registry prefix for all base images. Override at build time or in `.env`:

```bash
docker compose build --build-arg IMAGE_REGISTRY=ghcr.io/myorg
```

Defaults to `local` (for locally-built images). When set, both `DEV_BASE_IMAGE` and `PROD_BASE_IMAGE` resolve under that registry.

Individual base images can be overridden independently via `.env`:

```env
# .env — override the build base for the dev stage
DEV_BASE_IMAGE=local/agent-dev-env:latest
```

Because `docker-compose.yml` declares these as build args referencing `${VAR:-default}`, Docker Compose resolves them from `.env` automatically — no script changes needed.

## 4. TLS Strategy: Cloudflare at the Edge, Caddy as Gateway

### With Cloudflare Tunnel (default)

The Cloudflare Tunnel provides an encrypted channel from the Cloudflare edge to your server. Caddy does **not** terminate TLS — it receives plain HTTP from the tunnel on port 80.

**Traffic flow:**

```
User → Cloudflare Edge (TLS) → Cloudflare Tunnel (encrypted)
  → cloudflared → Caddy (HTTP on :80) → webapp (HTTP on :3000)
```

- Cloudflare terminates TLS at the edge.
- The tunnel encrypts traffic between Cloudflare and the server.
- **Origin CA certificates are not needed** — the tunnel itself provides origin encryption.
- Cloudflare SSL/TLS mode should be set to **Flexible** (tunnel handles encryption) or left at default. Full (Strict) is not applicable because there is no direct origin TLS handshake.

### Without Tunnel (direct origin access)

For scenarios where the tunnel is bypassed (local testing, alternative CDN, direct server access), Caddy can serve TLS directly. To enable this:

1. Generate a Cloudflare Origin CA certificate (see `docs/cloudflare-setup.md`).
2. Place `origin.pem` and `privkey.pem` in `./data/certs/`.
3. Update the `Caddyfile` to add the `tls` directive and use `{$DOMAIN}` instead of `http://{$DOMAIN}`.
4. Expose port 443 in `docker-compose.yml`.
5. Set Cloudflare SSL/TLS to **Full (Strict)**.

This is a supported fallback, not the default. The standard deployment uses the tunnel path above.

## 5. Deployment Interface

The `web-deploy-env` submodule acts as a toolkit for your project:

* **`scripts/bootstrap.sh`**: The master orchestrator. It generates infrastructure files and creates symlinks for configuration and utility scripts.
* **`scripts/deploy.sh`**: Symlinked to the project root. Handles the standardized multi-stage build and container orchestration.
* **`scripts/backup.sh`**: Symlinked to the project root. Handles disaster recovery by snapshotting the SQLite data volume, with automatic rotation and integrity verification.

## 6. Maintenance Workflow

To keep environments synchronized:

* **New Dependency?** Update your project's Dockerfile logic within the `dev-base` stage.
* **Configuration Update?** Update your local `.env` file with new credentials or domain settings, then rerun `./web-deploy-env/scripts/bootstrap.sh`.
* **Upgrade Infrastructure?** Update the `web-deploy-env` submodule. Rerunning `bootstrap.sh` will refresh the symlinked templates and scripts to the latest standard defined in the submodule.
