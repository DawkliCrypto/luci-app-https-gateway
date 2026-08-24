# Signed APK Feed

The project publishes signed OpenWrt 25.x APK packages for supported architectures:

- `x86_64`
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

printf '%s/packages/%s/Packages.adb\n' \
  'https://DawkliCrypto.github.io/luci-app-https-gateway' \
  "$(cat /etc/apk/arch)" > /etc/apk/repositories.d/https-gateway.list

apk update
apk add luci-app-https-gateway
```

The repository URL must match the router architecture returned by `cat /etc/apk/arch`. The package still declares its normal dependencies, so `apk` resolves them from the configured OpenWrt repositories.
