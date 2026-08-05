#!/bin/bash

# 统一日志输出样式（供其他脚本加载）
export COMMON_LOADED=1

# 自动确认模式（全选 Y）；从主菜单以环境变量继承时保留原值
: "${AUTO_YES:=0}"

if [ -t 1 ]; then
	RESET="\033[0m"
	BOLD="\033[1m"
	DIM="\033[2m"
	RED="\033[31m"
	GREEN="\033[32m"
	YELLOW="\033[33m"
	BLUE="\033[34m"
	CYAN="\033[36m"
else
	RESET=""
	BOLD=""
	DIM=""
	RED=""
	GREEN=""
	YELLOW=""
	BLUE=""
	CYAN=""
fi

header() { printf "\n%s%s==> %s%s\n" "$BOLD" "$BLUE" "$1" "$RESET"; }
step() { printf "%s→ %s…%s\n" "$CYAN" "$1" "$RESET"; }
ok() { printf "%s✓ %s%s\n" "$GREEN" "$1" "$RESET"; }
warn() { printf "%s⚠ %s%s\n" "$YELLOW" "$1" "$RESET"; }
err() { printf "%s✗ %s%s\n" "$RED" "$1" "$RESET"; }
note() { printf "%s∙ %s%s\n" "$DIM" "$1" "$RESET"; }

# ===== 安装确认 / Install confirmation =====

# 启用自动确认模式；已启用（AUTO_YES=1）时跳过询问
init_auto_yes() {
	if [ "$AUTO_YES" = "1" ]; then
		note "自动确认模式已启用 / Auto-yes mode enabled"
		return 0
	fi
	local choice
	if ! read -r -p "是否全选 Y（自动确认所有安装）？(y/N) / Select all Y (auto-confirm all installations)? (y/N): " choice; then
		return 0
	fi
	case "$choice" in
	[Yy]*) AUTO_YES=1 ;;
	esac
}

# 询问是否执行操作；返回 0=是，1=否
# default_yes: 1 → [Y/n]（回车=是）；0 → [y/N]（回车=否）
confirm_install() {
	local prompt=$1
	local default_yes=${2:-0}
	if [ "$AUTO_YES" = "1" ]; then
		return 0
	fi
	local answer
	if [ "$default_yes" = "1" ]; then
		read -r -p "${prompt} [Y/n]: " answer || return 1
		case "$answer" in
		[Nn]*) return 1 ;;
		*) return 0 ;;
		esac
	else
		read -r -p "${prompt} [y/N]: " answer || return 1
		case "$answer" in
		[Yy]*) return 0 ;;
		*) return 1 ;;
		esac
	fi
}

# ===== 软件包安装 / Package installation =====

# 判断软件包是否已安装（官方仓库 + AUR 均可检测）
pkg_installed() {
	local pkg=$1
	pacman -Q "$pkg" &>/dev/null
}

# 批量安装官方仓库软件包（跳过已安装，按组确认）
# 用法: install_official <default_yes> <pkg...>
install_official() {
	local default_yes=${1:-0}
	shift
	[ $# -eq 0 ] && return 0

	local -a missing=()
	local pkg
	for pkg in "$@"; do
		if pkg_installed "$pkg"; then
			ok "$pkg 已安装 / $pkg already installed"
		else
			missing+=("$pkg")
		fi
	done
	[ ${#missing[@]} -eq 0 ] && return 0

	step "安装软件包: ${missing[*]} / Installing: ${missing[*]}"
	if confirm_install "确认安装以上软件包？/ Confirm installation?" "$default_yes"; then
		sudo pacman -S --needed --noconfirm "${missing[@]}"
		ok "安装完成 / Installation completed"
	else
		note "跳过安装 / Skipping installation"
	fi
}

# 批量安装 AUR 软件包（优先 paru，回退 yay；跳过已安装）
# 用法: install_aur <default_yes> <pkg...>
install_aur() {
	local default_yes=${1:-0}
	shift
	[ $# -eq 0 ] && return 0

	local -a missing=()
	local pkg
	for pkg in "$@"; do
		if pkg_installed "$pkg"; then
			ok "$pkg 已安装 / $pkg already installed"
		else
			missing+=("$pkg")
		fi
	done
	[ ${#missing[@]} -eq 0 ] && return 0

	step "安装 AUR 软件包: ${missing[*]} / Installing AUR: ${missing[*]}"
	if ! confirm_install "确认安装以上 AUR 软件包？/ Confirm AUR installation?" "$default_yes"; then
		note "跳过安装 / Skipping installation"
		return 0
	fi

	if command -v paru &>/dev/null; then
		paru -S --noconfirm "${missing[@]}"
	elif command -v yay &>/dev/null; then
		yay -S --noconfirm "${missing[@]}"
	else
		err "未找到 AUR 助手（paru/yay）/ No AUR helper (paru/yay) found"
		return 1
	fi
	ok "安装完成 / Installation completed"
}
