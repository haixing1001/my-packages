#!/bin/sh
LOG_FILE='/tmp/cloudflarespeedtest.log'

echolog() {
	local d="$(date "+%Y-%m-%d %H:%M:%S")"
	echo -e "$d: $*" >>$LOG_FILE
}

cf_token=$1
record_name=$2
isIpv6=$3
ip=$4

type="A"
if [ "$isIpv6" -eq "1" ] ;then
	type="AAAA"
fi

# ==========================================
# 自动获取 Zone ID 的函数
# ==========================================
get_zone_id() {
    local current_domain="$1"
    local zone_res
    local extracted_id

    # 逐级截取域名进行查询，直到域名中不再包含 "." (比如截取到最后只剩 com)
    while [ "${current_domain}" != "" ] && [ "$(echo "$current_domain" | grep -o '\.' | wc -l)" -ge 1 ]; do
        # 请求 Cloudflare API 匹配 Zone 域名
        zone_res=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${current_domain}" \
             -H "Authorization: Bearer $cf_token" \
             -H "Content-Type: application/json")

        # 检查返回结果中是否成功匹配到了该域名的信息
        if echo "$zone_res" | grep -q '"name":"'"$current_domain"'"'; then
            # 提取 Zone ID
            extracted_id=$(echo "$zone_res" | grep -o '"id":"[a-zA-Z0-9]*"' | head -n 1 | awk -F'"' '{print $4}')
            echo "$extracted_id"
            return 0
        fi

        # 截掉第一段子域名，继续查下一级 (例如把 test.example.com 变成 example.com)
        current_domain=$(echo "$current_domain" | cut -d'.' -f2-)
    done
    echo ""
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
record_res=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$cf_zone_id/dns_records?type=$type&name=$record_name" \
     -H "Authorization: Bearer $cf_token" \
     -H "Content-Type: application/json")

record_id=$(echo "$record_res" | grep -o '"id":"[a-zA-Z0-9]*"' | head -n 1 | awk -F'"' '{print $4}')

if [ -z "$record_id" ]; then
	# ==========================================
	# 2a. 如果记录不存在，则创建新记录
	# ==========================================
	res=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$cf_zone_id/dns_records" \
	     -H "Authorization: Bearer $cf_token" \
	     -H "Content-Type: application/json" \
	     --data '{"type":"'"$type"'","name":"'"$record_name"'","content":"'"$ip"'","ttl":60,"proxied":false}')
	
	if echo "$res" | grep -q '"success":true'; then
		echolog "成功添加 Cloudflare DNS 记录: $record_name ($ip)"
	else
		echolog "# 错误：添加 Cloudflare DNS 记录失败。请检查 API Token"
	fi
else
	# ==========================================
	# 2b. 如果记录已存在，则更新该记录
	# ==========================================
	res=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$cf_zone_id/dns_records/$record_id" \
	     -H "Authorization: Bearer $cf_token" \
	     -H "Content-Type: application/json" \
	     --data '{"type":"'"$type"'","name":"'"$record_name"'","content":"'"$ip"'","ttl":60,"proxied":false}')
	
	if echo "$res" | grep -q '"success":true'; then
		echolog "成功更新 Cloudflare DNS 记录: $record_name ($ip)"
	else
		echolog "# 错误：更新 Cloudflare DNS 记录失败。请检查 API Token"
	fi
fi
