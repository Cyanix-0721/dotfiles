#!/bin/bash

set -e

echo "=== 安装常用软件 / Installing Common Software ==="

# 检查 paru 是否已安装 / Check if paru is installed
if ! command -v paru &> /dev/null; then
    echo "错误: paru 未安装，请先运行系统基础环境配置脚本 (01-system-foundation.sh) / Error: paru not installed, please run the system foundation setup script (01-system-foundation.sh) first"
    exit 1
fi

echo "安装命令行效率工具… / Installing command line efficiency tools…"
sudo pacman -S --noconfirm fzf zoxide ripgrep fd eza bat

echo "安装办公与笔记软件… / Installing office and note-taking software…"
sudo pacman -S --noconfirm obsidian keepassxc thunderbird thunderbird-i18n-zh-cn
paru -S --noconfirm zen-browser-bin

echo "安装媒体与工具软件… / Installing media and utility software…"
sudo pacman -S --noconfirm vlc mpv yazi 7zip ffmpeg
paru -S --noconfirm localsend-bin bibata-cursor-theme-bin

echo "安装开发与系统工具… / Installing development and system tools…"
sudo pacman -S --noconfirm neovim lazygit github-cli btop fastfetch dex
paru -S --noconfirm clash-verge-rev-bin

echo "安装文档处理工具… / Installing document processing tools…"
sudo pacman -S --noconfirm poppler resvg imagemagick jq

echo "安装通讯软件… / Installing communication software…"
sudo pacman -S --noconfirm telegram-desktop

echo "✓ 常用软件安装完成 / Common software installation completed"
