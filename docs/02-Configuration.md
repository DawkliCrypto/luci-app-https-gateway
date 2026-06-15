# Configuration Guide

All settings are stored in UCI at `/etc/config/https_gateway`. You can edit via LuCI or command line.

## Global Settings

### UCI Section: `config gateway 'global'`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | `0` | Master switch — enables nginx proxy and DNS |
| `email` | string | — | ACME account email (required) |
| `dns_provider` | string | `dns_ali` | DNS-01 challenge provider |
| `dns_credentials` | string | — | API credentials (format: `Key="Value"`) |
| `dns_sleep` | integer | `180` | Seconds to wait for DNS propagation |
| `staging` | bool | `1` | Use Let's Encrypt staging (for testing) |
| `auto_dns` | bool | `1` | Auto-manage dnsmasq domain → router IP |

### Supported DNS Providers

| Provider | `dns_provider` value | Required credentials |
|----------|---------------------|---------------------|
| Alibaba Cloud | `dns_ali` | `Ali_Key="..."` `Ali_Secret="..."` |
| Cloudflare | `dns_cf` | `CF_Key="..."` `CF_Email="..."` |
| Tencent DNSPod | `dns_dp` | `DP_Id="..."` `DP_Key="..."` |
| GoDaddy | `dns_gd` | `GD_Key="..."` `GD_Secret="..."` |

### Example: CLI Configuration

```sh
uci set https_gateway.global.enabled='1'
uci set https_gateway.global.email='admin@example.com'
uci set https_gateway.global.dns_provider='dns_ali'
uci set https_gateway.global.dns_credentials='Ali_Key="LTAI5t..." Ali_Secret="abc123..."'
uci set https_gateway.global.dns_sleep='200'
uci set https_gateway.global.staging='0'
uci set https_gateway.global.auto_dns='1'
uci commit https_gateway
```

## Certificates

### UCI Section: `config cert`

Each certificate is a named or anonymous section of type `cert`.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | `1` | Whether to issue/renew this cert |
| `domain` | string | — | Domain (e.g. `nas.example.com` or `*.example.com`) |
| `key_type` | string | `ec-256` | Key type: `ec-256` or `2048` |

### Wildcard vs Individual Certificates

- **Wildcard** (`*.example.com`): Covers all subdomains (`nas.example.com`, `ha.example.com`, etc.) with a single certificate. Also covers the bare domain `example.com`.
- **Individual** (`nas.example.com`): One cert per service. Use when you have few services or need different key types.

**Recommendation**: Use a wildcard certificate when you have 3+ subdomains under the same root.

### Example: Add a Wildcard Certificate

```sh
uci add https_gateway cert
uci set https_gateway.@cert[-1].enabled='1'
uci set https_gateway.@cert[-1].domain='*.example.com'
uci set https_gateway.@cert[-1].key_type='ec-256'
uci commit https_gateway
```

## Proxy Rules

### UCI Section: `config proxy`

Each proxy rule maps a domain + path to a backend upstream.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | `1` | Whether this rule is active |
| `name` | string | — | Friendly name (e.g. "NAS WebUI") |
| `domain` | string | — | Domain to match (must have a covering cert) |
| `location` | string | `/` | URL path prefix |
| `upstream` | string | — | Backend address (e.g. `http://192.168.0.100:5000`) |
| `websocket` | bool | `0` | Enable WebSocket Upgrade headers |
| `max_body_size` | string | — | Max client request body, e.g. `50m` (nginx `client_max_body_size`). Empty = nginx default (1m); `0` = unlimited |

### Example: Proxy NAS to HTTPS

```sh
uci add https_gateway proxy
uci set https_gateway.@proxy[-1].enabled='1'
uci set https_gateway.@proxy[-1].name='Synology NAS'
uci set https_gateway.@proxy[-1].domain='nas.example.com'
uci set https_gateway.@proxy[-1].location='/'
uci set https_gateway.@proxy[-1].upstream='http://192.168.0.100:5000'
uci set https_gateway.@proxy[-1].websocket='0'
uci commit https_gateway
```

### Example: Home Assistant with WebSocket

```sh
uci add https_gateway proxy
uci set https_gateway.@proxy[-1].enabled='1'
uci set https_gateway.@proxy[-1].name='Home Assistant'
uci set https_gateway.@proxy[-1].domain='ha.example.com'
uci set https_gateway.@proxy[-1].location='/'
uci set https_gateway.@proxy[-1].upstream='http://192.168.0.200:8123'
uci set https_gateway.@proxy[-1].websocket='1'
uci commit https_gateway
```

### Example: App That Accepts Large Uploads

```sh
uci add https_gateway proxy
uci set https_gateway.@proxy[-1].enabled='1'
uci set https_gateway.@proxy[-1].name='CMS'
uci set https_gateway.@proxy[-1].domain='admin.example.com'
uci set https_gateway.@proxy[-1].location='/'
uci set https_gateway.@proxy[-1].upstream='http://192.168.0.200:8095'
uci set https_gateway.@proxy[-1].max_body_size='50m'
uci commit https_gateway
```

### Example: Multiple Paths on One Domain

```sh
# Jellyfin media server
uci add https_gateway proxy
uci set https_gateway.@proxy[-1].name='Jellyfin'
uci set https_gateway.@proxy[-1].domain='media.example.com'
uci set https_gateway.@proxy[-1].location='/'
uci set https_gateway.@proxy[-1].upstream='http://192.168.0.150:8096'
uci set https_gateway.@proxy[-1].websocket='1'

# Transmission under /download
uci add https_gateway proxy
uci set https_gateway.@proxy[-1].name='Transmission'
uci set https_gateway.@proxy[-1].domain='media.example.com'
uci set https_gateway.@proxy[-1].location='/download'
uci set https_gateway.@proxy[-1].upstream='http://192.168.0.150:9091'
uci commit https_gateway
```

## Applying Changes

After modifying UCI config:

```sh
# Apply all (generate nginx conf, sync ACME, update DNS)
https-gateway apply

# Or via init script
/etc/init.d/https_gateway restart
```

From LuCI: Click **Save & Apply**, then use the **Reload Configuration** button on the Overview page.

## Important Notes

1. **Staging mode**: Start with `staging='1'` to test your DNS credentials without hitting Let's Encrypt rate limits. Switch to `staging='0'` once everything works.

2. **DNS propagation**: If certificate issuance fails, try increasing `dns_sleep` to 300 seconds.

3. **uhttpd port conflict**: When enabled, the gateway moves uhttpd from port 80/443 to 8080/8443 to free ports for nginx. When disabled, ports revert automatically.

4. **Certificate storage**: Issued certificates are stored in `/etc/ssl/acme/`.

5. **Auto DNS**: When `auto_dns='1'`, dnsmasq entries like `address=/nas.example.com/192.168.0.1` are added automatically so LAN clients resolve domains to the router.
