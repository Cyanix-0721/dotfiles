#!/bin/bash

set -e

echo "=== 安装常用软件 (Pacman) / Installing Common Software (Pacman) ==="

# 安装常用软件 (Pacman) / Install common software (Pacman)
echo "安装常用软件 (Pacman)… / Installing common software (Pacman)…"

echo "安装命令行效率工具… / Installing command line efficiency tools…"
sudo pacman -S --noconfirm fzf zoxide ripgrep fd eza bat

echo "安装办公与笔记软件… / Installing office and note-taking software…"
sudo pacman -S --noconfirm obsidian keepassxc thunderbird thunderbird-i18n-zh-cn

echo "安装媒体与工具软件… / Installing media and utility software…"
sudo pacman -S --noconfirm vlc mpv yazi 7zip ffmpeg

echo "安装开发与系统工具… / Installing development and system tools…"
sudo pacman -S --noconfirm neovim lazygit github-cli btop fastfetch dex

echo "安装文档处理工具… / Installing document processing tools…"
sudo pacman -S --noconfirm poppler resvg imagemagick jq

echo "安装通讯软件… / Installing communication software…"
sudo pacman -S --noconfirm telegram-desktop

echo "✓ 常用软件 (Pacman) 安装完成 / Common software (Pacman) installation completed"
