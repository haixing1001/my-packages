#!/bin/sh
LOG_FILE='/var/log/cloudflarespeedtest.log'

echolog() {
	local d="$(date "+%Y-%m-%d %H:%M:%S")"
	echo -e "$d: $*" >>$LOG_FILE
}

cf_token=$1
record_name=$2
isIpv6=$3
ips=$4  # 核心修改：接收由空格分隔的多条优选 IP 列表

type="A"
if [ "$isIpv6" = "1" ] ;then
	type="AAAA"
fi

# 封装通用的安全 curl 命令，自带超时机制防止网络波动卡死
safe_curl() {
    curl -s --connect-timeout 10 --max-time 15 "$@"
}

# ==========================================
# 逐级递进循环获取 Zone ID
# ==========================================
get_zone_id() {
    local current_domain="$1"
    local zone_id=""

    while [ -n "$current_domain" ] && echo "$current_domain" | grep -q '\.'; do
        zone_res=$(safe_curl -X GET "https://api.cloudflare.com/client/v4/zones?name=${current_domain}&status=active" \
             -H "Authorization: Bearer $cf_token" \
             -H "Content-Type: application/json")

        zone_id=$(echo "$zone_res" | jsonfilter -e '@.result[0].id')
        
        if [ -n "$zone_id" ]; then
            echo "$zone_id"
            return 0
        fi

        current_domain=$(echo "$current_domain" | cut -d'.' -f2-)
    done
    return 1
}

cf_zone_id=$(get_zone_id "$record_name")

if [ -z "$cf_zone_id" ]; then
    echolog "# 错误：无法为 $record_name 自动获取 Zone ID。请检查网络或 Token 权限。"
    exit 1
fi

echolog "成功获取到 Zone ID: $cf_zone_id"

# ==========================================
# 1. 获取现有同名同类型的所有 DNS 记录 ID 列表
# ==========================================
record_res=$(safe_curl -X GET "https://api.cloudflare.com/client/v4/zones/$cf_zone_id/dns_records?type=$type&name=$record_name" \
     -H "Authorization: Bearer $cf_token" \
     -H "Content-Type: application/json")

# 提取现有所有旧解析记录的 ID 序列
existing_ids=$(echo "$record_res" | jsonfilter -e '@.result[*].id')

# 利用位置参数管理旧记录 ID 队列
set -- $existing_ids

# ==========================================
# 2. 智能遍历并覆盖同步最新的多个优选 IP
# ==========================================
for ip in $ips; do
    current_id=$1 # 取出当前队列最前面的旧记录 ID
    
    if [ -n "$current_id" ]; then
        # 2a. 存在旧记录：直接原地 PUT 更新，无缝无断流切换
        res=$(safe_curl -X PUT "https://api.cloudflare.com/client/v4/zones/$cf_zone_id/dns_records/$current_id" \
             -H "Authorization: Bearer $cf_token" \
             -H "Content-Type: application/json" \
             --data '{"type":"'"$type"'","name":"'"$record_name"'","content":"'"$ip"'","ttl":60,"proxied":false}')
        
        success=$(echo "$res" | jsonfilter -e '@.success')
        if [ "$success" = "true" ]; then
            echolog "成功更新 DNS 记录: $record_name -> $ip"
        else
            echolog "# 错误：更新 DNS 记录失败 ($ip)"
        fi
        shift # 弹出已使用的旧 ID
    else
        # 2b. 旧记录已用尽（如调大了测速数量）：调用 POST 创建新解析
        res=$(safe_curl -X POST "https://api.cloudflare.com/client/v4/zones/$cf_zone_id/dns_records" \
             -H "Authorization: Bearer $cf_token" \
             -H "Content-Type: application/json" \
             --data '{"type":"'"$type"'","name":"'"$record_name"'","content":"'"$ip"'","ttl":60,"proxied":false}')
        
        success=$(echo "$res" | jsonfilter -e '@.success')
        if [ "$success" = "true" ]; then
            echolog "成功添加 DNS 新记录: $record_name -> $ip"
        else
            echolog "# 错误：添加 DNS 记录失败 ($ip)"
        fi
    fi
done

# ==========================================
# 3. 收尾清理：如果新 IP 同步完了还有剩余的旧解析记录，将其抹除
# ==========================================
while [ -n "$1" ]; do
    leftover_id=$1
    res=$(safe_curl -X DELETE "https://api.cloudflare.com/client/v4/zones/$cf_zone_id/dns_records/$leftover_id" \
         -H "Authorization: Bearer $cf_token" \
         -H "Content-Type: application/json")
    
    success=$(echo "$res" | jsonfilter -e '@.success')
    if [ "$success" = "true" ]; then
        echolog "成功清理闲置多余的旧记录 ID: $leftover_id"
    fi
    shift
done
