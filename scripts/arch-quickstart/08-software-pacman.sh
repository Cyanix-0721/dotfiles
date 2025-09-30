#!/bin/bash

set -e

echo "=== 安装常用软件 (Pacman) ==="

# 安装常用软件 (Pacman)
echo "安装常用软件 (Pacman)..."
sudo pacman -S --noconfirm obsidian keepassxc vlc mpv 7zip yazi ffmpeg jq poppler resvg imagemagick neovim dex btop fastfetch github-cli
echo "✓ 常用软件 (Pacman) 安装完成"
