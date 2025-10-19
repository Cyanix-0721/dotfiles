#!/bin/bash

set -e

echo "=== 系统基础环境配置 / System Foundation Setup ==="

# 检查网络连接 / Check network connection
echo "检查网络连接... / Checking network connection..."
if ! ping -c 1 archlinux.org &>/dev/null; then
  echo "错误: 无法连接到网络，请检查网络连接 / Error: Cannot connect to network, please check network connection"
  exit 1
fi

# 更新系统 / Update system
echo "更新系统... / Updating system..."
sudo pacman -Syu --noconfirm
echo "✓ 系统更新完成 / ✓ System update completed"

# 安装 git、svn 和基础开发工具 / Install git, svn and basic development tools
echo "安装 git、svn 和基础开发工具... / Installing git, svn and basic development tools..."
sudo pacman -S --needed --noconfirm git subversion base-devel
echo "✓ git、svn 和基础开发工具安装完成 / ✓ git, svn and basic development tools installed"

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

# 配置 ArchlinuxCN 仓库 / Configure ArchlinuxCN Repository
read -p "是否配置 ArchlinuxCN 仓库？(y/N) / Configure ArchlinuxCN repository? (y/N): " configure_archlinuxcn
if [[ $configure_archlinuxcn =~ ^[Yy]$ ]]; then
  echo "=== 配置 ArchlinuxCN 仓库 / Configuring ArchlinuxCN Repository ==="

  # 检查是否已配置 archlinuxcn / Check if archlinuxcn is already configured
  if ! sudo grep -q "\[archlinuxcn\]" /etc/pacman.conf; then
    echo "添加 ArchlinuxCN 仓库到 pacman.conf... / Adding ArchlinuxCN repository to pacman.conf..."
    echo -e "\n[archlinuxcn]\nServer = https://repo.archlinuxcn.org/\$arch" | sudo tee -a /etc/pacman.conf >/dev/null

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
else
  echo "跳过 ArchlinuxCN 仓库配置 / Skipping ArchlinuxCN repository configuration"
fi

# 安装 paru / Install paru
echo "安装 paru... / Installing paru..."
if ! command -v paru &>/dev/null; then
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
  if ! command -v yay &>/dev/null; then
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

# 安装 Flatpak / Install Flatpak
read -p "是否安装 Flatpak？(Y/n) / Install Flatpak? (Y/n): " install_flatpak
if [[ ! $install_flatpak =~ ^[Nn]$ ]]; then
  echo "=== 安装 Flatpak / Installing Flatpak ==="

  # 安装 Flatpak / Install Flatpak
  echo "安装 Flatpak… / Installing Flatpak…"
  sudo pacman -S --noconfirm flatpak
  echo "✓ Flatpak 安装完成 / Flatpak installation completed"
else
  echo "跳过 Flatpak 安装 / Skipping Flatpak installation"
fi

echo "✓ 系统基础环境配置完成 / ✓ System foundation setup completed"
