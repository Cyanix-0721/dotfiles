#!/bin/bash

set -e

echo "=== 安装 Flatpak ==="

# 安装 Flatpak
echo "安装 Flatpak..."
sudo pacman -S --noconfirm flatpak
echo "✓ Flatpak 安装完成"
