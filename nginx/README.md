# Nginx + Let's Encrypt for FHIR & MCP

Reverse proxy configuration for HTTPS with Let's Encrypt certificates.

## Endpoints

| Path | Backend | Purpose |
|------|---------|---------|
| `/server/fhir/*` | HAPI :8023/fhir | FHIR API |
| `/server/*` | HAPI :8023 | HAPI Tester UI |
| `/mcp` | MCP :8000 | MCP Streamable HTTP |
| `/sse` | MCP :8000 | MCP SSE transport |

## Setup (EC2 / Amazon Linux 2023)

### 1. Install nginx and certbot

```bash
sudo dnf install -y nginx certbot python3-certbot-nginx
```

### 2. Prepare for certificate (before HTTPS)

Temporarily use HTTP-only config, or run certbot in standalone mode with nginx stopped:

```bash
# Create ACME challenge directory
sudo mkdir -p /var/www/certbot

# Option A: Use certbot standalone (stop nginx first)
sudo systemctl stop nginx
sudo certbot certonly --standalone -d hl7int-server.com --non-interactive --agree-tos -m kaminker.diego@gmail.com
sudo systemctl start nginx
```

Or if nginx is already running with HTTP on port 80:

```bash
sudo certbot certonly --webroot -w /var/www/certbot -d hl7int-server.com --non-interactive --agree-tos -m your@email.com
```

### 3. Copy nginx config

```bash
sudo cp nginx/hl7int-server.conf /etc/nginx/conf.d/
```

### 4. Test and reload nginx

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 5. Auto-renewal

```bash
# Test renewal
sudo certbot renew --dry-run

# certbot installs a systemd timer; verify:
sudo systemctl status certbot-renew.timer
```

## Adjust ports

If your `.env` uses different ports, edit `hl7int-server.conf`:

- `8080` → HAPI (FHIR_PORT)
- `8000` → MCP (MCP_PORT)

## Different domain

Replace `hl7int-server.com` with your domain in:

1. `hl7int-server.conf` – `server_name` and `ssl_certificate` paths
2. certbot command – `-d yourdomain.com`
