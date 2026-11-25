#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数
# shellcheck source=00-common.sh
. "$SCRIPT_DIR/00-common.sh"

# 运行环境校验（DRY_RUN=1 时跳过）
require_arch "系统基础环境配置仅支持在 Arch Linux 中运行 / System foundation setup only runs on Arch Linux"
require_non_root_with_sudo

# 自动确认模式（仅自动确认默认 Y/n 推荐项）
init_auto_yes

header "系统基础环境配置 / System Foundation Setup"

# 安装 AUR 助手（在独立子 shell 中编译，退出自动清理临时目录且不污染调用者 cwd）
install_aur_helper() {
	local pkg="$1"
	if command -v "$pkg" &>/dev/null; then
		ok "$pkg 已安装，跳过 / $pkg already installed, skipping"
		return 0
	fi
	if [ "${DRY_RUN:-0}" = "1" ]; then
		note "[dry-run] 克隆并编译安装 AUR 助手: $pkg (https://aur.archlinux.org/${pkg}.git)"
		return 0
	fi
	if (
		set -euo pipefail
		temp_dir=""
		trap '[ -n "${temp_dir:-}" ] && rm -rf "$temp_dir"' EXIT
		temp_dir="$(mktemp -d)"
		cd "$temp_dir"
		git clone "https://aur.archlinux.org/${pkg}.git"
		cd "$pkg"
		makepkg -si --noconfirm
	); then
		ok "$pkg 安装成功 / $pkg installed"
		return 0
	else
		err "$pkg 安装失败 / Failed to install $pkg"
		add_failure "AUR 助手安装 ($pkg)"
		return 1
	fi
}

# 检查网络连接 / Check network connection
step "检查网络连接 / Checking network connection"
if [ "${DRY_RUN:-0}" = "1" ]; then
	note "[dry-run] 跳过网络连接检查 / Skipping network connectivity check"
else
	if ! curl -fsI --connect-timeout 5 https://archlinux.org >/dev/null 2>&1; then
		err "无法连接到 https://archlinux.org，请检查网络连接 / Cannot reach https://archlinux.org, please check connection"
		exit 1
	fi
	ok "网络连接正常 / Network connection OK"
fi

# 更新系统 / Update system
step "更新系统 / Updating system"
if qs_run_cmd sudo pacman -Syu --noconfirm; then
	ok "系统更新完成 / System update completed"
else
	err "系统更新失败 / System update failed"
	add_failure "系统更新 (pacman -Syu)"
fi

# 安装基础工具 / Install basic tools
step "安装基础工具 / Installing basic tools"
if qs_run_cmd sudo pacman -S --needed --noconfirm git subversion base-devel; then
	ok "基础工具安装完成 / Basic tools installed"
else
	err "基础工具安装失败 / Failed to install basic tools"
	add_failure "基础工具 (git subversion base-devel)"
fi

# 安装终端模拟器 / Install terminal emulator
header "终端模拟器 / Terminal Emulator"
echo "选择终端模拟器 / Select terminal emulator:"
echo "  1) kitty (默认/default)"
echo "  2) alacritty"
echo "  3) 全部安装 / Install all"
terminal_choice="$(read_choice "1" "输入选择 (1-3) [1]: ")"

term_packages=()
case "$terminal_choice" in
2) term_packages=(alacritty) ;;
3) term_packages=(kitty alacritty) ;;
*) term_packages=(kitty) ;;
esac

if [ "${#term_packages[@]}" -gt 0 ]; then
	step "安装终端模拟器: ${term_packages[*]} / Installing: ${term_packages[*]}"
	if qs_run_cmd sudo pacman -S --needed --noconfirm "${term_packages[@]}"; then
		ok "终端模拟器安装完成 / Terminal emulator installed"
	else
		err "终端模拟器安装失败 / Failed to install terminal emulator"
		add_failure "终端模拟器 (${term_packages[*]})"
	fi
fi

# 安装 Shell / Install Shell
header "Shell"
echo "选择 Shell / Select shell:"
echo "  1) fish (默认/default)"
echo "  2) zsh"
echo "  3) 全部安装 / Install all"
shell_choice="$(read_choice "1" "输入选择 (1-3) [1]: ")"

shell_packages=()
case "$shell_choice" in
2) shell_packages=(zsh) ;;
3) shell_packages=(fish zsh) ;;
*) shell_packages=(fish) ;;
esac

if [ "${#shell_packages[@]}" -gt 0 ]; then
	step "安装 Shell: ${shell_packages[*]} / Installing: ${shell_packages[*]}"
	if qs_run_cmd sudo pacman -S --needed --noconfirm "${shell_packages[@]}"; then
		ok "Shell 安装完成 / Shell installed"
	else
		err "Shell 安装失败 / Failed to install shell"
		add_failure "Shell (${shell_packages[*]})"
	fi
fi

# 安装 pacman 工具 / Install pacman tools
step "安装 pacman-contrib 与 reflector / Installing pacman-contrib and reflector"
if qs_run_cmd sudo pacman -S --needed --noconfirm pacman-contrib reflector; then
	ok "pacman-contrib 与 reflector 安装完成 / Installed"
else
	err "pacman-contrib 与 reflector 安装失败 / Failed to install pacman-contrib and reflector"
	add_failure "pacman-contrib 与 reflector"
fi

# 配置 reflector 服务和定时器 / Configure reflector service and timer
if confirm_install 0 "配置 reflector 服务与定时器？/ Configure reflector service and timer?"; then
	step "配置 reflector 服务与定时器 / Configuring reflector"

	REFLECTOR_SCRIPT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/reflector"
	if [[ -f "$REFLECTOR_SCRIPT_DIR/setup_reflector.sh" ]]; then
		step "运行 reflector 安装脚本 / Running reflector setup script"
		if qs_run_cmd sudo "$REFLECTOR_SCRIPT_DIR/setup_reflector.sh" --setup; then
			ok "reflector 服务与定时器已配置 / Reflector configured"
		else
			err "reflector 配置失败 / Reflector setup failed"
			add_failure "reflector 配置"
		fi
	else
		warn "未找到 reflector 安装脚本: $REFLECTOR_SCRIPT_DIR/setup_reflector.sh"
		add_failure "缺少 reflector 安装脚本"
		note "跳过 reflector 配置 / Skipping reflector configuration"
	fi
else
	note "跳过 reflector 服务配置 / Skipping reflector configuration"
fi

# 配置 ArchlinuxCN 仓库 / Configure ArchlinuxCN Repository
if confirm_install 0 "配置 ArchlinuxCN 仓库？/ Configure ArchlinuxCN repository?"; then
	header "配置 ArchlinuxCN 仓库 / Configuring ArchlinuxCN repository"

	if [ "${DRY_RUN:-0}" = "1" ]; then
		note "[dry-run] 检查并按需向 /etc/pacman.conf 追加 [archlinuxcn] 仓库"
		qs_run_cmd sudo pacman-key --lsign-key "farseerfc@archlinux.org"
		qs_run_cmd sudo pacman -Syu --needed --noconfirm archlinuxcn-keyring
	else
		archlinuxcn_ok=1
		if ! sudo grep -Eq '^[[:space:]]*\[archlinuxcn\][[:space:]]*$' /etc/pacman.conf; then
			step "添加仓库到 pacman.conf / Adding repository to pacman.conf"
			# pacman.conf 需要字面量 $arch 占位符
			# shellcheck disable=SC2016
			if ! printf '\n[archlinuxcn]\nServer = https://repo.archlinuxcn.org/$arch\n' | sudo tee -a /etc/pacman.conf >/dev/null; then
				err "写入 /etc/pacman.conf 失败 / Failed to update /etc/pacman.conf"
				add_failure "ArchlinuxCN 写入 pacman.conf"
				archlinuxcn_ok=0
			fi
		else
			ok "ArchlinuxCN 仓库项已存在于 /etc/pacman.conf / Repository entry already present"
		fi

		# 密钥签收与 keyring 安装与仓库条目解耦，便于中途失败后幂等恢复（且禁止部分更新 pacman -Sy）
		if [ "$archlinuxcn_ok" -eq 1 ]; then
			step "导入并签收 ArchlinuxCN GPG 密钥 / Signing ArchlinuxCN GPG key"
			if ! qs_run_cmd sudo pacman-key --lsign-key "farseerfc@archlinux.org"; then
				err "签收 ArchlinuxCN GPG 密钥失败 / Failed to lsign ArchlinuxCN GPG key"
				add_failure "ArchlinuxCN GPG 密钥签收"
				archlinuxcn_ok=0
			fi
		fi

		if [ "$archlinuxcn_ok" -eq 1 ]; then
			step "同步仓库并安装 archlinuxcn-keyring / Syncing and installing archlinuxcn-keyring"
			if qs_run_cmd sudo pacman -Syu --needed --noconfirm archlinuxcn-keyring; then
				ok "ArchlinuxCN 仓库配置成功 / Repository configured"
			else
				err "安装 archlinuxcn-keyring 失败 / Failed to install archlinuxcn-keyring"
				add_failure "archlinuxcn-keyring 安装"
			fi
		fi
	fi
else
	note "跳过 ArchlinuxCN 仓库配置 / Skipping ArchlinuxCN configuration"
fi

# 安装 paru / Install paru
step "安装 paru / Installing paru"
install_aur_helper paru || true

# 可选：安装 yay / Optional: install yay
if confirm_install 0 "安装 yay 作为备用 AUR 助手？/ Install yay as alternative AUR helper?"; then
	step "安装 yay / Installing yay"
	install_aur_helper yay || true
fi

# 安装 Flatpak / Install Flatpak
if confirm_install 1 "安装 Flatpak？/ Install Flatpak?"; then
	header "安装 Flatpak / Installing Flatpak"
	step "安装 Flatpak / Installing Flatpak"
	if qs_run_cmd sudo pacman -S --needed --noconfirm flatpak; then
		ok "Flatpak 安装完成 / Flatpak installed"
	else
		err "Flatpak 安装失败 / Failed to install Flatpak"
		add_failure "Flatpak 安装"
	fi
else
	note "跳过 Flatpak 安装 / Skipping Flatpak"
fi

# 检查并配置 OpenSSH 和 ssh-agent
header "配置 SSH Agent / Configuring SSH Agent"

if ! command -v ssh &>/dev/null; then
	step "安装 OpenSSH / Installing OpenSSH"
	if qs_run_cmd sudo pacman -S --needed --noconfirm openssh; then
		ok "OpenSSH 安装完成 / OpenSSH installed"
	else
		err "OpenSSH 安装失败 / Failed to install OpenSSH"
		add_failure "OpenSSH 安装"
	fi
else
	ok "OpenSSH 已安装 / OpenSSH already installed"
fi

# 启用 ssh-agent 用户服务
step "启用 ssh-agent 用户服务 / Enabling ssh-agent user service"
if enable_user_service ssh-agent.service; then
	ok "ssh-agent 用户服务已启用 / ssh-agent service enabled"
fi

# 提示用户配置环境变量
echo
note "提示 / Note"
note "SSH Agent 环境变量 / SSH Agent environment variable:"
note "  Fish: set -Ux SSH_AUTH_SOCK \"\$XDG_RUNTIME_DIR/ssh-agent.socket\""
note "  Bash: export SSH_AUTH_SOCK=\"\$XDG_RUNTIME_DIR/ssh-agent.socket\""
note "  Zsh:  export SSH_AUTH_SOCK=\"\$XDG_RUNTIME_DIR/ssh-agent.socket\""
echo

# rEFInd 引导管理器
header "rEFInd 引导管理器 / rEFInd Boot Manager"

refind_available=false
if command -v refind-install &>/dev/null; then
	ok "rEFInd 已安装 / rEFInd is already installed"
	refind_available=true
elif confirm_install 1 "安装 rEFInd 引导管理器？/ Install rEFInd boot manager?"; then
	step "安装 rEFInd / Installing rEFInd"
	if qs_run_cmd sudo pacman -S --needed --noconfirm refind; then
		if [ "${DRY_RUN:-0}" = "1" ] || command -v refind-install &>/dev/null; then
			ok "rEFInd 安装完成 / rEFInd installation completed"
			refind_available=true
		else
			err "rEFInd 安装后未检测到 refind-install / refind-install not found after install"
			add_failure "rEFInd 安装"
		fi
	else
		err "rEFInd 安装失败 / rEFInd installation failed"
		add_failure "rEFInd 安装"
	fi
else
	note "跳过 rEFInd 安装 / Skipping rEFInd"
fi

# 询问是否运行 refind-install（修改 EFI 分区，默认不自动执行）
if [[ "$refind_available" == "true" ]]; then
	if confirm_install 0 "运行 refind-install 安装到 EFI 分区？/ Run refind-install to install to EFI partition?"; then
		step "安装 rEFInd 到 EFI 分区 / Installing to EFI partition"
		if qs_run_cmd sudo refind-install; then
			ok "rEFInd 已安装到 EFI 分区 / Installed to EFI partition"
		else
			err "refind-install 执行失败 / refind-install failed"
			add_failure "refind-install"
		fi
	else
		note "跳过 refind-install / Skipping refind-install"
	fi
fi

# 安装 rEFInd 主题（修改 EFI 分区配置，默认不自动执行）
if [[ "$refind_available" == "true" ]]; then
	header "rEFInd 主题安装 / rEFInd Theme Installation"
	if confirm_install 0 "安装 Catppuccin 主题？/ Install Catppuccin theme?"; then
		if [ "${DRY_RUN:-0}" = "1" ]; then
			note "[dry-run] 查找 rEFInd 目录、克隆/更新 Catppuccin 主题并写入 refind.conf"
		else
			# 查找 rEFInd 目录（使用 sudo 兼容 0700 挂载的 ESP）
			REFIND_DIR=""
			for candidate in /boot/EFI/refind /efi/EFI/refind; do
				if sudo test -d "$candidate"; then
					REFIND_DIR="$candidate"
					step "找到 rEFInd 目录 (路径: $REFIND_DIR) / Found rEFInd directory"
					break
				fi
			done

			if [[ -z "$REFIND_DIR" ]]; then
				step "在 /boot 与 /efi 下搜索 rEFInd 目录 / Searching in /boot and /efi"
				search_roots=()
				for root_dir in /boot /efi; do
					if sudo test -d "$root_dir" 2>/dev/null; then
						search_roots+=("$root_dir")
					fi
				done
				REFIND_SEARCH=""
				if [ "${#search_roots[@]}" -gt 0 ]; then
					REFIND_SEARCH="$(sudo find "${search_roots[@]}" -type d -name "refind" 2>/dev/null | awk '!found { print; found=1 }' || true)"
				fi
				if [[ -n "$REFIND_SEARCH" ]] && sudo test -d "$REFIND_SEARCH"; then
					REFIND_DIR="$REFIND_SEARCH"
					step "找到 rEFInd 目录 (路径: $REFIND_DIR) / Found rEFInd directory"
				else
					err "未找到 rEFInd 目录，跳过主题安装 / rEFInd directory not found, skipping"
					add_failure "rEFInd 主题安装（未找到 rEFInd 目录）"
				fi
			fi

			if [[ -n "$REFIND_DIR" ]]; then
				THEMES_DIR="$REFIND_DIR/themes"
				THEME_REPO="$THEMES_DIR/catppuccin"
				step "创建主题目录 (目标: $THEMES_DIR) / Creating theme directory"
				if ! qs_run_cmd sudo mkdir -p "$THEMES_DIR"; then
					err "创建主题目录失败 / Failed to create theme directory"
					add_failure "rEFInd 主题目录创建"
				elif ! command -v git &>/dev/null; then
					err "git 未安装，无法克隆主题 / git not installed, cannot clone theme"
					add_failure "rEFInd 主题安装（缺少 git）"
				else
					theme_sync_ok=1
					if sudo test -d "$THEME_REPO/.git"; then
						step "更新 Catppuccin 主题仓库 / Updating Catppuccin theme repository"
						if ! qs_run_cmd sudo git -C "$THEME_REPO" pull --ff-only; then
							err "更新 Catppuccin 主题失败 / Failed to update Catppuccin theme"
							add_failure "rEFInd Catppuccin 主题更新"
							theme_sync_ok=0
						fi
					else
						step "克隆 Catppuccin 主题 / Cloning Catppuccin"
						if ! qs_run_cmd sudo git clone https://github.com/catppuccin/refind.git "$THEME_REPO"; then
							err "克隆 Catppuccin 主题失败 / Failed to clone Catppuccin theme"
							add_failure "rEFInd Catppuccin 主题克隆"
							theme_sync_ok=0
						fi
					fi

					if [ "$theme_sync_ok" -eq 1 ]; then
						echo "请选择主题口味 / Select theme flavor:"
						echo "  1) latte"
						echo "  2) frappe"
						echo "  3) macchiato"
						echo "  4) mocha (默认/default)"
						flavor_choice="$(read_choice "4" "输入选择 (1-4) [4]: ")"

						case "$flavor_choice" in
						1) FLAVOR="latte" ;;
						2) FLAVOR="frappe" ;;
						3) FLAVOR="macchiato" ;;
						*) FLAVOR="mocha" ;;
						esac

						note "选择: $FLAVOR / Selected: $FLAVOR"

						THEME_CONF="$THEME_REPO/${FLAVOR}.conf"
						if sudo test -f "$THEME_CONF"; then
							REFIND_CONF="$REFIND_DIR/refind.conf"
							if sudo test -f "$REFIND_CONF" && ! sudo test -f "$REFIND_CONF.bak"; then
								qs_run_cmd sudo cp "$REFIND_CONF" "$REFIND_CONF.bak"
								note "已备份原配置: $REFIND_CONF.bak / Backed up original: $REFIND_CONF.bak"
							fi

							step "向 refind.conf 写入主题配置 / Writing theme include to refind.conf"
							INCLUDE_LINE="include themes/catppuccin/${FLAVOR}.conf"

							if sudo grep -Eq '^[[:space:]]*include[[:space:]]+themes/catppuccin/[^[:space:]]+\.conf[[:space:]]*$' "$REFIND_CONF" 2>/dev/null; then
								if sudo grep -Fxq "$INCLUDE_LINE" "$REFIND_CONF" 2>/dev/null; then
									ok "主题配置已存在 ($FLAVOR) / Theme configuration already set ($FLAVOR)"
								elif qs_run_cmd sudo sed -Ei "s|^[[:space:]]*include[[:space:]]+themes/catppuccin/[^[:space:]]+\.conf[[:space:]]*$|${INCLUDE_LINE}|" "$REFIND_CONF"; then
									ok "已更新 rEFInd 主题为 $FLAVOR / Updated rEFInd theme to $FLAVOR"
								else
									err "更新 refind.conf 失败 / Failed to update refind.conf"
									add_failure "rEFInd refind.conf 更新"
								fi
							else
								if printf '%s\n' "$INCLUDE_LINE" | sudo tee -a "$REFIND_CONF" >/dev/null; then
									ok "主题配置已添加 / Theme configuration added"
								else
									err "写入 refind.conf 失败 / Failed to append to refind.conf"
									add_failure "rEFInd refind.conf 写入"
								fi
							fi
						else
							err "主题配置文件不存在: $THEME_CONF / Theme config file not found"
							add_failure "rEFInd 主题配置文件缺失 ($FLAVOR)"
						fi
					fi
				fi
			fi
		fi
	else
		note "跳过 rEFInd 主题安装 / Skipping theme installation"
	fi
fi

# 备份工具
header "备份工具 / Backup Tools"
if confirm_install 1 "安装备份工具？/ Install backup tools?"; then
	step "安装备份工具 / Installing backup tools"
	if qs_run_cmd sudo pacman -S --needed --noconfirm snapper btrfs-assistant snap-pac; then
		ok "备份工具安装完成 / Backup tools installed"
	else
		err "备份工具安装失败 / Failed to install backup tools"
		add_failure "备份工具 (snapper btrfs-assistant snap-pac)"
	fi
else
	note "跳过备份工具安装 / Skipping backup tools"
fi

# Chezmoi 配置管理工具
header "Chezmoi 配置管理工具 / Chezmoi Configuration Management Tool"

chezmoi_available=false
if command -v chezmoi &>/dev/null; then
	ok "Chezmoi 已安装 / Chezmoi already installed"
	chezmoi_available=true
elif confirm_install 1 "安装 Chezmoi？/ Install Chezmoi?"; then
	step "安装 Chezmoi / Installing Chezmoi"
	if qs_run_cmd sudo pacman -S --needed --noconfirm chezmoi; then
		if [ "${DRY_RUN:-0}" = "1" ] || command -v chezmoi &>/dev/null; then
			ok "Chezmoi 安装完成 / Chezmoi installed"
			chezmoi_available=true
		else
			err "Chezmoi 安装后未检测到命令 / chezmoi not found after install"
			add_failure "Chezmoi 安装"
		fi
	else
		err "Chezmoi 安装失败 / Chezmoi installation failed"
		add_failure "Chezmoi 安装"
	fi
else
	note "跳过 Chezmoi 安装 / Skipping Chezmoi"
fi

# 询问是否初始化 dotfiles（交互式模板提示会阻塞非交互运行，默认不自动执行）
if [[ "$chezmoi_available" == "true" ]]; then
	if confirm_install 0 "初始化 dotfiles 配置（交互式输入）？/ Initialize dotfiles configuration (interactive)?"; then
		step "初始化 dotfiles 配置 / Initializing dotfiles"
		if qs_run_cmd chezmoi init https://github.com/Cyanix-0721/dotfiles.git -a; then
			ok "dotfiles 配置初始化完成 / dotfiles initialized"
		else
			err "dotfiles 初始化失败 / Failed to initialize dotfiles"
			add_failure "chezmoi init"
		fi
	else
		note "跳过 dotfiles 初始化 / Skipping dotfiles init"
	fi
fi

write_failure_summary
