# Cloudflare Setup Guide

This document explains how to configure Cloudflare to work with the `web-deploy-env` deployment stack.

## Prerequisites

- A domain managed by Cloudflare (nameservers pointed to Cloudflare)
- A Cloudflare account

## Quick Start (Recommended — Tunnel Only)

If you're using Cloudflare Tunnel (the default), you only need to create a tunnel and point it at Caddy:

1. [Create a tunnel](#1-create-a-tunnel) and copy the token.
2. Configure the tunnel's public hostname to `http://caddy:80`.
3. Add `DOMAIN` and `TUNNEL_TOKEN` to your `.env` file.
4. Run `./deploy.sh`.

No SSL/TLS configuration changes are needed — the tunnel encrypts traffic end-to-end. Cloudflare handles TLS at the edge; Caddy receives HTTP through the tunnel.

---

## 1. Create a Tunnel

1. Log in to the [Cloudflare Zero Trust dashboard](https://one.dash.cloudflare.com/).
2. Navigate to **Networks** → **Tunnels**.
3. Click **Create a tunnel**.
4. Choose **Cloudflared** as the connector type.
5. Name your tunnel (e.g., `my-app-tunnel`).
6. Click **Save tunnel**.
7. Copy the tunnel token — you'll need it for `TUNNEL_TOKEN` in your `.env` file.

## 2. Configure the Tunnel

After creating the tunnel, configure its public hostname:

1. In the tunnel details page, click the **Public Hostname** tab.
2. Click **Add a public hostname**.
3. Enter your domain (e.g., `app.yourdomain.com`).
4. Set the **Service** type to `HTTP`.
5. Set the **URL** to `caddy:80` (the Caddy container on the internal Docker network).
6. Click **Save hostname**.

**Important:** The tunnel connects to Caddy on port **80** (HTTP). Caddy does not terminate TLS — it acts as a security gateway (reverse proxy, security headers, network isolation). Cloudflare handles TLS at the edge.

## 3. Configure Your .env File

Your project's `.env` file needs these variables:

```text
DOMAIN=app.yourdomain.com
TUNNEL_TOKEN=your_cloudflare_tunnel_token_here
```

## 4. Deploy

```bash
./deploy.sh
```

## Troubleshooting

### Tunnel shows "Connected" but site returns 502

- Verify the tunnel's public hostname points to `caddy:80` (HTTP, not HTTPS).
- Check that Caddy is running: `docker compose ps`.
- Check Caddy logs: `docker compose logs caddy`.

### Redirect loop (too many redirects)

- Make sure the Caddyfile uses `http://{$DOMAIN}` (not `{$DOMAIN}`). With `{$DOMAIN}`, Caddy's automatic HTTPS redirect creates a loop through the tunnel.
- See [deployment-strategy.md](deployment-strategy.md) for the traffic flow explanation.

### Caddy fails to start

- Validate the Caddyfile: `docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile`.
