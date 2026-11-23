#!/bin/bash

# WSL 公共函数：加载跨平台公共库（scripts/system-quickstart/lib/quickstart-common.sh）+ WSL 专用函数。
# 日志、确认、包清单等通用函数在公共库中定义；本文件只补 WSL 检测与参数解析相关。

_QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/quickstart-common.sh
. "$_QS_DIR/../lib/quickstart-common.sh"

# ===== 通用 CLI 参数解析 / Common CLI flag parsing =====

# 支持 --dry-run、--auto-yes、-h/--help；由各 WSL 脚本入口调用
parse_wsl_args() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--dry-run)
			DRY_RUN=1
			export DRY_RUN
			;;
		--auto-yes)
			# shellcheck disable=SC2034 # 由调用脚本与 quickstart-common.sh 读取，不主动 export
			AUTO_YES=1
			;;
		-h | --help)
			printf 'Usage: %s [--dry-run] [--auto-yes]\n' "$(basename "$0")"
			printf '  --dry-run   只打印不执行 / Print mutating commands without executing (same as QUICKSTART_DRY_RUN=1)\n'
			printf '  --auto-yes  自动确认默认 Y/n 推荐项，跳过 y/N 项 / Auto-confirm Y/n items, skip y/N (same as AUTO_YES=1)\n'
			exit 0
			;;
		*)
			err "未知参数 / Unknown option: $1"
			return 2
			;;
		esac
		shift
	done
}

# ===== WSL 检测 / WSL detection =====

# 检测当前是否运行在 WSL 中；返回 0=是，1=否
is_wsl() {
	if [ -n "${WSL_DISTRO_NAME:-}" ]; then
		return 0
	fi
	if grep -qi microsoft /proc/version 2>/dev/null; then
		return 0
	fi
	return 1
}

# 非 WSL 环境退出；可传入自定义退出提示
require_wsl() {
	local reason=${1:-"该脚本仅支持在 WSL 中使用 / This script only supports WSL"}
	if ! is_wsl; then
		err "当前环境不是 WSL / Current environment is not WSL"
		err "$reason"
		exit 1
	fi
}

# 解析 WSL 侧可用的 powershell.exe（优先 interop PATH，回退系统默认位置，兼容 appendWindowsPath=false）
# Resolve WSL-side powershell.exe (prefer interop PATH, fall back to default system path)
resolve_powershell_exe() {
	local ps_exe=""
	ps_exe="$(command -v powershell.exe 2>/dev/null || true)"
	if [ -n "$ps_exe" ]; then
		printf '%s\n' "$ps_exe"
		return 0
	fi
	local default_ps="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
	if [ -x "$default_ps" ]; then
		printf '%s\n' "$default_ps"
		return 0
	fi
	return 1
}

# 获取 Windows 用户目录（WSL 路径，如 /mnt/c/Users/Administrator）；失败返回非 0
# 强制 PowerShell 以 UTF-8 输出，避免中文/非 ASCII 用户名在 GBK/CP936 代码页下乱码
get_win_user_home() {
	local ps_exe="" win_profile="" win_home=""
	ps_exe="$(resolve_powershell_exe)" || return 1
	# shellcheck disable=SC2016
	win_profile="$("$ps_exe" -NoProfile -NonInteractive -Command \
		'[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); $p = if ($env:USERPROFILE) { $env:USERPROFILE } else { [Environment]::GetFolderPath("UserProfile") }; [Console]::WriteLine($p)' \
		2>/dev/null | tr -d '\r\n')" || return 1
	[ -z "$win_profile" ] && return 1
	if command -v wslpath >/dev/null 2>&1; then
		win_home="$(wslpath -u "$win_profile" 2>/dev/null || true)"
	fi
	if [ -z "$win_home" ]; then
		win_home="${win_profile//\\//}"
		if [[ "$win_home" =~ ^([A-Za-z]): ]]; then
			win_home="/mnt/${BASH_REMATCH[1],,}${win_home:2}"
		fi
	fi
	[ -n "$win_home" ] || return 1
	printf '%s' "$win_home"
}
