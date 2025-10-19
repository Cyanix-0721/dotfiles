#!/bin/bash

set -e

echo "=== 安装常用软件 / Installing Common Software ==="

# 检查 paru 是否已安装
if ! command -v paru &>/dev/null; then
  echo "错误: paru 未安装，请先运行系统基础环境配置脚本 / Error: paru not installed, please run the system foundation setup script first"
  exit 1
fi

echo "安装命令行工具… / Installing command line tools…"
sudo pacman -S --noconfirm fzf zoxide ripgrep fd eza bat stow btop fastfetch dex viu

echo "安装开发工具… / Installing development tools…"
sudo pacman -S --noconfirm neovim python-pynvim lazygit gitui github-cli uv ast-grep git-delta poppler resvg imagemagick jq luarocks
paru -S --noconfirm visual-studio-code-bin

echo "安装系统工具… / Installing system tools…"
sudo pacman -S --noconfirm mako fuzzel ntfs-3g niri
paru -S --noconfirm octopi dms-shell-git

echo "安装网络工具… / Installing network tools…"
paru -S --noconfirm clash-verge-rev-bin

echo "安装日常应用… / Installing daily applications…"
sudo pacman -S --noconfirm obsidian keepassxc thunderbird thunderbird-i18n-zh-cn libreoffice-fresh libreoffice-fresh-zh-cn mpv ffmpeg gimp yazi 7zip telegram-desktop dolphin nautilus scrcpy syncthing mpd rmpc kdenlive
paru -S --noconfirm zen-browser-bin ungoogled-chromium-bin localsend-bin bibata-cursor-theme-bin qt6ct-kde vesktop-bin syncthingtray-qt6

# 询问是否安装 Podman
echo -n "是否安装 Podman 和 podman-compose？[Y/n] / Install Podman and podman-compose? [Y/n]: "
read -r install_podman

install_podman=${install_podman:-Y}

if [[ $install_podman =~ ^[Yy]$ ]]; then
  echo "安装容器工具… / Installing container tools…"
  sudo pacman -S --noconfirm podman podman-compose podman-docker

  echo "配置 Podman 镜像源… / Configuring Podman registry mirror…"
  sudo tee /etc/containers/registries.conf.d/10-unqualified-search-registries.conf <<EOF
unqualified-search-registries = ["docker.io"]
EOF

  echo "✓ Podman 安装和配置完成 / Podman installation and configuration completed"
else
  echo "跳过 Podman 安装 / Skipping Podman installation"
fi

# 询问是否安装 LazyVim
echo -n "是否安装 LazyVim Starter？[y/N] / Install LazyVim Starter? [y/N]: "
read -r install_lazyvim

install_lazyvim=${install_lazyvim:-N}

if [[ $install_lazyvim =~ ^[Yy]$ ]]; then
  echo "安装 LazyVim Starter… / Installing LazyVim Starter…"

  # 询问是否备份现有配置
  echo -n "是否备份现有 Neovim 配置？[Y/n] / Backup existing Neovim configuration? [Y/n]: "
  read -r backup_nvim

  backup_nvim=${backup_nvim:-Y}

  if [[ $backup_nvim =~ ^[Yy]$ ]]; then
    echo "备份 Neovim 配置… / Backing up Neovim configuration…"
    # 必需备份
    mv ~/.config/nvim ~/.config/nvim.bak 2>/dev/null || echo "无现有 nvim 配置可备份 / No existing nvim configuration to backup"

    # 可选但推荐的备份
    mv ~/.local/share/nvim ~/.local/share/nvim.bak 2>/dev/null || echo "无 nvim 共享数据可备份 / No nvim share data to backup"
    mv ~/.local/state/nvim ~/.local/state/nvim.bak 2>/dev/null || echo "无 nvim 状态数据可备份 / No nvim state data to backup"
    mv ~/.cache/nvim ~/.cache/nvim.bak 2>/dev/null || echo "无 nvim 缓存可备份 / No nvim cache to backup"

    echo "✓ Neovim 配置备份完成 / Neovim configuration backup completed"
  fi

  # 克隆 LazyVim starter
  git clone https://github.com/LazyVim/starter ~/.config/nvim

  # 删除 .git 文件夹
  rm -rf ~/.config/nvim/.git

  echo "✓ LazyVim Starter 安装完成 / LazyVim Starter installation completed"
  echo ""
  echo "提示 / Tip:"
  echo "  1. 运行 'nvim' 启动 Neovim / Run 'nvim' to start Neovim"
  echo "  2. 建议运行 :LazyHealth 检查安装状态 / It is recommended to run :LazyHealth to check if everything is working correctly"
  echo "  3. 参考配置文件中的注释来自定义 LazyVim / Refer to the comments in the files on how to customize LazyVim"
else
  echo "跳过 LazyVim 安装 / Skipping LazyVim installation"
fi

# 询问是否安装 vfox
echo -n "是否安装 vfox (版本管理工具)？[Y/n] / Install vfox (version manager)? [Y/n]: "
read -r install_vfox

install_vfox=${install_vfox:-Y}

if [[ $install_vfox =~ ^[Yy]$ ]]; then
  echo "安装 vfox… / Installing vfox…"
  curl -sSL https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash
  echo "✓ vfox 安装完成 / vfox installation completed"
else
  echo "跳过 vfox 安装 / Skipping vfox installation"
fi

echo "✓ 常用软件安装完成 / Common software installation completed"
