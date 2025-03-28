#!/bin/bash

# 检查是否以 root 权限执行脚本
if [ "$(id -u)" -ne 0 ]; then
    echo "此脚本需要以 root 权限运行。请使用 sudo 执行脚本。"
    exit 1
fi

# 设置脚本的目标路径
SCRIPT_URL="https://raw.githubusercontent.com/yourusername/yourrepository/main/domain.sh"
TARGET_PATH="/usr/local/bin/domain"

# 下载脚本并保存到 /usr/local/bin/domain
echo "正在从 $SCRIPT_URL 下载脚本..."
curl -s -L "$SCRIPT_URL" -o "$TARGET_PATH"

# 确保下载的脚本有执行权限
chmod +x "$TARGET_PATH"

# 输出成功安装的提示
echo "脚本已成功安装到 /usr/local/bin/domain，您现在可以通过运行 'domain' 命令来执行脚本。"