#!/bin/bash

set -e

echo "=== 安装 Chezmoi 并初始化配置 / Installing Chezmoi and Initializing Configuration ==="

# 安装 Chezmoi / Install Chezmoi
echo "安装 Chezmoi... / Installing Chezmoi..."
sudo pacman -S --noconfirm chezmoi

echo "初始化 dotfiles 配置... / Initializing dotfiles configuration..."
chezmoi init https://github.com/Cyanix-0721/dotfiles.git -a

echo "✓ Chezmoi 安装和初始化完成 / Chezmoi installation and initialization completed"
