# Troubleshooting Guide

## Diagnostic Commands

```sh
# Overall status
https-gateway status

# Test nginx config syntax
nginx -t

# View nginx error log
logread | grep nginx

# View service log
logread | grep https-gateway

# Check if nginx is running
pgrep -l nginx

# Check listening ports
netstat -tlnp | grep -E ':(80|443|8080|8443)\b'

# Verify dnsmasq resolution
nslookup nas.example.com 127.0.0.1

# Check certificate files
ls -la /etc/ssl/acme/
```

## Common Issues

### Certificate Issuance Fails

**Symptoms**: `https-gateway issue` hangs or reports errors.

**Possible causes**:

| Cause | Fix |
|-------|-----|
| Wrong API credentials | Double-check `dns_credentials` format: `Ali_Key="LTAI..."` |
| DNS propagation too slow | Increase `dns_sleep` to 300 or higher |
| Rate limited (production) | Switch to `staging='1'`, wait 1 hour, retry |
| Network issue | Verify `curl -I https://acme-v02.api.letsencrypt.org` works |
| Firewall blocking | Ensure outbound HTTPS (port 443) is allowed |

**Debug**:
```sh
# Run acme.sh manually with debug
/usr/lib/acme/acme.sh --issue -d "*.example.com" --dns dns_ali \
  --dnssleep 300 --debug 2 --staging
```

### nginx Won't Start

**Symptoms**: Port 443 not listening, LuCI shows "Stopped".

**Check**:
```sh
nginx -t
# If error, inspect generated config:
cat /etc/nginx/conf.d/https-gateway.conf
```

**Common config errors**:

| Error | Cause | Fix |
|-------|-------|-----|
| `cannot load certificate` | Cert not yet issued | Run `https-gateway issue` first |
| `conflicting server name` | Duplicate domain in rules | Remove duplicate proxy rules |
| `bind() to 0.0.0.0:443 failed` | Another process on port 443 | Keep uhttpd running, confirm the gateway moved it to `127.0.0.1:8080`, then run `/etc/init.d/https_gateway restart` |

### LuCI Menu Not Showing

**Symptoms**: "HTTPS Gateway" doesn't appear under Services.

**Fix**:
```sh
# Verify menu file exists
ls /usr/share/luci/menu.d/luci-app-https-gateway.json

# Verify ACL file exists
ls /usr/share/rpcd/acl.d/luci-app-https-gateway.json

# Restart rpcd to reload plugins
/etc/init.d/rpcd restart

# Clear browser cache and reload LuCI
```

### RPC Errors in LuCI ("Permission Denied")

**Symptoms**: Dashboard shows errors, buttons don't work.

**Fix**:
```sh
# Check rpcd plugin is executable
ls -la /usr/libexec/rpcd/https-gateway
chmod +x /usr/libexec/rpcd/https-gateway

# Verify ubus service is registered
ubus list | grep https-gateway

# Restart rpcd
/etc/init.d/rpcd restart
```

### Can't Access LuCI After Enabling Gateway

**Symptoms**: `https://192.168.0.1` returns nginx default page or error.

**Explanation**: When the gateway is enabled, uhttpd remains running but moves to `127.0.0.1:8080` so nginx can use ports 80/443.

**Fix**:
- uhttpd listens on `127.0.0.1:8080`, so it is intentionally not reachable directly from the LAN
- Or add a proxy rule for the router itself: `router.example.com → http://127.0.0.1:8080`
- For a direct backend test, run `curl -I http://127.0.0.1:8080/cgi-bin/luci/` over SSH on the router

### DNS Not Resolving on LAN Clients

**Symptoms**: `nslookup nas.example.com` returns NXDOMAIN from LAN devices.

**Check**:
```sh
# Verify dnsmasq has the entry
grep "address=" /tmp/dnsmasq.d/* 2>/dev/null
cat /etc/dnsmasq.conf | grep address

# Ensure auto_dns is enabled
uci get https_gateway.global.auto_dns

# Re-apply configuration
https-gateway apply

# Restart dnsmasq
/etc/init.d/dnsmasq restart
```

**Note**: LAN clients must use the router as their DNS server (default in OpenWrt DHCP).

### WebSocket Connection Drops

**Symptoms**: Home Assistant, Jellyfin, or other WebSocket apps disconnect frequently.

**Fix**:
1. Ensure `websocket='1'` is set on the proxy rule
2. Check nginx timeout settings in the generated config:
   ```sh
   grep -A5 "proxy_set_header Upgrade" /etc/nginx/conf.d/https-gateway.conf
   ```
3. If connections still drop, the backend may need `proxy_read_timeout` increase (edit service script for custom timeout).

### Certificates Not Auto-Renewing

**Symptoms**: Certs expire despite service being enabled.

**Check**:
```sh
# Verify cron job exists
crontab -l | grep acme

# Check cert expiry
openssl x509 -in /etc/ssl/acme/*.example.com.fullchain.crt -noout -enddate

# Manually trigger renewal
https-gateway issue
```

## Emergency Recovery

If the gateway breaks your router's web access:

```sh
# SSH in and disable
ssh root@192.168.0.1
uci set https_gateway.global.enabled='0'
uci commit https_gateway
/etc/init.d/https_gateway restart
/etc/init.d/uhttpd restart
/etc/init.d/nginx stop
```

This restores uhttpd on default ports and stops nginx.

## Log Locations

| Log | Command |
|-----|---------|
| Service log | `logread -e https-gateway` |
| nginx error | `cat /var/log/nginx/error.log` or `logread -e nginx` |
| ACME log | `cat /var/log/acme.sh.log` |
| dnsmasq | `logread -e dnsmasq` |

## Getting Help

1. Check this troubleshooting guide first
2. Run `https-gateway status` and `nginx -t` to gather diagnostics
3. Open an issue with the output of both commands
