#!/bin/bash

set -e

echo "=== 安装常用软件 / Installing Common Software ==="

# 检查 paru 是否已安装 / Check if paru is installed
if ! command -v paru &>/dev/null; then
  echo "错误: paru 未安装，请先运行系统基础环境配置脚本 (01-system-foundation.sh) / Error: paru not installed, please run the system foundation setup script (01-system-foundation.sh) first"
  exit 1
fi

echo "安装命令行效率工具… / Installing command line efficiency tools…"
sudo pacman -S --noconfirm fzf zoxide ripgrep fd eza bat stow

echo "安装办公与笔记软件… / Installing office and note-taking software…"
sudo pacman -S --noconfirm obsidian keepassxc thunderbird thunderbird-i18n-zh-cn libreoffice-fresh libreoffice-fresh-zh-cn
paru -S --noconfirm zen-browser-bin ungoogled-chromium-bin

echo "安装媒体与工具软件… / Installing media and utility software…"
sudo pacman -S --noconfirm vlc mpv yazi 7zip ffmpeg gimp
paru -S --noconfirm localsend-bin bibata-cursor-theme-bin

echo "安装开发与系统工具… / Installing development and system tools…"
sudo pacman -S --noconfirm neovim lazygit github-cli btop fastfetch dex uv ast-grep
paru -S --noconfirm clash-verge-rev-bin

# 询问是否安装 Podman
echo -n "是否安装 Podman 和 podman-compose？[Y/n] / Install Podman and podman-compose? [Y/n]: "
read -r install_podman

# 设置默认值为 Y
install_podman=${install_podman:-Y}

if [[ $install_podman =~ ^[Yy]$ ]]; then
  echo "安装 Podman 和 podman-compose… / Installing Podman and podman-compose…"
  sudo pacman -S --noconfirm podman podman-compose

  echo "配置 Podman 镜像源… / Configuring Podman registry mirror…"

  # 创建配置文件并写入内容
  sudo tee /etc/containers/registries.conf.d/10-unqualified-search-registries.conf <<EOF
unqualified-search-registries = ["docker.io"]
EOF

  echo "✓ Podman 安装和配置完成 / Podman installation and configuration completed"
else
  echo "跳过 Podman 安装 / Skipping Podman installation"
fi

echo "安装文档处理工具… / Installing document processing tools…"
sudo pacman -S --noconfirm poppler resvg imagemagick jq

echo "安装通讯软件… / Installing communication software…"
sudo pacman -S --noconfirm telegram-desktop

echo "✓ 常用软件安装完成 / Common software installation completed"
