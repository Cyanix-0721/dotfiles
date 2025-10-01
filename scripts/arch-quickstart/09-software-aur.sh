#!/bin/bash

set -e

echo "=== 安装常用软件 (AUR) / Installing Common Software (AUR) ==="

# 检查 paru 是否已安装 / Check if paru is installed
if ! command -v paru &> /dev/null; then
    echo "错误: paru 未安装，请先运行基础工具安装脚本 / Error: paru not installed, please run the base tools installation script first"
    exit 1
fi

# 安装常用软件 (AUR) / Install common software (AUR)
echo "安装常用软件 (AUR)... / Installing common software (AUR)..."
paru -S --noconfirm localsend-bin clash-verge-rev-bin zen-browser-bin
echo "✓ 常用软件 (AUR) 安装完成 / Common software (AUR) installation completed"
