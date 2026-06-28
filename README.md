# 🌐 Web Deployment Environment

A version-controlled **infrastructure deployment toolkit** designed to be included as a **Git submodule** in web projects.

Rather than duplicating Docker configurations, Caddyfile reverse-proxy rules, and deployment scripts across multiple websites, `web-deploy-env` provides a centralized foundation for production-ready deployments.

The result is a consistent, secure, and easily maintainable deployment stack that evolves independently of the applications it hosts.

---

# Architecture

`web-deploy-env` follows a "Standardized Infrastructure" pattern. A typical project using this submodule looks like this:

```text
parent-project/
├── deploy/                 # Auto-generated build artifacts
├── data/                   # Persistent storage (e.g., SQLite)
├── .env                    # Secrets and configuration
├── deploy.sh               # Symlinked utility
├── backup.sh               # Symlinked utility
│
└── web-deploy-env/         # Git submodule
    ├── templates/          # Source templates (Caddy, Docker, etc.)
    └── scripts/            # Orchestration logic

```

---

# What This Repository Provides

| Component | Purpose |
| --- | --- |
| **Configuration** | Setup the host with dependencies and bootstrap project configs. |
| **Templates** | Standardized `Caddyfile`, `docker-compose.yml`, and `Dockerfile`. |
| **Deployment** | Multi-stage build and container orchestration logic. |
| **Backup** | Automated snapshots for database/data volume recovery. |

Because these components live in a shared repository, improvements can be rolled out across multiple projects simply by updating the Git submodule.

---

# Installing into a Project

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

### 2. Setup and Bootstrap

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

---

# Maintenance Workflow

The deployment environment acts as a "Toolkit" that projects consume to remain up to date.

### Updating Infrastructure

When you improve the `web-deploy-env` (e.g., adding security headers to the `Caddyfile` or optimizing the `Dockerfile`), update the submodule in your project:

```bash
git submodule update --remote
./web-deploy-env/scripts/bootstrap.sh

```

This non-destructive update refreshes your infrastructure symlinks while leaving your project-specific data and `.env` configuration untouched.

### Deployment & Backups

The toolkit exposes standard commands to the project root:

* **Deploy:** `./deploy.sh` (Builds the app and starts the containers)
* **Backup:** `./backup.sh` (Snapshots your data volume to `./data/backups/`)

---

# Design Philosophy

`web-deploy-env` separates **infrastructure plumbing** from **application logic**.

* **Parent Repo:** Owns the application source code and business logic.
* **`web-deploy-env`:** Owns the "how-to-deploy" standard—ensuring that all your projects are equally secure, consistently proxied, and easily backed up.

This separation ensures that when you learn a "better way" to deploy (e.g., adding advanced rate-limiting or automated offsite backups), you update the submodule once, and every project you manage instantly gains those capabilities.

### 📖 Documentation & Strategy

For a deeper dive into the architectural decisions and the "Lineage Hierarchy" of our deployment stack, see the detailed documentation under `./docs/`:

* **`./docs/deployment-strategy.md`**: Explains the architectural lineage (`Base` → `Dev` → `Project`) and the rationale behind our multi-stage build process.
