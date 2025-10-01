#!/bin/bash

set -e

echo "=== 安装基础工具和 AUR 助手 / Install basic tools and AUR helpers ==="

# 检查网络连接 / Check network connection
echo "检查网络连接... / Checking network connection..."
if ! ping -c 1 archlinux.org &> /dev/null; then
    echo "错误: 无法连接到网络，请检查网络连接 / Error: Cannot connect to network, please check network connection"
    exit 1
fi

# 更新系统 / Update system
echo "更新系统... / Updating system..."
sudo pacman -Syu --noconfirm
echo "✓ 系统更新完成 / ✓ System update completed"

# 安装 git 和基础开发工具 / Install git and basic development tools
echo "安装 git 和基础开发工具... / Installing git and basic development tools..."
sudo pacman -S --needed --noconfirm git base-devel
echo "✓ git 和基础开发工具安装完成 / ✓ git and basic development tools installed"

# 安装 pacman 工具 / Install pacman tools
echo "安装 pacman-contrib 和 reflector... / Installing pacman-contrib and reflector..."
sudo pacman -S --noconfirm pacman-contrib reflector
echo "✓ pacman-contrib 和 reflector 安装完成 / ✓ pacman-contrib and reflector installed"

# 配置 reflector 服务和定时器 / Configure reflector service and timer
read -p "是否配置 reflector 服务和定时器？(y/N) / Configure reflector service and timer? (y/N): " configure_reflector
if [[ $configure_reflector =~ ^[Yy]$ ]]; then
    echo "配置 reflector 服务和定时器... / Configuring reflector service and timer..."
    
    # 获取脚本所在目录 / Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REFLECTOR_SCRIPT_DIR="$(dirname "$SCRIPT_DIR")/reflector"
    
    if [[ -f "$REFLECTOR_SCRIPT_DIR/setup_reflector.sh" ]]; then
        # 运行 setup_reflector.sh
        echo "运行 reflector 安装脚本... / Running reflector setup script..."
        sudo "$REFLECTOR_SCRIPT_DIR/setup_reflector.sh"
        echo "✓ reflector 服务和定时器配置完成 / ✓ Reflector service and timer configured"
    else
        echo "警告: 未找到 reflector 安装脚本 / Warning: Reflector setup script not found at $REFLECTOR_SCRIPT_DIR/setup_reflector.sh"
        echo "跳过 reflector 配置 / Skipping reflector configuration"
    fi
else
    echo "跳过 reflector 服务配置 / Skipping reflector service configuration"
fi

# 安装 paru / Install paru
echo "安装 paru... / Installing paru..."
if ! command -v paru &> /dev/null; then
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
    cd
    rm -rf "$temp_dir"
    echo "✓ paru 安装成功 / ✓ paru installed successfully"
else
    echo "✓ paru 已安装，跳过 / ✓ paru already installed, skipping"
fi

# 可选：安装 yay / Optional: install yay
read -p "是否安装 yay 作为备用 AUR 助手？(y/N) / Install yay as alternative AUR helper? (y/N): " install_yay
if [[ $install_yay =~ ^[Yy]$ ]]; then
    echo "安装 yay... / Installing yay..."
    if ! command -v yay &> /dev/null; then
        temp_dir=$(mktemp -d)
        cd "$temp_dir"
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd
        rm -rf "$temp_dir"
        echo "✓ yay 安装成功 / ✓ yay installed successfully"
    else
        echo "✓ yay 已安装，跳过 / ✓ yay already installed, skipping"
    fi
fi

echo "✓ 基础工具和 AUR 助手安装完成 / ✓ Basic tools and AUR helpers installation completed"
