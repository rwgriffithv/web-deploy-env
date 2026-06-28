# Web Deployment Environment

A version-controlled **infrastructure deployment toolkit** designed to be included as a **Git submodule** in web projects.

Rather than duplicating Docker configurations, Caddyfile reverse-proxy rules, and deployment scripts across multiple websites, `web-deploy-env` provides a centralized foundation for production-ready deployments.

The result is a consistent, secure, and easily maintainable deployment stack that evolves independently of the applications it hosts.

---

## Architecture

`web-deploy-env` follows a "Standardized Infrastructure" pattern. A typical project using this submodule looks like this:

```text
parent-project/
├── deploy/                 # Auto-generated build artifacts
├── data/                   # Persistent storage
│   ├── sqlite/             # SQLite database volume
│   ├── backups/            # Automated backup snapshots
│   └── certs/              # Cloudflare Origin CA certificates
├── .env                    # Secrets and configuration
├── docker-compose.yml      # Symlinked from submodule
├── Caddyfile               # Symlinked from submodule
├── deploy.sh               # Symlinked utility
├── backup.sh               # Symlinked utility
│
└── web-deploy-env/         # Git submodule
    ├── templates/          # Source templates (Caddy, Docker, etc.)
    ├── scripts/            # Orchestration logic
    └── docs/               # Architecture & setup guides
```

### Service Architecture

```
                  Cloudflare Edge
                        |
                  Cloudflare Tunnel
                        |
                    cloudflared
                        |
                    ┌───┘
                 Caddy (TLS, reverse proxy, security headers)
                        |
                    webapp (Next.js on :3000)
                        |
                    SQLite (/app/data)
```

Three Docker services connected over isolated networks:
- **tunnel** — outbound-only connection to Cloudflare edge (frontend network only)
- **caddy** — TLS termination, rate limiting, security headers (frontend + backend networks)
- **webapp** — application server, isolated on backend network

---

## What This Repository Provides

| Component | Purpose |
| --- | --- |
| **Configuration** | Setup the host with dependencies and bootstrap project configs. |
| **Templates** | Standardized `Caddyfile`, `docker-compose.yml`, and `Dockerfile`. |
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
2. [Generate an Origin CA certificate](docs/cloudflare-setup.md#4-generate-an-origin-ca-certificate).
3. [Set SSL/TLS mode to Full (Strict)](docs/cloudflare-setup.md#3-set-ssltls-mode-to-full-strict).

See [docs/cloudflare-setup.md](docs/cloudflare-setup.md) for detailed instructions.

### 3. Setup and Bootstrap

Setup host dependencies and bootstrap the parent repository:

```bash
./web-deploy-env/scripts/setup-host.sh
./web-deploy-env/scripts/bootstrap.sh
```

The setup and bootstrap processes are idempotent.

> **Important:** These scripts run on the **host machine**, not inside a devcontainer.
> They install system packages, pull Docker images, build base images, and symlink
> infrastructure templates — all operations that belong on the host. If you attempt
> to run them inside a devcontainer, they will abort with a clear error message.
>
> Container initialization is handled by the project's own build and runtime
> configuration (e.g., `Dockerfile`, `docker-compose.yml`, devcontainer
> `postCreateCommand`).

### 4. Install Origin CA Certificate

Place your Cloudflare Origin CA certificate and private key in `./data/certs/`:

```bash
mkdir -p ./data/certs
# Copy origin.pem and privkey.pem into ./data/certs/
chmod 600 ./data/certs/privkey.pem
```

See [docs/cloudflare-setup.md#5-install-the-certificate-on-your-server](docs/cloudflare-setup.md#5-install-the-certificate-on-your-server).

### 5. Deploy

```bash
./deploy.sh
```

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
* **Backup:** `./backup.sh` (Snapshots your data volume to `./data/backups/`)

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
* **`PLAN.md`**: Architecture assessment and remediation plan.
