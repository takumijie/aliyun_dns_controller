#!/bin/bash

# 配置文件路径
CONFIG_FILE="$HOME/.aliyun_dns_config"

# 函数：修改 AccessKey
change_ak() {
    echo "请输入新的阿里云 AccessKey 进行配置："
    read -p "AccessKeyId: " ACCESS_KEY_ID
    read -p "AccessKeySecret: " ACCESS_KEY_SECRET

    # 保存到配置文件
    echo "ACCESS_KEY_ID=$ACCESS_KEY_ID" > "$CONFIG_FILE"
    echo "ACCESS_KEY_SECRET=$ACCESS_KEY_SECRET" >> "$CONFIG_FILE"

    echo "新的 AccessKey 配置已保存至 $CONFIG_FILE。"
}

# 检查 AccessKey 是否已配置
if [ ! -f "$CONFIG_FILE" ]; then
    echo "首次运行，请输入你的阿里云 AccessKey 进行配置："
    change_ak
fi

# 读取 AccessKey
source "$CONFIG_FILE"

# 阿里云 API 相关参数
ENDPOINT="https://alidns.aliyuncs.com"
API_VERSION="2015-01-09"
FORMAT="json"

# 获取当前时间戳
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
nonce=$RANDOM$RANDOM

# 获取账户的域名列表
get_domains() {
    echo "正在获取您的域名列表..."
    response=$(curl -s -X GET "$ENDPOINT" \
        -d "Action=DescribeDomains" \
        -d "Version=$API_VERSION" \
        -d "AccessKeyId=$ACCESS_KEY_ID" \
        -d "Format=$FORMAT" \
        -d "Timestamp=$timestamp" \
        -d "SignatureNonce=$nonce")

    domain_list=($(echo "$response" | grep -o '"DomainName":"[^"]*' | awk -F ':"' '{print $2}'))

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

    echo "正在绑定 $SUBDOMAIN.$DOMAIN 类型: $RECORD_TYPE 到 $TARGET ..."
    response=$(curl -s "$ENDPOINT" \
        -d "Action=AddDomainRecord" \
        -d "DomainName=$DOMAIN" \
        -d "RR=$SUBDOMAIN" \
        -d "Type=$RECORD_TYPE" \
        -d "Value=$TARGET" \
        -d "AccessKeyId=$ACCESS_KEY_ID")
    echo "绑定成功: $response"
}

# 获取 DNS 记录
list_records() {
    response=$(curl -s "$ENDPOINT" \
        -d "Action=DescribeDomainRecords" \
        -d "DomainName=$DOMAIN" \
        -d "AccessKeyId=$ACCESS_KEY_ID")

    record_ids=($(echo "$response" | grep -o '"RecordId":"[^"]*' | awk -F ':"' '{print $2}'))
    subdomains=($(echo "$response" | grep -o '"RR":"[^"]*' | awk -F ':"' '{print $2}'))
    ips=($(echo "$response" | grep -o '"Value":"[^"]*' | awk -F ':"' '{print $2}'))

    if [ ${#record_ids[@]} -eq 0 ]; then
        echo "未找到解析记录。"
        exit 1
    fi

    echo "现有的 DNS 解析记录："
    for i in "${!record_ids[@]}"; do
        echo "$((i+1))) ${subdomains[$i]}.$DOMAIN -> ${ips[$i]}"
    done
}

# 解绑解析
unbind() {
    list_records
    read -p "请输入要删除的记录编号: " selection
    record_id=${record_ids[$((selection-1))]}
    
    response=$(curl -s "$ENDPOINT" \
        -d "Action=DeleteDomainRecord" \
        -d "RecordId=$record_id" \
        -d "AccessKeyId=$ACCESS_KEY_ID")
    echo "解绑成功: $response"
}

# 修改解析记录
update_record() {
    list_records
    read -p "请输入要修改的记录编号: " selection
    record_id=${record_ids[$((selection-1))]}
    read -p "请输入新的解析值: " new_value

    response=$(curl -s "$ENDPOINT" \
        -d "Action=UpdateDomainRecord" \
        -d "RecordId=$record_id" \
        -d "RR=${subdomains[$((selection-1))]}" \
        -d "Type=A" \
        -d "Value=$new_value" \
        -d "AccessKeyId=$ACCESS_KEY_ID")
    echo "修改成功: $response"
}

# 选择操作
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