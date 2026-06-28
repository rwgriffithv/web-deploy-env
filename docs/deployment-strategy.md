# Deployment & Environment Inheritance Strategy

This document outlines the architectural approach for maintaining parity between development and deployment environments while leveraging our modular `web-deploy-env` submodule.

## 1. Architectural Philosophy

Our platform follows a "Common Base → Agent-Enabled Dev → Project-Specific" lineage, managed through centralized templates.

* **Consistency:** Infrastructure is generated from a single source of truth, ensuring parity across all projects.
* **Maintainability:** Infrastructure logic is centralized in the submodule; updates propagate instantly to all parent repositories.
* **Efficiency:** Deployment images are automatically "stripped" of agentic bloat via multi-stage Docker builds.

## 2. The Lineage Hierarchy

1. **`web-deploy-base`**: The foundational layer (OS, Node.js, SQLite, system-level libs).
2. **`agent-dev-env`**: Inherits from `web-deploy-base`. Adds LLM tools, debuggers, and VS Code devcontainer standards.
3. **`project-repo`**: Inherits from `agent-dev-env`. Adds project-specific dependencies.

## 3. Implementation: Templates & Variable Injection

We use two mechanisms for configuration injection:

* **`envsubst`** — Processes the `templates/Dockerfile` at bootstrap time, injecting `${DEV_BASE_IMAGE}` and `${PROD_BASE_IMAGE}`.
* **Runtime environment variables** — `docker-compose.yml` and `Caddyfile` receive `${DOMAIN}` and `${TUNNEL_TOKEN}` directly from the container environment at runtime. These files are symlinked, not processed by `envsubst`.

| Template | Injection Method | Variables |
|---|---|---|
| `deploy/Dockerfile` | `envsubst` (bootstrap) | `DEV_BASE_IMAGE`, `PROD_BASE_IMAGE` |
| `docker-compose.yml` | Runtime env | `DOMAIN`, `TUNNEL_TOKEN` |
| `Caddyfile` | Caddy native `{$DOMAIN}` | `DOMAIN` |

## 4. TLS Strategy: Cloudflare Origin CA

Caddy is configured with a **Cloudflare Origin CA certificate** rather than auto-provisioning via Let's Encrypt. This is required because Cloudflare Tunnel proxies traffic at the edge — Let's Encrypt's HTTP-01 challenge cannot reach the origin server through the tunnel.

**Traffic flow:**

```
User → Cloudflare Edge (TLS) → Cloudflare Tunnel → cloudflared container
  → Caddy (TLS via Origin CA) → webapp (plain HTTP on :3000)
```

Cloudflare SSL/TLS mode must be set to **Full (Strict)**.

See `docs/cloudflare-setup.md` for instructions on generating the Origin CA certificate.

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
