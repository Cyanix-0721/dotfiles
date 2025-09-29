#!/bin/bash

set -e

echo "=== 配置 ArchlinuxCN 仓库 ==="

# 检查是否已配置 archlinuxcn
if ! sudo grep -q "\[archlinuxcn\]" /etc/pacman.conf; then
    echo "添加 ArchlinuxCN 仓库到 pacman.conf..."
    echo -e "\n[archlinuxcn]\nServer = https://repo.archlinuxcn.org/\$arch" | sudo tee -a /etc/pacman.conf > /dev/null
    
    # 导入 GPG 密钥
    echo "导入 ArchlinuxCN GPG 密钥..."
    sudo pacman-key --lsign-key "farseerfc@archlinux.org"
    
    # 更新并安装密钥环
    echo "安装 archlinuxcn-keyring..."
    sudo pacman -Sy --noconfirm archlinuxcn-keyring
    echo "✓ ArchlinuxCN 仓库配置成功"
else
    echo "✓ ArchlinuxCN 仓库已配置，跳过"
fi
