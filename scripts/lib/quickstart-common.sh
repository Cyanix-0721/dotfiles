#!/bin/bash

# =============================================================================
# 跨平台 Bash 公共库 / Cross-platform Bash common library
# 供 wsl-quickstart 与 arch-quickstart 的 00-common.sh 加载（薄壳）。
# 仅含与发行版无关的日志、确认、包清单函数；平台专用函数留在各平台 00-common.sh。
# =============================================================================

# 防重复加载
[ -n "${COMMON_LOADED:-}" ] && return 0
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

header() { printf "\n%s%s==> %s%s\n" "$BOLD" "$BLUE" "${1:-}" "$RESET"; }
step() { printf "%s→ %s…%s\n" "$CYAN" "${1:-}" "$RESET"; }
ok() { printf "%s✓ %s%s\n" "$GREEN" "${1:-}" "$RESET"; }
warn() { printf "%s⚠ %s%s\n" "$YELLOW" "${1:-}" "$RESET"; }
err() { printf "%s✗ %s%s\n" "$RED" "${1:-}" "$RESET"; }
note() { printf "%s∙ %s%s\n" "$DIM" "${1:-}" "$RESET"; }

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

# ===== 包清单 / Package list =====

# 读取包清单文件：每行一个包，# 之后为注释，空行忽略；校验包名并去重。
# 用法: read_pkg_list <file>   （结果经 stdout 返回，逐行）
read_pkg_list() {
	local file=${1:-}
	if [ ! -r "$file" ]; then
		err "包清单不可读 / Package list not readable: $file" >&2
		return 1
	fi
	local line
	local out=()
	while IFS= read -r line || [ -n "$line" ]; do
		line="${line%%#*}"
		line="${line//[[:space:]]/}"
		[ -z "$line" ] && continue
		if ! [[ "$line" =~ ^[a-z0-9][a-z0-9.+-]*$ ]]; then
			err "非法包名 / Invalid package name: '$line' ($file)" >&2
			return 1
		fi
		out+=("$line")
	done <"$file"
	# 去重并保持首次出现顺序
	printf '%s\n' "${out[@]}" | awk '!seen[$0]++'
}

# ===== Dry-run 与失败汇总 / Dry-run & failure summary =====
: "${DRY_RUN:=0}"
QS_FAILURES=()

add_failure() { QS_FAILURES+=("${1:-}"); }

write_failure_summary() {
	if [ "${#QS_FAILURES[@]}" -eq 0 ]; then
		ok "全部完成，无失败项 / All completed with no failures"
	else
		warn "有 ${#QS_FAILURES[@]} 项未成功 / ${#QS_FAILURES[@]} item(s) failed:"
		local f
		for f in ${QS_FAILURES[@]+"${QS_FAILURES[@]}"}; do
			note "$f"
		done
	fi
}

# 统一执行外部命令并记录（dry-run 时只打印不执行）
qs_run_cmd() {
	if [ "$DRY_RUN" = "1" ]; then
		note "[dry-run] $*"
		return 0
	fi
	"$@"
}