#!/bin/bash

set -e

echo "=== 系统基础环境配置 / System Foundation Setup ==="

# 检查网络连接 / Check network connection
echo "检查网络连接… / Checking network connection…"
if ! ping -c 1 archlinux.org &>/dev/null; then
	echo "错误: 无法连接到网络，请检查网络连接 / Error: Cannot connect to network, please check network connection"
	exit 1
fi

# 更新系统 / Update system
echo "更新系统… / Updating system…"
sudo pacman -Syu --noconfirm
echo "✓ 系统更新完成 / ✓ System update completed"

# 安装 git、svn 和基础开发工具 / Install git, svn and basic development tools
echo "安装 git、svn 和基础开发工具… / Installing git, svn and basic development tools…"
sudo pacman -S --needed --noconfirm git subversion base-devel
echo "✓ git、svn 和基础开发工具安装完成 / ✓ git, svn and basic development tools installed"

# 安装 pacman 工具 / Install pacman tools
echo "安装 pacman-contrib 和 reflector… / Installing pacman-contrib and reflector…"
sudo pacman -S --noconfirm pacman-contrib reflector
echo "✓ pacman-contrib 和 reflector 安装完成 / ✓ pacman-contrib and reflector installed"

# 配置 reflector 服务和定时器 / Configure reflector service and timer
read -p "是否配置 reflector 服务和定时器？(y/N) / Configure reflector service and timer? (y/N): " configure_reflector
if [[ $configure_reflector =~ ^[Yy]$ ]]; then
	echo "配置 reflector 服务和定时器… / Configuring reflector service and timer…"

	# 获取脚本所在目录 / Get script directory
	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	REFLECTOR_SCRIPT_DIR="$(dirname "$SCRIPT_DIR")/reflector"

	if [[ -f "$REFLECTOR_SCRIPT_DIR/setup_reflector.sh" ]]; then
		# 运行 setup_reflector.sh
		echo "运行 reflector 安装脚本… / Running reflector setup script…"
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
		echo "添加 ArchlinuxCN 仓库到 pacman.conf… / Adding ArchlinuxCN repository to pacman.conf…"
		echo -e "\n[archlinuxcn]\nServer = https://repo.archlinuxcn.org/\$arch" | sudo tee -a /etc/pacman.conf >/dev/null

		# 导入 GPG 密钥 / Import GPG key
		echo "导入 ArchlinuxCN GPG 密钥… / Importing ArchlinuxCN GPG key…"
		sudo pacman-key --lsign-key "farseerfc@archlinux.org"

		# 更新并安装密钥环 / Update and install keyring
		echo "安装 archlinuxcn-keyring… / Installing archlinuxcn-keyring…"
		sudo pacman -Sy --noconfirm archlinuxcn-keyring
		echo "✓ ArchlinuxCN 仓库配置成功 / ArchlinuxCN repository configured successfully"
	else
		echo "✓ ArchlinuxCN 仓库已配置，跳过 / ArchlinuxCN repository already configured, skipping"
	fi
else
	echo "跳过 ArchlinuxCN 仓库配置 / Skipping ArchlinuxCN repository configuration"
fi

# 安装 paru / Install paru
echo "安装 paru… / Installing paru…"
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
	echo "安装 yay… / Installing yay…"
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

# 检查并配置 OpenSSH 和 ssh-agent
echo "=== 配置 SSH Agent / Configuring SSH Agent ==="

# 检查 openssh 是否已安装
if ! command -v ssh &>/dev/null; then
	echo "OpenSSH 未安装，正在安装… / OpenSSH not installed, installing…"
	sudo pacman -S --noconfirm openssh
	echo "✓ OpenSSH 安装完成 / OpenSSH installed"
else
	echo "✓ OpenSSH 已安装 / OpenSSH already installed"
fi

# 启用 ssh-agent 用户服务
echo "启用 ssh-agent 用户服务… / Enabling ssh-agent user service…"
systemctl --user enable --now ssh-agent.service
echo "✓ ssh-agent 用户服务已启用 / ssh-agent user service enabled"

# 提示用户配置环境变量
echo ""
echo "提示 / Note:"
echo "  请在 Fish 配置中添加以下环境变量："
echo "  Please add the following environment variable to your Fish config:"
echo "  set -Ux SSH_AUTH_SOCK \"\$XDG_RUNTIME_DIR/ssh-agent.socket\""
echo ""

# rEFInd 引导管理器
echo "=== rEFInd 引导管理器 / rEFInd Boot Manager ==="

# 检查 rEFInd 是否已安装
if command -v refind-install &>/dev/null; then
	echo "✓ rEFInd 已安装 / rEFInd is already installed"
	refind_available=true
else
	read -p "是否安装 rEFInd 引导管理器？(Y/n) / Install rEFInd boot manager? (Y/n): " install_refind
	if [[ ! $install_refind =~ ^[Nn]$ ]]; then
		echo "安装 rEFInd 引导管理器… / Installing rEFInd boot manager…"
		sudo pacman -S --noconfirm refind

		# 验证安装是否成功
		if command -v refind-install &>/dev/null; then
			echo "✓ rEFInd 安装完成 / rEFInd installation completed"
			refind_available=true
		else
			echo "✗ rEFInd 安装失败 / rEFInd installation failed"
			refind_available=false
		fi
	else
		echo "跳过 rEFInd 安装 / Skipping rEFInd installation"
		refind_available=false
	fi
fi

# 询问是否运行 refind-install (仅在工具可用时)
if [[ $refind_available == "true" ]]; then
	read -p "是否运行 refind-install 安装到 EFI 系统分区？(Y/n) / Run refind-install to install to EFI system partition? (Y/n): " run_refind_install
	if [[ ! $run_refind_install =~ ^[Nn]$ ]]; then
		echo "安装 rEFInd 到 EFI 系统分区… / Installing rEFInd to EFI system partition…"
		sudo refind-install
		echo "✓ rEFInd 已安装到 EFI 系统分区 / rEFInd installed to EFI system partition"
	else
		echo "跳过 refind-install / Skipping refind-install"
	fi
fi

# 安装 rEFInd 主题 (仅在 rEFInd 可用时)
if [[ $refind_available == "true" ]]; then
	echo "=== rEFInd 主题安装 / rEFInd Theme Installation ==="
	read -p "是否安装 Catppuccin 主题？(Y/n) / Install Catppuccin theme? (Y/n): " install_refind_theme
	if [[ ! $install_refind_theme =~ ^[Nn]$ ]]; then

		# 查找 rEFInd 目录
		REFIND_DIR=""
		if [[ -d "/boot/EFI/refind" ]]; then
			REFIND_DIR="/boot/EFI/refind"
			echo "找到 rEFInd 目录… (路径: $REFIND_DIR) / Found rEFInd directory… (path: $REFIND_DIR)"
		else
			# 在 /boot 下搜索 refind 文件夹
			echo "在 /boot 下搜索 rEFInd 目录… / Searching for rEFInd directory in /boot…"
			REFIND_SEARCH=$(find /boot -type d -name "refind" 2>/dev/null | head -n1)
			if [[ -n "$REFIND_SEARCH" && -d "$REFIND_SEARCH" ]]; then
				REFIND_DIR="$REFIND_SEARCH"
				echo "找到 rEFInd 目录… (路径: $REFIND_DIR) / Found rEFInd directory… (path: $REFIND_DIR)"
			else
				echo "✗ 未找到 rEFInd 目录，跳过主题安装 / rEFInd directory not found, skipping theme installation"
			fi
		fi

		# 如果找到 rEFInd 目录，安装主题
		if [[ -n "$REFIND_DIR" ]]; then
			# 创建 themes 目录
			THEMES_DIR="$REFIND_DIR/themes"
			echo "创建主题目录… (目标: $THEMES_DIR) / Creating theme directory… (target: $THEMES_DIR)"
			sudo mkdir -p "$THEMES_DIR"

			# 克隆主题
			echo "克隆 Catppuccin 主题… / Cloning Catppuccin theme…"
			if command -v git &>/dev/null; then
				sudo git clone https://github.com/catppuccin/refind.git "$THEMES_DIR/catppuccin"

				# 选择主题口味
				echo "请选择主题口味 / Please select theme flavor:"
				echo "1) latte"
				echo "2) frappe"
				echo "3) macchiato"
				echo "4) mocha (默认/default)"
				read -p "输入选择 (1-4) / Enter choice (1-4) [4]: " flavor_choice

				case $flavor_choice in
				1) FLAVOR="latte" ;;
				2) FLAVOR="frappe" ;;
				3) FLAVOR="macchiato" ;;
				*) FLAVOR="mocha" ;;
				esac

				echo "选择的口味: $FLAVOR / Selected flavor: $FLAVOR"

				# 检查主题文件是否存在
				THEME_CONF="$THEMES_DIR/catppuccin/${FLAVOR}.conf"
				if [[ -f "$THEME_CONF" ]]; then
					# 备份原配置文件
					REFIND_CONF="$REFIND_DIR/refind.conf"
					if [[ -f "$REFIND_CONF" ]]; then
						sudo cp "$REFIND_CONF" "$REFIND_CONF.bak"
						echo "已备份原配置文件: $REFIND_CONF.bak / Original config backed up: $REFIND_CONF.bak"
					fi

					# 添加主题配置到 refind.conf
					echo "添加主题配置到 refind.conf… / Adding theme configuration to refind.conf…"
					INCLUDE_LINE="include themes/catppuccin/${FLAVOR}.conf"

					# 检查是否已包含该主题
					if ! sudo grep -q "include themes/catppuccin/" "$REFIND_CONF" 2>/dev/null; then
						echo "$INCLUDE_LINE" | sudo tee -a "$REFIND_CONF" >/dev/null
						echo "✓ 主题配置已添加 / Theme configuration added"
					else
						echo "✓ 主题配置已存在 / Theme configuration already exists"
					fi

					echo "✓ Catppuccin 主题安装完成 / Catppuccin theme installation completed"
				else
					echo "✗ 主题配置文件不存在: $THEME_CONF / Theme config file not found: $THEME_CONF"
				fi
			else
				echo "✗ git 未安装，无法克隆主题 / git not installed, cannot clone theme"
			fi
		fi
	else
		echo "跳过 rEFInd 主题安装 / Skipping rEFInd theme installation"
	fi
fi

# 备份工具
echo "=== 备份工具 / Backup Tools ==="
read -p "是否安装备份工具？(Y/n) / Install backup tools? (Y/n): " install_backup_tools
if [[ ! $install_backup_tools =~ ^[Nn]$ ]]; then
	echo "安装备份工具… / Installing backup tools…"
	sudo pacman -S --noconfirm snapper btrfs-assistant
	echo "✓ 备份工具安装完成 / Backup tools installation completed"
else
	echo "跳过备份工具安装 / Skipping backup tools installation"
fi

# Chezmoi 配置管理工具
echo "=== Chezmoi 配置管理工具 / Chezmoi Configuration Management Tool ==="

# 检查 Chezmoi 是否已安装
if command -v chezmoi &>/dev/null; then
	echo "✓ Chezmoi 已安装 / Chezmoi is already installed"
	chezmoi_available=true
else
	read -p "是否安装 Chezmoi 配置管理工具？(Y/n) / Install Chezmoi configuration management tool? (Y/n): " install_chezmoi
	if [[ ! $install_chezmoi =~ ^[Nn]$ ]]; then
		echo "安装 Chezmoi… / Installing Chezmoi…"
		sudo pacman -S --noconfirm chezmoi

		# 验证安装是否成功
		if command -v chezmoi &>/dev/null; then
			echo "✓ Chezmoi 安装完成 / Chezmoi installation completed"
			chezmoi_available=true
		else
			echo "✗ Chezmoi 安装失败 / Chezmoi installation failed"
			chezmoi_available=false
		fi
	else
		echo "跳过 Chezmoi 安装 / Skipping Chezmoi installation"
		chezmoi_available=false
	fi
fi

# 询问是否初始化 dotfiles (仅在工具可用时)
if [[ $chezmoi_available == "true" ]]; then
	read -p "是否初始化 dotfiles 配置？(Y/n) / Initialize dotfiles configuration? (Y/n): " init_chezmoi
	if [[ ! $init_chezmoi =~ ^[Nn]$ ]]; then
		echo "初始化 dotfiles 配置… / Initializing dotfiles configuration…"
		chezmoi init https://github.com/Cyanix-0721/dotfiles.git -a
		echo "✓ dotfiles 配置初始化完成 / dotfiles configuration initialized"
	else
		echo "跳过 dotfiles 配置初始化 / Skipping dotfiles configuration initialization"
	fi
fi

echo "✓ 系统基础环境配置完成 / ✓ System foundation setup completed"
