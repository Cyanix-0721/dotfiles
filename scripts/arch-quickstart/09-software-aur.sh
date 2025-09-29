#!/bin/bash

set -e

echo "=== 安装常用软件 (AUR) ==="

# 检查 paru 是否已安装
if ! command -v paru &> /dev/null; then
    echo "错误: paru 未安装，请先运行基础工具安装脚本"
    exit 1
fi

# 安装常用软件 (AUR)
echo "安装常用软件 (AUR)..."
paru -S --noconfirm localsend-bin clash-verge-rev-bin zen-browser-bin
echo "✓ 常用软件 (AUR) 安装完成"
