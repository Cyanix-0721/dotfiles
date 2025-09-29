#!/bin/bash

set -e

echo "=== 安装基础工具和 AUR 助手 ==="

# 检查网络连接
echo "检查网络连接..."
if ! ping -c 1 archlinux.org &> /dev/null; then
    echo "错误: 无法连接到网络，请检查网络连接"
    exit 1
fi

# 更新系统
echo "更新系统..."
sudo pacman -Syu --noconfirm
echo "✓ 系统更新完成"

# 安装 git 和基础开发工具
echo "安装 git 和基础开发工具..."
sudo pacman -S --needed --noconfirm git base-devel
echo "✓ git 和基础开发工具安装完成"

# 安装 pacman 工具
echo "安装 pacman-contrib 和 reflector..."
sudo pacman -S --noconfirm pacman-contrib reflector
echo "✓ pacman-contrib 和 reflector 安装完成"

# 安装 paru
echo "安装 paru..."
if ! command -v paru &> /dev/null; then
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
    cd
    rm -rf "$temp_dir"
    echo "✓ paru 安装成功"
else
    echo "✓ paru 已安装，跳过"
fi

# 可选：安装 yay
read -p "是否安装 yay 作为备用 AUR 助手？(y/N): " install_yay
if [[ $install_yay =~ ^[Yy]$ ]]; then
    echo "安装 yay..."
    if ! command -v yay &> /dev/null; then
        temp_dir=$(mktemp -d)
        cd "$temp_dir"
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd
        rm -rf "$temp_dir"
        echo "✓ yay 安装成功"
    else
        echo "✓ yay 已安装，跳过"
    fi
fi

echo "✓ 基础工具和 AUR 助手安装完成"
