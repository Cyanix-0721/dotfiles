#!/bin/bash

set -e

# 加载公共函数
. "$(dirname "$0")/00-common.sh"

# 自动确认模式（全选 Y）
init_auto_yes

header "安装常用软件 / Installing Common Software"

# 检查 paru 是否已安装
if ! command -v paru &>/dev/null; then
	err "paru 未安装，请先运行系统基础环境配置脚本 / paru not installed; run foundation setup first"
	exit 1
fi

step "安装命令行工具 / Installing command line tools"
install_official 1 fzf zoxide ripgrep fd eza bat stow btop fastfetch dex viu less

step "安装开发工具 / Installing development tools"
install_official 1 neovim python-pynvim lazygit gitui github-cli uv ast-grep git-delta poppler resvg imagemagick jq luarocks ruff shellcheck shfmt copyparty
install_aur 1 visual-studio-code-bin

step "安装系统工具 / Installing system tools"
install_official 1 mako fuzzel ntfs-3g niri lysd qt6ct xwayland-satellite playerctl polkit-kde-agent xdg-desktop-portal xdg-desktop-portal-gtk nwg-look cliphist wl-clipboard wl-clip-persist udisks2
install_aur 1 systemd-manager-tui

step "安装网络工具 / Installing network tools"
install_official 1 nmap
install_aur 1 clash-verge-rev-bin

step "安装日常应用 / Installing daily applications"
install_official 1 obsidian keepassxc thunderbird thunderbird-i18n-zh-cn libreoffice-fresh libreoffice-fresh-zh-cn mpv ffmpeg gimp yazi 7zip dolphin nautilus scrcpy syncthing mpd mpd-mpris rmpc kdenlive cava
install_aur 1 zen-browser-bin ungoogled-chromium-bin localsend-bin bibata-cursor-theme-bin vesktop-bin ayugram-desktop

# 询问是否安装 Podman
if confirm_install "安装 Podman 与 podman-compose？/ Install Podman and podman-compose?" 1; then
	step "安装容器工具 / Installing container tools"
	install_official 1 podman podman-compose podman-docker

	step "配置 Podman 镜像源 / Configuring Podman registry mirror"
	sudo tee /etc/containers/registries.conf.d/10-unqualified-search-registries.conf <<EOF
unqualified-search-registries = ["docker.io"]
EOF

	ok "Podman 安装与配置完成 / Podman installed and configured"
else
	note "跳过 Podman 安装 / Skipping Podman"
fi

# 询问是否安装 LazyVim
if confirm_install "安装 LazyVim Starter？/ Install LazyVim Starter?" 0; then
	step "安装 LazyVim Starter / Installing LazyVim Starter"

	# 询问是否备份现有配置
	if confirm_install "备份现有 Neovim 配置？/ Backup existing Neovim configuration?" 1; then
		step "备份 Neovim 配置 / Backing up Neovim configuration"
		# 必需备份
		mv ~/.config/nvim ~/.config/nvim.bak 2>/dev/null || echo "无现有 nvim 配置可备份 / No existing nvim configuration to backup"

		# 可选但推荐的备份
		mv ~/.local/share/nvim ~/.local/share/nvim.bak 2>/dev/null || echo "无 nvim 共享数据可备份 / No nvim share data to backup"
		mv ~/.local/state/nvim ~/.local/state/nvim.bak 2>/dev/null || echo "无 nvim 状态数据可备份 / No nvim state data to backup"
		mv ~/.cache/nvim ~/.cache/nvim.bak 2>/dev/null || echo "无 nvim 缓存可备份 / No nvim cache to backup"

		ok "Neovim 配置备份完成 / Neovim backup completed"
	fi

	# 克隆 LazyVim starter
	git clone https://github.com/LazyVim/starter ~/.config/nvim

	# 删除 .git 文件夹
	rm -rf ~/.config/nvim/.git

	ok "LazyVim Starter 安装完成 / LazyVim Starter installed"
	echo
	note "提示 / Tip"
	note "1) 运行 nvim 启动 / Run nvim to start"
	note "2) 建议执行 :LazyHealth 检查 / Recommended to run :LazyHealth"
	note "3) 参考注释自定义配置 / See comments to customize"
else
	note "跳过 LazyVim 安装 / Skipping LazyVim"
fi

# 询问是否安装 vfox
if confirm_install "安装 vfox（版本管理工具）？/ Install vfox (version manager)?" 1; then
	step "安装 vfox / Installing vfox"
	curl -sSL https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash
	ok "vfox 安装完成 / vfox installed"
else
	note "跳过 vfox 安装 / Skipping vfox"
fi

# 询问是否启用 MPD 服务
if confirm_install "启用 MPD（音乐播放器守护进程）用户服务？/ Enable MPD user service?" 1; then
	step "启用 MPD 用户服务 / Enabling MPD user service"
	systemctl --user enable --now mpd.service
	systemctl --user enable --now mpd-mpris.service
	ok "MPD 用户服务已启用 / MPD user service enabled"
else
	note "跳过 MPD 服务启用 / Skipping MPD service"
fi

# 询问是否启用 Syncthing 服务
if confirm_install "启用 Syncthing（文件同步）用户服务？/ Enable Syncthing user service?" 1; then
	step "启用 Syncthing 用户服务 / Enabling Syncthing user service"
	systemctl --user enable --now syncthing.service
	ok "Syncthing 用户服务已启用 / Syncthing user service enabled"
	note "访问 http://127.0.0.1:8384 进行配置 / Open http://127.0.0.1:8384 to configure"
else
	note "跳过 Syncthing 服务启用 / Skipping Syncthing service"
fi

# 询问是否启用 Ly 显示管理器
if confirm_install "启用 Ly 显示管理器？/ Enable Ly display manager?" 1; then
	echo -n "选择启动 TTY（如 tty2 或 2）[默认 tty2] / Choose TTY (e.g., tty2 or 2) [default tty2]: "
	read -r ly_tty

	ly_tty=${ly_tty:-tty2}

	# 若仅输入数字则标准化为 ttyN
	if [[ $ly_tty =~ ^[0-9]+$ ]]; then
		ly_tty="tty${ly_tty}"
	fi

	# 校验范围（tty1-tty12），不合法则回退到 tty2
	if [[ ! $ly_tty =~ ^tty([1-9]|1[0-2])$ ]]; then
		warn "无效 TTY，使用默认 tty2 / Invalid TTY, fallback to tty2"
		ly_tty="tty2"
	fi

	step "启用并启动 Ly@${ly_tty} / Enabling and starting Ly@${ly_tty}"
	# 避免与非模板单元冲突
	sudo systemctl disable ly.service >/dev/null 2>&1 || true
	sudo systemctl enable --now "ly@${ly_tty}.service"
	ok "Ly 已在 ${ly_tty} 启动 / Ly started on ${ly_tty}"
else
	note "跳过 Ly 服务启用 / Skipping Ly service"
fi

ok "常用软件安装完成 / Common software installation completed"
