#!/bin/bash

set -e

echo "=== 配置 ArchlinuxCN 仓库 / Configuring ArchlinuxCN Repository ==="

# 检查是否已配置 archlinuxcn / Check if archlinuxcn is already configured
if ! sudo grep -q "\[archlinuxcn\]" /etc/pacman.conf; then
    echo "添加 ArchlinuxCN 仓库到 pacman.conf... / Adding ArchlinuxCN repository to pacman.conf..."
    echo -e "\n[archlinuxcn]\nServer = https://repo.archlinuxcn.org/\$arch" | sudo tee -a /etc/pacman.conf > /dev/null
    
    # 导入 GPG 密钥 / Import GPG key
    echo "导入 ArchlinuxCN GPG 密钥... / Importing ArchlinuxCN GPG key..."
    sudo pacman-key --lsign-key "farseerfc@archlinux.org"
    
    # 更新并安装密钥环 / Update and install keyring
    echo "安装 archlinuxcn-keyring... / Installing archlinuxcn-keyring..."
    sudo pacman -Sy --noconfirm archlinuxcn-keyring
    echo "✓ ArchlinuxCN 仓库配置成功 / ArchlinuxCN repository configured successfully"
else
    echo "✓ ArchlinuxCN 仓库已配置，跳过 / ArchlinuxCN repository already configured, skipping"
fi
