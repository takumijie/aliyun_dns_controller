#!/bin/bash

# 检查并设置 AccessKey 信息
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

# 检查是否存在配置文件，如果不存在则引导用户输入 AccessKey
if [ ! -f "$CONFIG_FILE" ]; then
    echo "首次运行，请输入你的阿里云 AccessKey 进行配置："
    change_ak
else
    # 读取本地保存的 AccessKey
    source "$CONFIG_FILE"
fi

# 用户选择操作
echo "请选择操作:"
echo "1) 绑定 (bind)"
echo "2) 解绑 (unbind)"
echo "3) 修改 AccessKey (change_ak)"
echo "4) 修改解析记录 (update)"
read -p "请输入数字 (1-4): " ACTION

if [[ "$ACTION" != "1" && "$ACTION" != "2" && "$ACTION" != "3" && "$ACTION" != "4" ]]; then
    echo "无效输入，请输入 1 (绑定)、2 (解绑)、3 (修改 AccessKey) 或 4 (修改解析记录)。"
    exit 1
fi

# 如果用户选择修改 AccessKey，则执行并退出
if [ "$ACTION" == "3" ]; then
    change_ak
    exit 0
fi

# 交互式输入用户参数
read -p "请输入你的域名 (如 example.com): " DOMAIN

# 绑定（添加解析记录）
bind() {
    read -p "请输入要解析的子域名 (如 www): " SUBDOMAIN
    read -p "请输入要绑定的 IP 地址或目标域名: " TARGET

    # 选择记录类型
    echo "请选择记录类型:"
    echo "1) A 记录 (绑定 IP 地址)"
    echo "2) CNAME 记录 (绑定目标域名)"
    echo "3) TXT 记录"
    read -p "请输入数字 (1-3): " RECORD_TYPE

    if [[ "$RECORD_TYPE" != "1" && "$RECORD_TYPE" != "2" && "$RECORD_TYPE" != "3" ]]; then
        echo "无效选择，请选择 1、2 或 3。"
        exit 1
    fi

    case "$RECORD_TYPE" in
        "1") # A 记录
            RECORD_TYPE="A"
            ;;
        "2") # CNAME 记录
            RECORD_TYPE="CNAME"
            ;;
        "3") # TXT 记录
            RECORD_TYPE="TXT"
            ;;
    esac

    echo "正在绑定 $SUBDOMAIN.$DOMAIN 类型: $RECORD_TYPE 到 $TARGET ..."
    local response=$(curl -s "https://alidns.aliyuncs.com/?Action=AddDomainRecord&DomainName=$DOMAIN&RR=$SUBDOMAIN&Type=$RECORD_TYPE&Value=$TARGET&AccessKeyId=$ACCESS_KEY_ID")
    echo "绑定成功: $response"
}

# 解绑（删除解析记录）
unbind() {
    echo "正在获取 $DOMAIN 的解析记录..."
    list_records

    local total_records=$(wc -l < /tmp/record_ids.txt)
    if [ "$total_records" -eq 0 ]; then
        echo "未找到任何解析记录，无法解绑。"
        exit 1
    fi

    read -p "请输入要解绑的编号 (1-$total_records): " selection

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "$total_records" ]; then
        echo "无效选择，请输入正确的编号。"
        exit 1
    fi

    local record_id=$(sed -n "${selection}p" /tmp/record_ids.txt)
    local subdomain=$(sed -n "${selection}p" /tmp/record_subdomains.txt)
    local ip_address=$(sed -n "${selection}p" /tmp/record_ips.txt)

    echo "正在解绑 $subdomain.$DOMAIN (IP: $ip_address)..."
    local response=$(curl -s "https://alidns.aliyuncs.com/?Action=DeleteDomainRecord&RecordId=$record_id&AccessKeyId=$ACCESS_KEY_ID")
    echo "解绑成功: $response"
}

# 修改解析记录的值
update_record() {
    echo "正在获取 $DOMAIN 的解析记录..."
    list_records

    local total_records=$(wc -l < /tmp/record_ids.txt)
    if [ "$total_records" -eq 0 ]; then
        echo "未找到任何解析记录，无法修改。"
        exit 1
    fi

    read -p "请输入要修改的记录编号 (1-$total_records): " selection

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "$total_records" ]; then
        echo "无效选择，请输入正确的编号。"
        exit 1
    fi

    local record_id=$(sed -n "${selection}p" /tmp/record_ids.txt)
    local subdomain=$(sed -n "${selection}p" /tmp/record_subdomains.txt)
    local old_ip=$(sed -n "${selection}p" /tmp/record_ips.txt)

    read -p "请输入新的 IP 地址或目标域名 (当前: $old_ip): " new_target

    echo "正在更新 $subdomain.$DOMAIN 的记录值从 $old_ip 修改为 $new_target ..."
    local response=$(curl -s "https://alidns.aliyuncs.com/?Action=UpdateDomainRecord&RecordId=$record_id&RR=$subdomain&Type=A&Value=$new_target&AccessKeyId=$ACCESS_KEY_ID")
    echo "修改成功: $response"
}

# 执行选择的操作
if [ "$ACTION" == "1" ]; then
    bind
elif [ "$ACTION" == "2" ]; then
    unbind
elif [ "$ACTION" == "4" ]; then
    update_record
fi