#!/bin/bash

set -e

echo "=== 安装 Chezmoi 并初始化配置 ==="

# 安装 Chezmoi
echo "安装 Chezmoi..."
sudo pacman -S --noconfirm chezmoi
echo "初始化 dotfiles 配置..."
chezmoi init https://github.com/Cyanix-0721/com.cyanix.dotfiles.git -a
echo "✓ Chezmoi 安装和初始化完成"
