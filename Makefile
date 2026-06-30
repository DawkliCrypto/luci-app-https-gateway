include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-https-gateway
# Placeholder — overridden by CI from the release tag (vX.Y.Z)
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=haizi

LUCI_TITLE:=LuCI HTTPS Gateway - Reverse Proxy Manager
LUCI_DESCRIPTION:=Manage nginx reverse proxy with automatic ACME certificates and local DNS for LAN services
LUCI_DEPENDS:=+acme-acmesh +acme-acmesh-dnsapi +curl +ca-bundle +ca-certificates
LUCI_PKGARCH:=all

PKG_PO_VERSION:=$(PKG_VERSION)-$(PKG_RELEASE)

include $(TOPDIR)/feeds/luci/luci.mk

define Package/luci-app-https-gateway/conffiles
/etc/config/https_gateway
endef

define Package/luci-app-https-gateway/install
	# LuCI JS views
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/https-gateway
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/view/*.js \
		$(1)/www/luci-static/resources/view/https-gateway/

	# UCI default config
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/src/config/https_gateway $(1)/etc/config/

	# procd init script
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/init/https_gateway $(1)/etc/init.d/

	# UCI defaults (first-boot)
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/uci-defaults/50-luci-https-gateway $(1)/etc/uci-defaults/

	# Main service script
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/bin/https-gateway $(1)/usr/sbin/

	# rpcd backend
	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/rpcd/https-gateway $(1)/usr/libexec/rpcd/

	# LuCI menu registration
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/share/menu.d/luci-app-https-gateway.json \
		$(1)/usr/share/luci/menu.d/

	# rpcd ACL
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/share/acl.d/luci-app-https-gateway.json \
		$(1)/usr/share/rpcd/acl.d/
endef

define Package/luci-app-https-gateway/poinstall
	# Install PO-compiled .lmo translation files
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	for lang in $$(ls $(PKG_BUILD_DIR)/src/i18n/ 2>/dev/null | grep -v templates); do \
		if [ -f "$(PKG_BUILD_DIR)/src/i18n/$$lang/https-gateway.po" ]; then \
			po2lmo $(PKG_BUILD_DIR)/src/i18n/$$lang/https-gateway.po \
				$(1)/usr/lib/lua/luci/i18n/https-gateway.$$lang.lmo 2>/dev/null || true; \
		fi; \
	done
endef

$(eval $(call BuildPackage,luci-app-https-gateway))
