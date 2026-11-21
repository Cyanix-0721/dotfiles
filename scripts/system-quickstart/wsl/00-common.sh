#!/bin/bash

# WSL 公共函数：加载跨平台公共库（scripts/system-quickstart/lib/quickstart-common.sh）+ WSL 专用函数。
# 日志、确认、包清单等通用函数在公共库中定义；本文件只补 WSL 检测相关。

_QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/quickstart-common.sh
. "$_QS_DIR/../lib/quickstart-common.sh"

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

# 获取 Windows 用户目录（WSL 路径，如 /mnt/c/Users/Administrator）；失败返回非 0
get_win_user_home() {
	local win_profile win_home
	win_profile=$(powershell.exe -NoProfile -NonInteractive -Command \
		"[Environment]::GetFolderPath('UserProfile')" 2>/dev/null | tr -d '\r\n') || return 1
	[ -z "$win_profile" ] && return 1
	if command -v wslpath >/dev/null 2>&1; then
		win_home=$(wslpath -u "$win_profile" 2>/dev/null) || return 1
	else
		win_home="${win_profile//\\//}"
		if [[ "$win_home" =~ ^([A-Za-z]): ]]; then
			win_home="/mnt/${BASH_REMATCH[1],,}${win_home:2}"
		fi
	fi
	printf '%s' "$win_home"
}
