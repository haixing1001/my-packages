include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-cloudflarespeedtest
PKG_VERSION:=1.5.5
PKG_RELEASE:=1

LUCI_TITLE:=LuCI support for Cloudflare Speed Test
LUCI_DEPENDS:=+cdnspeedtest +openssl-util +curl
LUCI_PKGARCH:=all

PKG_LICENSE:=AGPL-3.0
PKG_MAINTAINER:=haixing1001

define Package/$(PKG_NAME)/conffiles
/etc/config/cloudflarespeedtest
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/cloudflarespeedtest $(1)/etc/init.d/cloudflarespeedtest

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/cloudflarespeedtest $(1)/etc/config/cloudflarespeedtest

	$(INSTALL_DIR) $(1)/usr/share/CloudflareSpeedTest
	$(INSTALL_DATA) ./root/usr/share/CloudflareSpeedTest/ip.txt $(1)/usr/share/CloudflareSpeedTest/
	$(INSTALL_DATA) ./root/usr/share/CloudflareSpeedTest/ipv6.txt $(1)/usr/share/CloudflareSpeedTest/

	$(INSTALL_DIR) $(1)/usr/bin/cloudflarespeedtest
	$(INSTALL_BIN) ./root/usr/bin/cloudflarespeedtest/*.sh $(1)/usr/bin/cloudflarespeedtest/
endef

include $(TOPDIR)/feeds/luci/luci.mk
