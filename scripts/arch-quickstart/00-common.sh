#!/bin/bash

# 统一日志输出样式（供其他脚本加载）
export COMMON_LOADED=1

# 自动确认模式（全选 Y）；从主菜单以环境变量继承时保留原值
: "${AUTO_YES:=0}"

if [ -t 1 ]; then
	RESET=$'\033[0m'
	BOLD=$'\033[1m'
	DIM=$'\033[2m'
	RED=$'\033[31m'
	GREEN=$'\033[32m'
	YELLOW=$'\033[33m'
	BLUE=$'\033[34m'
	CYAN=$'\033[36m'
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
# 用法: confirm_install <default_yes> <prompt>
#   default_yes: 1 → [Y/n]（回车=是）；0 → [y/N]（回车=否）
confirm_install() {
	local default_yes=${1:-0}
	local prompt=${2:-}
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
