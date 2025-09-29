#!/bin/bash

set -e

echo "=== 安装备份工具 ==="

# 安装备份工具
echo "安装备份工具..."
sudo pacman -S --noconfirm snapper btrfs-assistant
echo "✓ 备份工具安装完成"
