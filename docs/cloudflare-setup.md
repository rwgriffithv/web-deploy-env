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

**Origin CA certificates and SSL/TLS mode changes are not needed.** The tunnel encrypts traffic end-to-end. Cloudflare handles TLS at the edge; Caddy receives HTTP through the tunnel.

The sections below cover both the tunnel setup and the optional Origin CA setup for direct origin access.

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

## 3. SSL/TLS Mode

With Cloudflare Tunnel, the SSL/TLS mode setting in the Cloudflare dashboard is **not relevant** — the tunnel provides its own encryption between Cloudflare and your server. You can leave it at the default setting.

If you configure direct origin access (bypassing the tunnel), set SSL/TLS to **Full (Strict)** and see section 4 below.

## 4. Optional: Origin CA Certificate (for Direct Origin Access)

If you need direct server access without the tunnel (e.g., staging environment, CDN fallback), you can generate an Origin CA certificate:

1. In the Cloudflare dashboard, go to **SSL/TLS** → **Origin Server**.
2. Click **Create Certificate**.
3. Leave the default **Generate private key and CSR with Cloudflare** selected.
4. Set the hostnames to include your domain (e.g., `app.yourdomain.com` and `*.yourdomain.com`).
5. Choose a validity period (14 days to 15 years).
6. Click **Create**.
7. **Copy both the origin certificate and private key** — this is your only chance to save the private key.
8. Place the files in `./data/certs/`:
   ```bash
   mkdir -p ./data/certs
   cat > ./data/certs/origin.pem << 'EOF'
   -----BEGIN CERTIFICATE-----
   ... (paste origin certificate here)
   -----END CERTIFICATE-----
   EOF
   cat > ./data/certs/privkey.pem << 'EOF'
   -----BEGIN RSA PRIVATE KEY-----
   ... (paste private key here)
   -----END RSA PRIVATE KEY-----
   EOF
   chmod 600 ./data/certs/privkey.pem
   ```
9. Update the `Caddyfile` to add the `tls` directive and use `{$DOMAIN}` instead of `http://{$DOMAIN}`.
10. Expose port 443 in `docker-compose.yml`.
11. Set Cloudflare SSL/TLS to **Full (Strict)**.

## 5. Configure Your .env File

Your project's `.env` file needs these variables:

```text
DOMAIN=app.yourdomain.com
TUNNEL_TOKEN=your_cloudflare_tunnel_token_here
```

## 6. Deploy

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
