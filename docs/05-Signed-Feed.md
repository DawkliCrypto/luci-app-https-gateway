# Signed APK Feed

The project publishes a signed OpenWrt 25.x APK package for:

- `aarch64_cortex-a53`

The feed is published by the `Release` GitHub Actions workflow on every `v*` tag. The source repository is private. The repository's private signing key is stored only in the GitHub Actions secret `APK_SEC_PEM`; the public key is published with the feed at:

```text
https://DawkliCrypto.github.io/luci-app-https-gateway/keys/https-gateway-apk.pem
```

GitHub Pages must be enabled for the private repository using the `gh-pages` branch and `/(root)` folder. GitHub Pages for private repositories requires a GitHub plan that supports private-repository Pages. If Pages cannot be enabled, publish the feed from a separate public repository instead.

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
apk upgrade --available --force-overwrite luci-app-https-gateway
```

The policy output should show `0.3.14-r1` or a newer version as available. If it does not, check the configured feed and architecture:

```sh
cat /etc/apk/arch
cat /etc/apk/repositories.d/customfeeds.list
apk update --force-refresh
apk list --available luci-app-https-gateway
```

`--available` is important when the installed package came from a local APK file. It removes the exact-file constraint and allows APK to replace it with the repository version.

The feed URL must be exactly:

```text
https://dawklicrypto.github.io/luci-app-https-gateway/packages/apk/packages.adb
```
