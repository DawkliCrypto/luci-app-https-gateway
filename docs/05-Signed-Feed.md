# Signed APK Feed

The project publishes a signed OpenWrt 25.x APK package for:

- `aarch64_cortex-a53`

The feed is published by the `Signed APK Feed` GitHub Actions workflow on every `v*` tag. The repository's private signing key is stored only in the GitHub Actions secret `APK_SEC_PEM`; the public key is available at:

```text
https://DawkliCrypto.github.io/luci-app-https-gateway/keys/https-gateway-apk.pem
```

GitHub Pages must be enabled for the repository's `gh-pages` branch after the first feed run.

## Install on OpenWrt 25.x

```sh
wget -O /etc/apk/keys/https-gateway-apk.pem \
  https://DawkliCrypto.github.io/luci-app-https-gateway/keys/https-gateway-apk.pem

printf '%s\n' \
  'https://DawkliCrypto.github.io/luci-app-https-gateway/packages/apk/packages.adb' \
  >> /etc/apk/repositories.d/customfeeds.list

apk update
apk add luci-app-https-gateway
```

The feed uses the fixed `packages/apk/` path. Confirm that `cat /etc/apk/arch` reports `aarch64_cortex-a53` before installing. The package still declares its normal dependencies, so `apk` resolves them from the configured OpenWrt repositories.

## Upgrade an Existing Installation

Refresh the repository index before upgrading. `--force-overwrite` only handles file conflicts; it does not force APK to use a newer repository index.

```sh
apk update --force-refresh
apk policy luci-app-https-gateway
apk upgrade --force-overwrite luci-app-https-gateway
```

The policy output should show `0.3.14-r1` or a newer version as available. If it does not, check the configured feed and architecture:

```sh
cat /etc/apk/arch
cat /etc/apk/repositories.d/customfeeds.list
apk update --force-refresh
apk list --available luci-app-https-gateway
```

The feed URL must be exactly:

```text
https://dawklicrypto.github.io/luci-app-https-gateway/packages/apk/packages.adb
```
