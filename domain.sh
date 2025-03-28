#!/bin/bash

# 配置文件
CONFIG_FILE="$HOME/.aliyun_dns_config"

# 阿里云 API 相关参数
ENDPOINT="https://alidns.aliyuncs.com"
API_VERSION="2015-01-09"

# 读取 AccessKey
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        echo "首次运行，请输入你的阿里云 AccessKey 进行配置："
        change_ak
    fi
}

# 修改 AccessKey
change_ak() {
    read -p "AccessKeyId: " ACCESS_KEY_ID
    read -p "AccessKeySecret: " ACCESS_KEY_SECRET

    echo "ACCESS_KEY_ID=$ACCESS_KEY_ID" > "$CONFIG_FILE"
    echo "ACCESS_KEY_SECRET=$ACCESS_KEY_SECRET" >> "$CONFIG_FILE"

    echo "新的 AccessKey 配置已保存至 $CONFIG_FILE。"
    load_config
}

# 计算阿里云 API 签名
sign_request() {
    local params="$1"
    local sorted_params
    sorted_params=$(echo -n "$params" | tr '&' '\n' | sort | tr '\n' '&' | sed 's/&$//')

    local string_to_sign="GET&%2F&$(echo -n "$sorted_params" | jq -sRr @uri)"
    local signature
    signature=$(echo -n "$string_to_sign" | openssl dgst -sha1 -hmac "$ACCESS_KEY_SECRET&" -binary | base64)

    echo "$params&Signature=$(echo -n "$signature" | jq -sRr @uri)"
}

# 获取账户的域名列表
get_domains() {
    echo "正在获取您的域名列表..."
    local params="AccessKeyId=$ACCESS_KEY_ID&Action=DescribeDomains&Format=json&Version=$API_VERSION&Timestamp=$(date -u +%Y-%m-%dT%H%%3A%M%%3A%SZ)&SignatureMethod=HMAC-SHA1&SignatureVersion=1.0&SignatureNonce=$RANDOM"
    local signed_params
    signed_params=$(sign_request "$params")

    local response
    response=$(curl -s "$ENDPOINT?$signed_params")

    local domain_list
    domain_list=($(echo "$response" | jq -r '.Domains.Domain[].DomainName'))

    if [ ${#domain_list[@]} -eq 0 ]; then
        echo "未能获取到您的域名，请检查 API 配置是否正确。"
        exit 1
    fi

    echo "请选择一个域名："
    for i in "${!domain_list[@]}"; do
        echo "$((i+1))) ${domain_list[$i]}"
    done

    while true; do
        read -p "请输入序号 (1-${#domain_list[@]}): " choice
        if [[ $choice =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#domain_list[@]} )); then
            DOMAIN="${domain_list[$((choice-1))]}"
            echo "你选择的域名是：$DOMAIN"
            break
        else
            echo "输入无效，请重新输入！"
        fi
    done
}

# 获取 DNS 记录
list_records() {
    local params="AccessKeyId=$ACCESS_KEY_ID&Action=DescribeDomainRecords&DomainName=$DOMAIN&Format=json&Version=$API_VERSION&Timestamp=$(date -u +%Y-%m-%dT%H%%3A%M%%3A%SZ)&SignatureMethod=HMAC-SHA1&SignatureVersion=1.0&SignatureNonce=$RANDOM"
    local signed_params
    signed_params=$(sign_request "$params")

    local response
    response=$(curl -s "$ENDPOINT?$signed_params")

    record_ids=($(echo "$response" | jq -r '.DomainRecords.Record[].RecordId'))
    subdomains=($(echo "$response" | jq -r '.DomainRecords.Record[].RR'))
    ips=($(echo "$response" | jq -r '.DomainRecords.Record[].Value'))

    if [ ${#record_ids[@]} -eq 0 ]; then
        echo "未找到解析记录。"
        exit 1
    fi

    echo "现有的 DNS 解析记录："
    for i in "${!record_ids[@]}"; do
        echo "$((i+1))) ${subdomains[$i]}.$DOMAIN -> ${ips[$i]}"
    done
}

# 绑定解析
bind() {
    read -p "请输入要解析的子域名 (如 www): " SUBDOMAIN
    read -p "请输入要绑定的 IP 地址或目标域名: " TARGET

    echo "请选择记录类型:"
    echo "1) A 记录 (绑定 IP 地址)"
    echo "2) CNAME 记录 (绑定目标域名)"
    echo "3) TXT 记录"
    read -p "请输入数字 (1-3): " RECORD_TYPE

    case "$RECORD_TYPE" in
        "1") RECORD_TYPE="A" ;;
        "2") RECORD_TYPE="CNAME" ;;
        "3") RECORD_TYPE="TXT" ;;
        *) echo "无效选择" && exit 1 ;;
    esac

    local params="AccessKeyId=$ACCESS_KEY_ID&Action=AddDomainRecord&DomainName=$DOMAIN&RR=$SUBDOMAIN&Type=$RECORD_TYPE&Value=$TARGET&Format=json&Version=$API_VERSION&Timestamp=$(date -u +%Y-%m-%dT%H%%3A%M%%3A%SZ)&SignatureMethod=HMAC-SHA1&SignatureVersion=1.0&SignatureNonce=$RANDOM"
    local signed_params
    signed_params=$(sign_request "$params")

    local response
    response=$(curl -s "$ENDPOINT?$signed_params")

    echo "绑定成功!"
}

# 解绑解析
unbind() {
    list_records
    read -p "请输入要删除的记录编号: " selection
    record_id=${record_ids[$((selection-1))]}

    local params="AccessKeyId=$ACCESS_KEY_ID&Action=DeleteDomainRecord&RecordId=$record_id&Format=json&Version=$API_VERSION&Timestamp=$(date -u +%Y-%m-%dT%H%%3A%M%%3A%SZ)&SignatureMethod=HMAC-SHA1&SignatureVersion=1.0&SignatureNonce=$RANDOM"
    local signed_params
    signed_params=$(sign_request "$params")

    local response
    response=$(curl -s "$ENDPOINT?$signed_params")

    echo "解绑成功!"
}

# 修改解析记录
update_record() {
    list_records
    read -p "请输入要修改的记录编号: " selection
    record_id=${record_ids[$((selection-1))]}
    read -p "请输入新的解析值: " new_value

    local params="AccessKeyId=$ACCESS_KEY_ID&Action=UpdateDomainRecord&RecordId=$record_id&RR=${subdomains[$((selection-1))]}&Type=A&Value=$new_value&Format=json&Version=$API_VERSION&Timestamp=$(date -u +%Y-%m-%dT%H%%3A%M%%3A%SZ)&SignatureMethod=HMAC-SHA1&SignatureVersion=1.0&SignatureNonce=$RANDOM"
    local signed_params
    signed_params=$(sign_request "$params")

    local response
    response=$(curl -s "$ENDPOINT?$signed_params")

    echo "修改成功!"
}

# 选择操作
load_config
echo "请选择操作:"
echo "1) 绑定 (bind)"
echo "2) 解绑 (unbind)"
echo "3) 修改 AccessKey (change_ak)"
echo "4) 修改解析记录 (update)"
read -p "请输入数字 (1-4): " ACTION

case "$ACTION" in
    "1") get_domains; bind ;;
    "2") get_domains; unbind ;;
    "3") change_ak ;;
    "4") get_domains; update_record ;;
    *) echo "无效输入，请输入 1-4" && exit 1 ;;
esac