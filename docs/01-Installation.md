# Installation Guide

## Prerequisites

- OpenWrt 23.05+ or 25.x
- SSH access to the router (root)
- A registered domain name (e.g. `example.com`)
- DNS provider API credentials (Alibaba Cloud, Cloudflare, DNSPod, or GoDaddy)

## Method 1: Signed APK Feed (OpenWrt 25.x, ARM64)

The signed feed is the recommended installation method for OpenWrt 25.x on `aarch64_cortex-a53` devices.

### Confirm your architecture

```sh
ssh root@192.168.0.1 'cat /etc/apk/arch'
# Expected: aarch64_cortex-a53
```

### Install the signing key and feed

```sh
ssh root@192.168.0.1 <<'EOF'
wget -O /etc/apk/keys/https-gateway-apk.pem \
	https://DawkliCrypto.github.io/luci-app-https-gateway/keys/https-gateway-apk.pem

printf '%s/packages/%s/Packages.adb\n' \
	'https://DawkliCrypto.github.io/luci-app-https-gateway' \
	"$(cat /etc/apk/arch)" >> /etc/apk/repositories.d/customfeeds.list

apk update
apk add luci-app-https-gateway
EOF
```

The package dependencies are resolved through the router's configured OpenWrt repositories. After installation, open LuCI and go to **Services → HTTPS Gateway**.

See [Signed APK Feed](05-Signed-Feed.md) for the feed URL and troubleshooting details.

## Method 2: Pre-built Package (OpenWrt 23.x)

Download the `.ipk` file matching your router's architecture from the [GitHub Releases](https://github.com/seamys/luci-app-https-gateway/releases) page.

### Determine your architecture

```sh
ssh root@192.168.0.1 'opkg print-architecture'
```

### Install with opkg

```sh
scp luci-app-https-gateway_*.ipk root@192.168.0.1:/tmp/
ssh root@192.168.0.1 'opkg install /tmp/luci-app-https-gateway_*.ipk'
```

Dependencies (`nginx-ssl`, `acme-acmesh`, etc.) are installed automatically.

After installation, access LuCI → **Services → HTTPS Gateway**.

## Method 3: Manual Deployment (Development)

### Step 1: Install Dependencies

```sh
ssh root@192.168.0.1
apk update
apk add nginx-ssl acme-acmesh acme-acmesh-dnsapi curl ca-bundle ca-certificates
```

### Step 2: Deploy Files

From your development machine:

```sh
ROUTER=root@192.168.0.1

# Core service
scp src/bin/https-gateway ${ROUTER}:/usr/sbin/
scp src/rpcd/https-gateway ${ROUTER}:/usr/libexec/rpcd/

# Configuration
scp src/config/https_gateway ${ROUTER}:/etc/config/
scp src/init/https_gateway ${ROUTER}:/etc/init.d/
scp src/uci-defaults/50-luci-https-gateway ${ROUTER}:/etc/uci-defaults/

# LuCI integration
scp src/share/menu.d/luci-app-https-gateway.json ${ROUTER}:/usr/share/luci/menu.d/
scp src/share/acl.d/luci-app-https-gateway.json ${ROUTER}:/usr/share/rpcd/acl.d/

# Frontend views
ssh ${ROUTER} 'mkdir -p /www/luci-static/resources/view/https-gateway'
scp src/view/*.js ${ROUTER}:/www/luci-static/resources/view/https-gateway/
```

### Step 3: Set Permissions and Enable

```sh
ssh ${ROUTER} <<'EOF'
chmod +x /usr/sbin/https-gateway
chmod +x /usr/libexec/rpcd/https-gateway
chmod +x /etc/init.d/https_gateway

# Run first-boot setup
sh /etc/uci-defaults/50-luci-https-gateway

# Enable and start
/etc/init.d/https_gateway enable
/etc/init.d/rpcd restart
EOF
```

### Step 4: Verify

Open `http://192.168.0.1` → navigate to **Services → HTTPS Gateway**. You should see the status dashboard.

## Method 4: ImageBuilder (Production)

Include files in the ImageBuilder `files/` overlay:

```sh
# Copy all source files into the ImageBuilder files/ tree
cp src/bin/https-gateway           files/usr/sbin/
cp src/rpcd/https-gateway          files/usr/libexec/rpcd/
cp src/config/https_gateway        files/etc/config/
cp src/init/https_gateway          files/etc/init.d/
cp src/uci-defaults/50-luci-https-gateway files/etc/uci-defaults/
cp src/share/menu.d/*.json         files/usr/share/luci/menu.d/
cp src/share/acl.d/*.json          files/usr/share/rpcd/acl.d/

mkdir -p files/www/luci-static/resources/view/https-gateway
cp src/view/*.js files/www/luci-static/resources/view/https-gateway/
```

Then build the image with these packages in your build configuration:

```
nginx-ssl acme-acmesh acme-acmesh-dnsapi curl ca-bundle ca-certificates
```

## Method 5: APK Package (SDK Build)

After building with the OpenWrt SDK:

```sh
scp bin/packages/*/luci/luci-app-https-gateway_*.apk root@192.168.0.1:/tmp/
ssh root@192.168.0.1 'apk add --allow-untrusted /tmp/luci-app-https-gateway_*.apk'
```

## Post-Install Checklist

| Step | Command | Expected Result |
|------|---------|-----------------|
| Service registered | `ls /etc/init.d/https_gateway` | File exists |
| rpcd plugin active | `ubus list | grep https` | `luci.https-gateway` |
| LuCI menu visible | Browser → Services | "HTTPS Gateway" entry |
| Config file exists | `cat /etc/config/https_gateway` | UCI config output |

## Uninstall

```sh
/etc/init.d/https_gateway stop
/etc/init.d/https_gateway disable
rm -f /usr/sbin/https-gateway
rm -f /usr/libexec/rpcd/https-gateway
rm -f /etc/init.d/https_gateway
rm -f /etc/config/https_gateway
rm -f /usr/share/luci/menu.d/luci-app-https-gateway.json
rm -f /usr/share/rpcd/acl.d/luci-app-https-gateway.json
rm -rf /www/luci-static/resources/view/https-gateway
rm -f /etc/nginx/conf.d/https-gateway.conf
/etc/init.d/rpcd restart
/etc/init.d/nginx restart
```
