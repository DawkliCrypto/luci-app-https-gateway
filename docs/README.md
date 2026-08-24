# HTTPS Gateway Documentation

Detailed guides for installing, configuring, and operating `luci-app-https-gateway` on OpenWrt 25.x.

## Table of Contents

| # | Guide | Description |
|---|-------|-------------|
| 01 | [Installation](01-Installation.md) | Install dependencies, deploy files, first-boot setup |
| 02 | [Configuration](02-Configuration.md) | UCI settings, DNS providers, certificates, proxy rules |
| 03 | [Usage](03-Usage.md) | Day-to-day operations: issue certs, add services, check status |
| 04 | [Troubleshooting](04-Troubleshooting.md) | Common errors, diagnostic commands, FAQ |
| 05 | [Signed APK Feed](05-Signed-Feed.md) | Install signed OpenWrt 25.x packages from GitHub Pages |

## Quick Links

- **LuCI URL**: `https://192.168.0.1/cgi-bin/luci/admin/services/https-gateway`
- **Service command**: `/etc/init.d/https_gateway {start|stop|restart|enable|disable}`
- **Manual apply**: `https-gateway apply`
- **Check status**: `https-gateway status`
