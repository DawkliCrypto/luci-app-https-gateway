<div align="center">

# 🔒 luci-app-https-gateway

**LAN HTTPS Reverse Proxy Gateway for OpenWrt**

[![Release](https://img.shields.io/github/v/release/seamys/luci-app-https-gateway?style=flat-square&logo=github)](https://github.com/seamys/luci-app-https-gateway/releases)
[![License](https://img.shields.io/github/license/seamys/luci-app-https-gateway?style=flat-square)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-149%20passing-brightgreen?style=flat-square&logo=checkmarx&logoColor=white)](#testing)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-25.x-00B5E2?style=flat-square&logo=openwrt&logoColor=white)](https://openwrt.org/)
[![Shell](https://img.shields.io/badge/shell-POSIX%20sh-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)](src/bin/https-gateway)
[![i18n](https://img.shields.io/badge/i18n-English%20%7C%20中文-blue?style=flat-square&logo=translate&logoColor=white)](#internationalization)

Manage nginx reverse proxy, automatic ACME certificate issuance, and local DNS resolution through a LuCI web UI — providing HTTPS access for all your LAN services with zero manual configuration.

[📖 Documentation](docs/) · [🐛 Report Bug](https://github.com/seamys/luci-app-https-gateway/issues) · [💡 Request Feature](https://github.com/seamys/luci-app-https-gateway/issues)

</div>

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🌐 **Multi-domain** | Add domains freely, each with an automatically issued TLS certificate |
| 🃏 **Wildcard certs** | `*.example.com` — one certificate covers all subdomains |
| 🔀 **Reverse proxy** | Proxy any HTTP service on LAN or public networks |
| ⚡ **WebSocket** | One-click Upgrade header injection for real-time apps |
| 🧭 **Auto DNS** | Automatically add domain → router IP resolution in dnsmasq |
| 🔄 **Auto renewal** | Based on acme.sh, 90-day certificates auto-renew |
| 🎨 **LuCI native** | Three-page UI: status overview, certificate management, proxy rules |
| 🌍 **i18n** | English + Chinese Simplified, easily extensible |

## 📋 Requirements

| Requirement | Details |
|-------------|---------|
| Platform | OpenWrt 25.x (APK package manager) |
| Domain | A registered domain name |
| DNS API | Provider API credentials (Alibaba Cloud, Cloudflare, DNSPod, or GoDaddy) |

## 📦 Dependencies

Auto-installed: 

![nginx-ssl](https://img.shields.io/badge/-nginx--ssl-009639?style=flat-square&logo=nginx&logoColor=white)
![acme-acmesh](https://img.shields.io/badge/-acme--acmesh-blue?style=flat-square)
![acme-acmesh-dnsapi](https://img.shields.io/badge/-acme--acmesh--dnsapi-blue?style=flat-square)
![curl](https://img.shields.io/badge/-curl-073551?style=flat-square&logo=curl&logoColor=white)
![ca-bundle](https://img.shields.io/badge/-ca--bundle-grey?style=flat-square)
![ca-certificates](https://img.shields.io/badge/-ca--certificates-grey?style=flat-square)

## 🏗️ Project Structure

```
├── Makefile              OpenWrt SDK build definition
├── src/
│   ├── view/             LuCI JS frontend views (i18n via _())
│   ├── bin/              Main service script → /usr/sbin/https-gateway
│   ├── rpcd/             RPC backend → /usr/libexec/rpcd/https-gateway
│   ├── config/           UCI default config → /etc/config/https_gateway
│   ├── init/             procd init → /etc/init.d/https_gateway
│   ├── uci-defaults/     First-boot script → /etc/uci-defaults/
│   ├── share/            LuCI menu + ACL JSON
│   └── i18n/             Translation files (POT + PO)
│       ├── templates/    POT template (source strings)
│       └── zh_Hans/      Chinese Simplified translation
├── docs/                 Documentation
└── tests/                Unit & integration tests (149 tests)
```

## 🚀 Installation

### Signed APK Feed (OpenWrt 25.x, ARM64, Recommended)

For OpenWrt 25.x devices reporting `aarch64_cortex-a53`, install from the signed APK feed:

```sh
ssh root@192.168.0.1 'cat /etc/apk/arch'
ssh root@192.168.0.1 <<'EOF'
wget -O /etc/apk/keys/https-gateway-apk.pem \
	https://DawkliCrypto.github.io/luci-app-https-gateway/keys/https-gateway-apk.pem
printf '%s\n' \
	'https://DawkliCrypto.github.io/luci-app-https-gateway/packages/apk/packages.adb' \
	>> /etc/apk/repositories.d/customfeeds.list
apk update
apk add luci-app-https-gateway
EOF
```

See the [signed feed installation guide](docs/05-Signed-Feed.md) for details.

### Pre-built Package (OpenWrt 23.x)

Download the `.ipk` matching your router's architecture from the [Releases](https://github.com/seamys/luci-app-https-gateway/releases) page:

| Architecture | Target Devices |
|--------------|----------------|
| `x86_64` | Virtual machines, PC routers |
| `aarch64_cortex-a53` | MediaTek MT7981/7986 (Filogic) |
| `aarch64_generic` | Rockchip ARM64 boards |
| `arm_cortex-a7_neon-vfpv4` | Allwinner sunxi |

```sh
# Transfer to router
scp luci-app-https-gateway_*_x86_64.ipk root@192.168.0.1:/tmp/

# Install (OpenWrt 23.x with opkg)
ssh root@192.168.0.1 'opkg install /tmp/luci-app-https-gateway_*.ipk'

```

### Manual Deployment (Development/Debug)

```sh
ROUTER=root@192.168.0.1

scp src/bin/https-gateway          ${ROUTER}:/usr/sbin/
scp src/rpcd/https-gateway         ${ROUTER}:/usr/libexec/rpcd/
scp src/config/https_gateway       ${ROUTER}:/etc/config/
scp src/init/https_gateway         ${ROUTER}:/etc/init.d/
scp src/uci-defaults/50-luci-https-gateway ${ROUTER}:/etc/uci-defaults/
scp src/share/menu.d/luci-app-https-gateway.json ${ROUTER}:/usr/share/luci/menu.d/
scp src/share/acl.d/luci-app-https-gateway.json  ${ROUTER}:/usr/share/rpcd/acl.d/

ssh ${ROUTER} 'mkdir -p /www/luci-static/resources/view/https-gateway'
scp src/view/*.js ${ROUTER}:/www/luci-static/resources/view/https-gateway/

ssh ${ROUTER} 'chmod +x /usr/sbin/https-gateway /usr/libexec/rpcd/https-gateway /etc/init.d/https_gateway'
ssh ${ROUTER} '/etc/init.d/rpcd restart && /etc/init.d/https_gateway enable'
```

### ImageBuilder Built-in

```sh
cp src/bin/https-gateway           files/usr/sbin/
cp src/rpcd/https-gateway          files/usr/libexec/rpcd/
cp src/config/https_gateway        files/etc/config/
cp src/init/https_gateway          files/etc/init.d/
cp src/uci-defaults/50-luci-https-gateway files/etc/uci-defaults/
cp src/share/menu.d/*.json         files/usr/share/luci/menu.d/
cp src/share/acl.d/*.json          files/usr/share/rpcd/acl.d/
mkdir -p files/www/luci-static/resources/view/https-gateway
cp src/view/*.js                   files/www/luci-static/resources/view/https-gateway/
```

### APK/opkg Package Install (After SDK Build)

```sh
# opkg (OpenWrt 23.x)
opkg install luci-app-https-gateway_1.0.1-1_all.ipk

# APK (OpenWrt 25.x, locally built package)
apk add --allow-untrusted luci-app-https-gateway_*.apk
```

## ⚡ Quick Configuration

1. Navigate to **LuCI → Services → HTTPS Gateway**
2. Enter email, select DNS provider, fill in API credentials
3. Add a certificate (e.g. `*.example.com`)
4. Add proxy rules (domain + path + upstream address)
5. Enable gateway → **Save & Apply**
6. Click **"Issue/Renew Certificates"**

> 💡 **Tip**: Start with staging mode enabled to test your setup without hitting Let's Encrypt rate limits.

## 🧪 Testing

Run the full test suite (no router required):

```sh
sh tests/run_all.sh
```

| Suite | Tests | Coverage |
|-------|-------|----------|
| `test_validation.sh` | 47 | Domain, location, upstream regex validation |
| `test_nginx_conf.sh` | 37 | nginx config generation, TLS, WebSocket |
| `test_dns_certs.sh` | 25 | Certificate paths, wildcard matching, DNS sync |
| `test_integration.sh` | 25 | JSON output, UCI validation, service states |
| `test_validate.sh` | 15 | Legacy regex smoke tests |

## 🌍 Internationalization

The UI uses OpenWrt's standard PO/LMO i18n system:

- Source strings in English with `_()` markers in JS views
- Translations in `src/i18n/<lang>/https-gateway.po`
- Build produces `.lmo` binary files for LuCI runtime

**Available languages**: English (base), 中文简体 (zh_Hans)

To add a new language, copy `src/i18n/templates/https-gateway.pot` to `src/i18n/<lang>/https-gateway.po` and translate the `msgstr` entries.

## 📋 Release

To create a new release:

```sh
# Bump version in Makefile, then:
git tag v1.1.0
git push origin v1.1.0
```

GitHub Actions will automatically:
1. Download the OpenWrt SDK for each supported architecture
2. Compile `.ipk` packages (x86_64, aarch64, arm)
3. Create a source tarball for manual SDK builds
4. Publish a GitHub Release with all assets attached

### Supported architectures

| Arch | SDK Target | Typical Devices |
|------|-----------|-----------------|
| x86_64 | x86/64 | VMs, soft routers |
| aarch64_cortex-a53 | mediatek/filogic | GL.iNet MT3000, Xiaomi AX series |
| aarch64_generic | rockchip/armv8 | NanoPi R4S/R5S, FriendlyElec |
| arm_cortex-a7 | sunxi/cortexa7 | Orange Pi, Banana Pi |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/amazing-feature`)
3. Run tests (`sh tests/run_all.sh`)
4. Commit your changes (`git commit -m 'feat: add amazing feature'`)
5. Push to the branch (`git push origin feat/amazing-feature`)
6. Open a Pull Request

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**If this project helps you, consider giving it a ⭐**

</div>
