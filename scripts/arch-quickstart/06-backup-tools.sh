#!/bin/bash

set -e

echo "=== 安装备份工具 / Installing Backup Tools ==="

# 安装备份工具 / Install backup tools
echo "安装备份工具... / Installing backup tools..."
sudo pacman -S --noconfirm snapper btrfs-assistant
echo "✓ 备份工具安装完成 / Backup tools installation completed"
