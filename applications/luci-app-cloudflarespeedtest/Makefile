# Author: mingxiaoyu (fengying0347@163.com)
#
# Licensed to the public under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-cloudflarespeedtest

LUCI_TITLE:=LuCI support for Cloudflares Speed Test
LUCI_DEPENDS:=+cdnspeedtest +openssl-util +curl
LUCI_PKGARCH:=all
PKG_VERSION:=1.5.4
PKG_RELEASE:=0
PKG_LICENSE:=AGPL-3.0
PKG_MAINTAINER:=mingxiaoyu <fengying0347@163.com>

# call BuildPackage - OpenWrt buildroot signature
# 1. 声明：告诉系统哪些是需要保护的配置文件
define Package/$(PKG_NAME)/conffiles
/etc/config/cloudflarespeedtest
endef

# 2. 安装：实际把文件放进安装包并设定正确的权限
define Package/$(PKG_NAME)/install
	# 安装可执行的脚本
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/cloudflarespeedtest $(1)/etc/init.d/cloudflarespeedtest
	
	# 安装不具备执行权限的配置文件
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/cloudflarespeedtest $(1)/etc/config/cloudflarespeedtest

	$(INSTALL_DIR) $(1)/usr/share/CloudflareSpeedTest/
	$(INSTALL_DATA) ./root/usr/share/CloudflareSpeedTest/ip.txt $(1)/usr/share/CloudflareSpeedTest/
	$(INSTALL_DATA) ./root/usr/share/CloudflareSpeedTest/ipv6.txt $(1)/usr/share/CloudflareSpeedTest/
	
	$(INSTALL_DIR) $(1)/usr/bin/cloudflarespeedtest/
	$(INSTALL_BIN) ./root/usr/bin/cloudflarespeedtest/aliddns.sh $(1)/usr/bin/cloudflarespeedtest/
	$(INSTALL_BIN) ./root/usr/bin/cloudflarespeedtest/cloudflarespeedtest.sh $(1)/usr/bin/cloudflarespeedtest/

endef
# 安装后脚本，可以配置权限等但不建议
define Package/$(PKG_NAME)/postinst
 #!/bin/sh
 chmod 0755 /usr/bin/cloudflarespeedtest/*.sh
 exit 0

endef

include $(TOPDIR)/feeds/luci/luci.mk
