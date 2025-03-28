#!/bin/bash

# 确保以 root 用户运行
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用 root 权限运行此脚本！"
    exit 1
fi

# 检测系统版本
OS_ID=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')
OS_VERSION=$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | tr -d '"')

# 获取 CentOS 版本
get_centos_version() {
    if [ -f /etc/redhat-release ]; then
        grep -oE '[0-9]+' /etc/redhat-release | head -1
    else
        echo "0"
    fi
}

# 安装 EPEL 源
install_epel() {
    local centos_version=$(get_centos_version)
    if [ "$centos_version" == "7" ]; then
        echo "检测到 CentOS 7，正在安装 EPEL..."
        rpm -ivh https://archives.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm
    elif [ "$centos_version" == "8" ] || [ "$centos_version" == "9" ]; then
        echo "检测到 CentOS $centos_version，正在安装 EPEL..."
        dnf install -y epel-release
    elif [ "$centos_version" == "6" ]; then
        echo "检测到 CentOS 6，正在安装 EPEL（已停止维护，可能不稳定）..."
        rpm -ivh https://archives.fedoraproject.org/pub/archive/epel/6/x86_64/Packages/e/epel-release-6-8.noarch.rpm
    else
        echo "无法确定 CentOS 版本，跳过 EPEL 安装。"
    fi
}

# 安装 jq
install_jq() {
    echo "正在安装 jq..."
    if command -v jq &>/dev/null; then
        echo "jq 已安装，无需重复安装。"
        return
    fi
    
    if [[ "$OS_ID" == "centos" && "$OS_VERSION" =~ ^7 ]]; then
        echo "检测到 CentOS 7，尝试安装 jq..."
        if yum install -y jq; then
            echo "jq 安装成功！"
            return
        fi
        echo "yum 安装 jq 失败，尝试手动下载安装包..."
        wget -O /tmp/jq.rpm http://mirror.centos.org/centos/7/updates/x86_64/Packages/jq-1.6-2.el7.x86_64.rpm
        if rpm -ivh /tmp/jq.rpm; then
            echo "jq 手动安装成功！"
        else
            echo "jq 安装失败，请手动检查！"
            exit 1
        fi
    else
        echo "正在使用默认软件包管理器安装 jq..."
        if command -v apt &>/dev/null; then
            apt update && apt install -y jq
        elif command -v dnf &>/dev/null; then
            dnf install -y jq
        elif command -v pacman &>/dev/null; then
            pacman -Syu --noconfirm jq
        elif command -v zypper &>/dev/null; then
            zypper install -y jq
        elif command -v brew &>/dev/null; then
            brew install jq
        else
            echo "未找到合适的软件包管理器，请手动安装 jq！"
            exit 1
        fi
    fi
}

# 安装必要的软件包
install_dependencies() {
    echo "正在安装必要的依赖项 (curl, jq)..."
    if command -v yum &>/dev/null; then
        install_epel
        yum install -y curl
    elif command -v dnf &>/dev/null; then
        install_epel
        dnf install -y curl
    elif command -v apt &>/dev/null; then
        apt update
        apt install -y curl
    elif command -v pacman &>/dev/null; then
        pacman -Syu --noconfirm curl
    elif command -v zypper &>/dev/null; then
        zypper install -y curl
    elif command -v brew &>/dev/null; then
        brew install curl
    else
        echo "无法检测到受支持的包管理器，请手动安装 curl。"
        exit 1
    fi
    install_jq
    echo "依赖安装完成！"
}

# 下载并安装 domain 脚本
install_domain_script() {
    echo "正在下载 domain 脚本..."
    curl -s -L -o /usr/local/bin/domain https://raw.githubusercontent.com/takumijie/aliyun_dns_controller/refs/heads/main/domain.sh
    chmod +x /usr/local/bin/domain
    echo "安装完成！你可以运行 'domain' 命令使用。"
}

install_dependencies
install_domain_script
