#!/bin/bash

# 确保以 root 用户运行
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用 root 权限运行此脚本！"
    exit 1
fi

# 安装必要的软件包
install_dependencies() {
    echo "正在安装必要的依赖项 (curl, jq)..."

    # 根据系统类型安装依赖
    if command -v yum &>/dev/null; then
        yum install -y epel-release
        yum install -y curl jq
    elif command -v apt &>/dev/null; then
        apt update
        apt install -y curl jq
    elif command -v pacman &>/dev/null; then
        pacman -Syu --noconfirm curl jq
    elif command -v brew &>/dev/null; then
        brew install curl jq
    else
        echo "无法检测到受支持的包管理器，请手动安装 curl 和 jq。"
        exit 1
    fi

    echo "依赖安装完成！"
}

# 下载主脚本
install_domain_script() {
    echo "正在下载 domain 脚本..."
    curl -s -L -o /usr/local/bin/domain https://raw.githubusercontent.com/takumijie/aliyun_dns_controller/refs/heads/main/domain.sh
    chmod +x /usr/local/bin/domain
    echo "安装完成！你可以运行 'domain' 命令使用。"
}

install_dependencies
install_domain_script