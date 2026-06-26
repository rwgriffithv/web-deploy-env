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

We utilize `envsubst` to process templates stored in `web-deploy-env/templates/`. This allows us to inject dynamic configuration (like `${DOMAIN}` and `${TUNNEL_TOKEN}`) at bootstrap time.

* **`deploy/Dockerfile`**: Generated from the template; uses multi-stage builds to create a lean production runtime.
* **`docker-compose.yml`**: Standardized service orchestration (including Cloudflare Tunnel and Caddy) that relies on local `.env` files.
* **`Caddyfile`**: Automatic SSL/TLS reverse proxy configuration.

## 4. Deployment Interface

The `web-deploy-env` submodule acts as a toolkit for your project:

* **`scripts/validate-env.sh`**: The pre-flight gatekeeper. It verifies system dependencies and ensures all required environment variables (e.g., `DOMAIN`, `TUNNEL_TOKEN`) are set before execution.
* **`scripts/bootstrap.sh`**: The master orchestrator. It invokes the validator, generates infrastructure files, and creates symlinks for configuration and utility scripts.
* **`scripts/deploy.sh`**: Symlinked to the project root. Handles the standardized multi-stage build and container orchestration.
* **`scripts/backup.sh`**: Symlinked to the project root. Handles disaster recovery by snapshotting the SQLite data volume.

## 5. Maintenance Workflow

To keep environments synchronized:

* **New Dependency?** Update your project's Dockerfile logic within the `dev-base` stage.
* **Configuration Update?** Update your local `.env` file with new credentials or domain settings, then rerun `./web-deploy-env/scripts/bootstrap.sh`.
* **Upgrade Infrastructure?** Update the `web-deploy-env` submodule. Rerunning `bootstrap.sh` will refresh the symlinked templates and scripts to the latest standard defined in the submodule.
