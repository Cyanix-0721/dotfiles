#!/bin/bash

set -e

echo "=== 安装 Flatpak / Installing Flatpak ==="

# 安装 Flatpak / Install Flatpak
echo "安装 Flatpak... / Installing Flatpak..."
sudo pacman -S --noconfirm flatpak
echo "✓ Flatpak 安装完成 / Flatpak installation completed"
