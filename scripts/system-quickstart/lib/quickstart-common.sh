#!/bin/bash

# =============================================================================
# 跨平台 Bash 公共库 / Cross-platform Bash common library
# 供 wsl 与 arch 的 00-common.sh 加载（薄壳）。
# 仅含与发行版无关的日志、确认、包清单函数；平台专用函数留在各平台 00-common.sh。
# =============================================================================

# 防重复加载（绑定当前进程 PID，不 export，确保子进程重新加载全部函数与数组）
[ "${_QS_COMMON_LOADED_PID:-}" = "$$" ] && return 0
_QS_COMMON_LOADED_PID="$$"

# 自动确认模式（仅自动确认默认 Y/n 推荐项，跳过默认 y/N 项）；从环境继承时保留原值
if [ "${QUICKSTART_AUTO_YES:-0}" = "1" ]; then
	AUTO_YES=1
fi
: "${AUTO_YES:=0}"

# Dry-run 归一化：QUICKSTART_DRY_RUN=1 → DRY_RUN=1（并导出给子脚本）
if [ "${QUICKSTART_DRY_RUN:-0}" = "1" ]; then
	DRY_RUN=1
	export DRY_RUN
fi
: "${DRY_RUN:=0}"

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
err() { printf "%s✗ %s%s\n" "$RED" "${1:-}" "$RESET" >&2; }
note() { printf "%s∙ %s%s\n" "$DIM" "${1:-}" "$RESET"; }

# ===== 安装确认 / Install confirmation =====

# 启用自动确认模式（仅自动确认默认 Y/n 推荐项，跳过默认 y/N 项）；已启用时跳过询问
# 不主动 export AUTO_YES，由调用方按需以 AUTO_YES="$run_auto_yes" 传给子脚本
init_auto_yes() {
	if [ "${AUTO_YES:-0}" = "1" ] || [ "${QUICKSTART_AUTO_YES:-0}" = "1" ]; then
		AUTO_YES=1
		note "自动确认模式已启用（仅自动确认默认 Y/n 推荐项）/ Auto-yes mode enabled (default Y/n items only)"
		return 0
	fi
	local choice=""
	if ! read -r -p "是否自动确认所有推荐项（默认 Y/n，跳过 y/N）？[Y/n] / Auto-confirm recommended items (Y/n, skips y/N)? [Y/n]: " choice && [ -z "$choice" ]; then
		AUTO_YES=0
		return 0
	fi
	choice="${choice%$'\r'}"
	case "$choice" in
	"" | [Yy] | [Yy][Ee][Ss]) AUTO_YES=1 ;;
	[Nn] | [Nn][Oo]) AUTO_YES=0 ;;
	*) AUTO_YES=0 ;;
	esac
}

# 询问是否执行操作；返回 0=是，1=否
# 用法: confirm_install <default_yes> <prompt>
#   default_yes: 1 → [Y/n]（回车=是，AUTO_YES=1 自动确认）
#                0 → [y/N]（回车=否，AUTO_YES=1 自动跳过）
confirm_install() {
	local default_yes=${1:-0}
	local prompt=${2:-}
	if [ "${AUTO_YES:-0}" = "1" ]; then
		[ "$default_yes" = "1" ] && return 0
		return 1
	fi
	local answer=""
	if [ "$default_yes" = "1" ]; then
		if ! read -r -p "${prompt} [Y/n]: " answer && [ -z "$answer" ]; then
			return 1
		fi
		answer="${answer%$'\r'}"
		case "$answer" in
		"" | [Yy] | [Yy][Ee][Ss]) return 0 ;;
		[Nn] | [Nn][Oo]) return 1 ;;
		*) return 1 ;;
		esac
	else
		if ! read -r -p "${prompt} [y/N]: " answer && [ -z "$answer" ]; then
			return 1
		fi
		answer="${answer%$'\r'}"
		case "$answer" in
		[Yy] | [Yy][Ee][Ss]) return 0 ;;
		"" | [Nn] | [Nn][Oo]) return 1 ;;
		*) return 1 ;;
		esac
	fi
}

# 读取用户输入；AUTO_YES=1 时立即输出默认值（不调用 read），交互模式空输入/EOF 回退默认值
# 用法: val="$(read_choice <default_val> <prompt>)"
read_choice() {
	local default_val=${1:-}
	local prompt=${2:-}
	if [ "${AUTO_YES:-0}" = "1" ]; then
		printf '%s\n' "$default_val"
		return 0
	fi
	local answer=""
	read -r -p "$prompt" answer || true
	answer="${answer%$'\r'}"
	if [ -z "$answer" ]; then
		printf '%s\n' "$default_val"
	else
		printf '%s\n' "$answer"
	fi
}

# ===== 包清单 / Package list =====

# 读取包清单文件：每行一个包，# 之后为注释，空行忽略；校验包名并去重。
# 用法: read_pkg_list <file>   （结果经 stdout 返回，逐行）
read_pkg_list() {
	local file=${1:-}
	if [ -z "$file" ] || [ ! -f "$file" ] || [ ! -r "$file" ]; then
		err "包清单不存在或不可读 / Package list missing or not readable: $file"
		return 1
	fi
	local line=""
	local out=()
	while IFS= read -r line || [ -n "$line" ]; do
		line="${line%$'\r'}"
		line="${line%%#*}"
		# 仅去除首尾空白，保留内部空白以令非法行（如 "foo bar"）触发正则校验失败
		line="${line#"${line%%[![:space:]]*}"}"
		line="${line%"${line##*[![:space:]]}"}"
		[ -z "$line" ] && continue
		if ! [[ "$line" =~ ^[a-z0-9@][a-z0-9._@+-]*$ ]]; then
			err "非法包名 / Invalid package name: '$line' ($file)"
			return 1
		fi
		out+=("$line")
	done <"$file"
	if [ "${#out[@]}" -eq 0 ]; then
		return 0
	fi
	# 去重并保持首次出现顺序
	printf '%s\n' "${out[@]}" | awk '!seen[$0]++'
}

# ===== Dry-run 与失败汇总 / Dry-run & failure summary =====
QS_FAILURES=()

add_failure() {
	local msg=${1:-}
	local trimmed="$msg"
	trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
	[ -z "$trimmed" ] && return 0
	local existing
	for existing in ${QS_FAILURES[@]+"${QS_FAILURES[@]}"}; do
		[ "$existing" = "$msg" ] && return 0
	done
	QS_FAILURES+=("$msg")
}

get_failure_count() {
	printf '%s\n' "${#QS_FAILURES[@]}"
}

write_failure_summary() {
	if [ "${#QS_FAILURES[@]}" -eq 0 ]; then
		ok "全部完成，无失败项 / All completed with no failures"
		return 0
	fi
	warn "有 ${#QS_FAILURES[@]} 项未成功 / ${#QS_FAILURES[@]} item(s) failed:"
	local f
	for f in "${QS_FAILURES[@]}"; do
		note "$f"
	done
	return 1
}

# 统一执行外部命令并记录（dry-run 时只打印不执行）
qs_run_cmd() {
	if [ "$#" -eq 0 ]; then
		warn "qs_run_cmd: 未提供命令 / no command specified" >&2
		return 0
	fi
	if [ "${DRY_RUN:-0}" = "1" ]; then
		local cmd_str=""
		printf -v cmd_str '%q ' "$@"
		cmd_str="${cmd_str% }"
		note "[dry-run] $cmd_str"
		return 0
	fi
	"$@"
}
