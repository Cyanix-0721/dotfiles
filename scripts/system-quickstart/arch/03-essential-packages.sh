#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数
# shellcheck source=00-common.sh
. "$SCRIPT_DIR/00-common.sh"

# 运行环境校验（DRY_RUN=1 时跳过）
require_arch "必备软件包安装仅支持在 Arch Linux 中运行 / Essential packages setup only runs on Arch Linux"
require_non_root_with_sudo

# 自动确认模式（仅自动确认默认 Y/n 推荐项）
init_auto_yes

header "安装常用软件 / Installing Common Software"

# 检测 AUR 助手（支持 paru 与 yay；DRY_RUN=1 时缺省以 paru 占位）
aur_helper="$(detect_aur_helper || true)"
if [ -z "$aur_helper" ]; then
	if [ "${DRY_RUN:-0}" = "1" ]; then
		aur_helper="paru"
		note "[dry-run] 未检测到 paru/yay，演练模式暂以 paru 占位 / No AUR helper found; using paru placeholder in dry-run"
	else
		err "未检测到 paru 或 yay，请先运行系统基础环境配置脚本 / Neither paru nor yay is installed; run foundation setup first"
		exit 1
	fi
else
	note "使用 AUR 助手 / Using AUR helper: $aur_helper"
fi

install_pacman_group() {
	local label="$1"
	shift
	if ! qs_run_cmd sudo pacman -S --needed --noconfirm "$@"; then
		err "${label}安装失败 / Failed to install ${label}"
		add_failure "pacman: ${label}"
		return 1
	fi
	return 0
}

install_aur_group() {
	local label="$1"
	shift
	if ! qs_run_cmd "$aur_helper" -S --needed --noconfirm "$@"; then
		err "${label} (AUR) 安装失败 / Failed to install ${label} (AUR)"
		add_failure "${aur_helper}: ${label}"
		return 1
	fi
	return 0
}

step "安装命令行工具 / Installing command line tools"
install_pacman_group "命令行工具" \
	fzf zoxide ripgrep fd eza bat stow btop fastfetch dex viu less || true

step "安装开发工具 / Installing development tools"
install_pacman_group "开发工具" \
	neovim python-pynvim lazygit gitui github-cli uv ast-grep git-delta fnm poppler resvg imagemagick jq luarocks ruff shellcheck shfmt copyparty || true
install_aur_group "开发工具" visual-studio-code-bin || true

# Node.js：默认安装最新 LTS 并设为 fnm 全局默认（fish 集成由 12-fnm.fish 提供）
# Node.js: install latest LTS and set it as the fnm global default by default
# (fish integration lives in 12-fnm.fish)
if confirm_install 1 "是否安装最新 LTS 版 Node.js？/ Install latest LTS Node.js?"; then
	step "安装 Node.js Latest LTS（fnm）/ Installing Node.js latest LTS (fnm)"
	if [ "${DRY_RUN:-0}" = "1" ]; then
		qs_run_cmd fnm install --lts
		qs_run_cmd fnm default lts-latest
	elif ! command -v fnm >/dev/null 2>&1; then
		err "未检测到 fnm，跳过 Node.js 安装 / fnm not found, skipping Node.js"
		add_failure "Node.js Latest LTS (缺少 fnm)"
	else
		# 同版本已安装时 fnm 返回非零，故用列表结果判断是否安装成功
		# fnm exits non-zero when the same version is already installed; verify via list instead
		qs_run_cmd fnm install --lts || true
		lts_version="$(fnm list 2>/dev/null | awk '/lts-latest/ && !found { if (match($0, /v?[0-9]+\.[0-9]+\.[0-9]+/)) { print substr($0, RSTART, RLENGTH); found=1 } }')"
		if [ -n "$lts_version" ]; then
			ok "最新 LTS 版 Node.js $lts_version 安装完成 / Latest LTS Node.js $lts_version installed"
			# lts-latest 别名随 fnm install --lts 自动指向新版本，比固定版本号更稳；
			# 个别旧环境无法创建别名时退回写具体版本号
			if qs_run_cmd fnm default lts-latest; then
				ok "已将 Node.js $lts_version 设为全局默认 / Node.js $lts_version set as global default"
			elif qs_run_cmd fnm default "$lts_version"; then
				ok "已将 Node.js $lts_version 设为全局默认 / Node.js $lts_version set as global default"
			else
				warn "设置全局默认失败 / Failed to set global default"
				add_failure "fnm 设置全局默认 Node.js"
			fi
		else
			err "最新 LTS 版 Node.js 安装失败 / Latest LTS Node.js installation failed"
			add_failure "Node.js Latest LTS (fnm)"
		fi
	fi
fi

step "安装系统工具 / Installing system tools"
install_pacman_group "系统工具" \
	mako fuzzel ntfs-3g niri ly qt6ct xwayland-satellite playerctl polkit-kde-agent xdg-desktop-portal xdg-desktop-portal-gtk nwg-look cliphist wl-clipboard wl-clip-persist udisks2 || true
install_aur_group "系统工具" systemd-manager-tui || true

step "安装网络工具 / Installing network tools"
install_pacman_group "网络工具" nmap || true
install_aur_group "网络工具" clash-verge-rev-bin || true

step "安装日常应用 / Installing daily applications"
install_pacman_group "日常应用" \
	obsidian keepassxc thunderbird thunderbird-i18n-zh-cn libreoffice-fresh libreoffice-fresh-zh-cn mpv ffmpeg gimp yazi 7zip dolphin nautilus scrcpy syncthing mpd mpd-mpris rmpc kdenlive cava telegram-desktop || true
install_aur_group "日常应用" \
	zen-browser-bin ungoogled-chromium-bin localsend-bin bibata-cursor-theme-bin vesktop-bin || true

# 询问是否安装 Podman
if confirm_install 1 "安装 Podman 与 podman-compose？/ Install Podman and podman-compose?"; then
	step "安装容器工具 / Installing container tools"
	install_pacman_group "容器工具" podman podman-compose podman-docker || true

	step "配置 Podman 镜像源 / Configuring Podman registry mirror"
	if qs_run_cmd sudo mkdir -p /etc/containers/registries.conf.d; then
		if [ "${DRY_RUN:-0}" = "1" ]; then
			note "[dry-run] 写入 /etc/containers/registries.conf.d/10-unqualified-search-registries.conf"
		elif printf 'unqualified-search-registries = ["docker.io"]\n' | sudo tee /etc/containers/registries.conf.d/10-unqualified-search-registries.conf >/dev/null; then
			ok "Podman 安装与配置完成 / Podman installed and configured"
		else
			err "写入 Podman 镜像源配置失败 / Failed to write Podman registry config"
			add_failure "Podman registries.conf.d 配置"
		fi
	else
		err "创建 /etc/containers/registries.conf.d 失败 / Failed to create /etc/containers/registries.conf.d"
		add_failure "Podman registries.conf.d 目录创建"
	fi
else
	note "跳过 Podman 安装 / Skipping Podman"
fi

# 询问是否安装 LazyVim（会备份并覆盖现有 Neovim 配置，默认不自动执行）
if confirm_install 0 "安装 LazyVim Starter？/ Install LazyVim Starter?"; then
	step "安装 LazyVim Starter / Installing LazyVim Starter"

	if confirm_install 1 "备份现有 Neovim 配置？/ Backup existing Neovim configuration?"; then
		step "备份 Neovim 配置 / Backing up Neovim configuration"
		backup_ts="$(date +%Y%m%d%H%M%S)"
		for nvim_dir in \
			"$HOME/.config/nvim" \
			"$HOME/.local/share/nvim" \
			"$HOME/.local/state/nvim" \
			"$HOME/.cache/nvim"; do
			if [ -e "$nvim_dir" ]; then
				if ! qs_run_cmd mv "$nvim_dir" "${nvim_dir}.bak.${backup_ts}"; then
					err "备份目录失败: $nvim_dir / Failed to backup $nvim_dir"
					add_failure "Neovim 配置备份 ($nvim_dir)"
				fi
			else
				note "目录不存在，跳过备份: $nvim_dir / Not found, skipping backup"
			fi
		done
		ok "Neovim 配置备份完成 / Neovim backup completed"
	fi

	if [ "${DRY_RUN:-0}" = "1" ]; then
		qs_run_cmd git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
		qs_run_cmd rm -rf "$HOME/.config/nvim/.git"
	elif [ -e "$HOME/.config/nvim" ]; then
		warn "$HOME/.config/nvim 仍存在，跳过克隆 LazyVim Starter / $HOME/.config/nvim still exists, skipping clone"
		add_failure "LazyVim Starter 克隆（目标目录已存在）"
	else
		if qs_run_cmd git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"; then
			qs_run_cmd rm -rf "$HOME/.config/nvim/.git"
			ok "LazyVim Starter 安装完成 / LazyVim Starter installed"
			echo
			note "提示 / Tip"
			note "1) 运行 nvim 启动 / Run nvim to start"
			note "2) 建议执行 :LazyHealth 检查 / Recommended to run :LazyHealth"
			note "3) 参考注释自定义配置 / See comments to customize"
		else
			err "LazyVim Starter 克隆失败 / Failed to clone LazyVim Starter"
			add_failure "LazyVim Starter 克隆"
		fi
	fi
else
	note "跳过 LazyVim 安装 / Skipping LazyVim"
fi

# 询问是否安装 mise
if confirm_install 1 "安装 mise（版本管理工具）？/ Install mise (version manager)?"; then
	step "安装 mise / Installing mise"
	if install_pacman_group "mise" mise; then
		ok "mise 安装完成 / mise installed"
	fi
else
	note "跳过 mise 安装 / Skipping mise"
fi

# 询问是否启用 MPD 服务
if confirm_install 1 "启用 MPD（音乐播放器守护进程）用户服务？/ Enable MPD user service?"; then
	step "启用 MPD 用户服务 / Enabling MPD user service"
	mpd_ok=1
	enable_user_service mpd.service || mpd_ok=0
	enable_user_service mpd-mpris.service || mpd_ok=0
	if [ "$mpd_ok" -eq 1 ]; then
		ok "MPD 用户服务已启用 / MPD user service enabled"
	fi
else
	note "跳过 MPD 服务启用 / Skipping MPD service"
fi

# 询问是否启用 Syncthing 服务
if confirm_install 1 "启用 Syncthing（文件同步）用户服务？/ Enable Syncthing user service?"; then
	step "启用 Syncthing 用户服务 / Enabling Syncthing user service"
	if enable_user_service syncthing.service; then
		ok "Syncthing 用户服务已启用 / Syncthing user service enabled"
		note "访问 http://127.0.0.1:8384 进行配置 / Open http://127.0.0.1:8384 to configure"
	fi
else
	note "跳过 Syncthing 服务启用 / Skipping Syncthing service"
fi

# 询问是否启用 Ly 显示管理器（修改显示管理器与 TTY，默认不自动执行）
if confirm_install 0 "启用 Ly 显示管理器？/ Enable Ly display manager?"; then
	ly_tty="$(read_choice "tty2" "选择启动 TTY（如 tty2 或 2）[默认 tty2] / Choose TTY (e.g., tty2 or 2) [default tty2]: ")"

	# 若仅输入数字则标准化为 ttyN
	if [[ "$ly_tty" =~ ^[0-9]+$ ]]; then
		ly_tty="tty${ly_tty}"
	fi

	# 校验范围（tty1-tty12），不合法则回退到 tty2
	if [[ ! "$ly_tty" =~ ^tty([1-9]|1[0-2])$ ]]; then
		warn "无效 TTY，使用默认 tty2 / Invalid TTY, fallback to tty2"
		ly_tty="tty2"
	fi

	step "配置 Ly@${ly_tty}（仅 enable，不立即切换当前 TTY）/ Enabling Ly@${ly_tty} (without --now)"
	# 避免与非模板单元冲突
	if [ "${DRY_RUN:-0}" = "1" ]; then
		qs_run_cmd sudo systemctl disable ly.service
	else
		sudo systemctl disable ly.service >/dev/null 2>&1 || true
	fi

	if ! qs_run_cmd sudo systemctl disable "getty@${ly_tty}.service"; then
		warn "禁用 getty@${ly_tty}.service 失败 / Failed to disable getty@${ly_tty}.service"
		add_failure "禁用 getty@${ly_tty}.service"
	fi

	if qs_run_cmd sudo systemctl enable "ly@${ly_tty}.service"; then
		ok "Ly 已在 ${ly_tty} 启用（下次重启后生效）/ Ly enabled on ${ly_tty} (takes effect after reboot)"
	else
		err "启用 ly@${ly_tty}.service 失败 / Failed to enable ly@${ly_tty}.service"
		add_failure "启用 ly@${ly_tty}.service"
	fi
else
	note "跳过 Ly 服务启用 / Skipping Ly service"
fi

write_failure_summary
