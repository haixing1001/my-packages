#!/bin/sh
LOG_FILE='/var/log/cloudflarespeedtest.log'

echolog() {
	local d="$(date "+%Y-%m-%d %H:%M:%S")"
	echo -e "$d: $*" >>$LOG_FILE
}

cf_token=$1
record_name=$2
isIpv6=$3
ip=$4

type="A"
if [ "$isIpv6" = "1" ] ;then
	type="AAAA"
fi

safe_curl() {
    curl -s --connect-timeout 5 --max-time 10 "$@"
}

# ==========================================
# 逐级递进循环获取 Zone ID (完美支持多级子域名如 test.xx.xx.com)
# ==========================================
get_zone_id() {
    local current_domain="$1"
    local zone_id=""

    # 循环条件：当前域名不为空且包含点号 "."
    while [ -n "$current_domain" ] && echo "$current_domain" | grep -q '\.'; do
        # 请求 Cloudflare API 匹配当前级别的域名
        zone_res=$(safe_curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${current_domain}&status=active" \
             -H "Authorization: Bearer $cf_token" \
             -H "Content-Type: application/json")

        # 使用 OpenWrt 自带的 jsonfilter 解析 id
        zone_id=$(echo "$zone_res" | jsonfilter -e '@.result[0].id')
        
        # 如果找到了有效的 Zone ID，直接输出并返回成功
        if [ -n "$zone_id" ]; then
            echo "$zone_id"
            return 0
        fi

        # 如果当前级别未找到，剥离最左侧的一级子域名继续往下匹配
        # 演进过程示例：test.xx.xx.com -> xx.xx.com -> xx.com
        current_domain=$(echo "$current_domain" | cut -d'.' -f2-)
    done
    return 1
}

# 调用函数获取 Zone ID
cf_zone_id=$(get_zone_id "$record_name")

if [ -z "$cf_zone_id" ]; then
    echolog "# 错误：无法为 $record_name 自动获取 Zone ID。请检查 API Token 权限或该域名是否在你的 Cloudflare 账号中。"
    exit 1
fi

echolog "成功获取到 $record_name 所属的 Zone ID: $cf_zone_id"

# ==========================================
# 1. 尝试获取现有的 DNS 记录 ID
# ==========================================
record_res=$(safe_curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$cf_zone_id/dns_records?type=$type&name=$record_name" \
     -H "Authorization: Bearer $cf_token" \
     -H "Content-Type: application/json")

record_id=$(echo "$record_res" | jsonfilter -e '@.result[0].id')

if [ -z "$record_id" ]; then
	# ==========================================
	# 2a. 如果记录不存在，则创建新记录
	# ==========================================
	res=$(safe_curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$cf_zone_id/dns_records" \
	     -H "Authorization: Bearer $cf_token" \
	     -H "Content-Type: application/json" \
	     --data '{"type":"'"$type"'","name":"'"$record_name"'","content":"'"$ip"'","ttl":60,"proxied":false}')
	
	success=$(echo "$res" | jsonfilter -e '@.success')
	if [ "$success" = "true" ]; then
		echolog "成功添加 Cloudflare DNS 记录: $record_name ($ip)"
	else
		echolog "# 错误：添加 Cloudflare DNS 记录失败。请检查 API Token"
	fi
else
	# ==========================================
	# 2b. 如果记录已存在，则更新该记录
	# ==========================================
	res=$(safe_curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$cf_zone_id/dns_records/$record_id" \
	     -H "Authorization: Bearer $cf_token" \
	     -H "Content-Type: application/json" \
	     --data '{"type":"'"$type"'","name":"'"$record_name"'","content":"'"$ip"'","ttl":60,"proxied":false}')
	
	success=$(echo "$res" | jsonfilter -e '@.success')
	if [ "$success" = "true" ]; then
		echolog "成功更新 Cloudflare DNS 记录: $record_name ($ip)"
	else
		echolog "# 错误：更新 Cloudflare DNS 记录失败。请检查 API Token"
	fi
fi
