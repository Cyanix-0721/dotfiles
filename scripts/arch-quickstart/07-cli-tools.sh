#!/bin/bash

set -e

echo "=== 安装命令行效率工具 ==="

# 安装命令行效率工具
echo "安装命令行效率工具..."
sudo pacman -S --noconfirm fzf zoxide ripgrep fd eza
echo "✓ 命令行效率工具安装完成"
