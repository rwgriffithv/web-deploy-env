# Cloudflare Setup Guide

This document explains how to configure Cloudflare to work with the `web-deploy-env` deployment stack.

## Prerequisites

- A domain managed by Cloudflare (nameservers pointed to Cloudflare)
- A Cloudflare account

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
4. Set the **Service** type to `HTTP` (not HTTPS, because Caddy handles TLS termination internally).
5. Set the **URL** to `caddy:80` (the Caddy container on the internal Docker network).
6. Click **Save hostname**.

**Important:** The tunnel connects to Caddy on port **80** (HTTP). Caddy terminates TLS using the Origin CA certificate and handles security headers.

## 3. Set SSL/TLS Mode to Full (Strict)

1. In the Cloudflare dashboard, go to **SSL/TLS** → **Overview**.
2. Select **Full (Strict)**.
3. This ensures Cloudflare encrypts traffic to your origin and verifies the Origin CA certificate.

## 4. Generate an Origin CA Certificate

1. In the Cloudflare dashboard, go to **SSL/TLS** → **Origin Server**.
2. Click **Create Certificate**.
3. Leave the default **Generate private key and CSR with Cloudflare** selected.
4. Set the hostnames to include your domain (e.g., `app.yourdomain.com` and `*.yourdomain.com`).
5. Choose a validity period (14 days to 15 years).
6. Click **Create**.
7. **Copy both the origin certificate and private key** — this is your only chance to save the private key.

## 5. Install the Certificate on Your Server

1. On your deployment server, place the certificate files in `./data/certs/`:

   ```bash
   # Create the certs directory (already created by bootstrap.sh)
   mkdir -p ./data/certs

   # Save the origin certificate
   # Copy the full text from the Cloudflare dashboard
   cat > ./data/certs/origin.pem << 'EOF'
   -----BEGIN CERTIFICATE-----
   ... (paste origin certificate here)
   -----END CERTIFICATE-----
   EOF

   # Save the private key
   cat > ./data/certs/privkey.pem << 'EOF'
   -----BEGIN RSA PRIVATE KEY-----
   ... (paste private key here)
   -----END RSA PRIVATE KEY-----
   EOF
   ```

2. Set strict permissions:

   ```bash
   chmod 600 ./data/certs/privkey.pem
   chmod 644 ./data/certs/origin.pem
   ```

3. The Caddy container mounts `./data/certs` to `/etc/caddy/certs` automatically when you run `deploy.sh`.

## 6. Configure Your .env File

Your project's `.env` file needs these variables:

```text
DOMAIN=app.yourdomain.com
TUNNEL_TOKEN=your_cloudflare_tunnel_token_here
```

## 7. Deploy

```bash
./deploy.sh
```

## Troubleshooting

### Tunnel shows "Connected" but site returns 502

- Verify the tunnel's public hostname points to `caddy:80` (HTTP, not HTTPS).
- Check that Caddy is running: `docker compose ps`.
- Check Caddy logs: `docker compose logs caddy`.

### Certificate errors in browser

- Verify Cloudflare SSL/TLS is set to **Full (Strict**).
- Confirm the Origin CA certificate matches your domain.
- Check that `origin.pem` and `privkey.pem` exist in `./data/certs/`.

### Caddy fails to start

- Validate the Caddyfile: `docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile`.
- Check the certificate files are mounted: `docker compose exec caddy ls -la /etc/caddy/certs/`.
