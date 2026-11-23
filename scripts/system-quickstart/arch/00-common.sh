#!/bin/bash

# Arch 公共函数：加载跨平台公共库（scripts/system-quickstart/lib/quickstart-common.sh）+ Arch 专用守护。
# 日志、确认、包清单、失败汇总等通用函数由公共库提供；本文件补充 Arch 平台与服务辅助函数。

_QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/quickstart-common.sh
. "$_QS_DIR/../lib/quickstart-common.sh"

# ===== Arch 环境校验 / Arch environment guards =====

# 检测当前是否为 Arch Linux；返回 0=是，1=否
is_arch() {
	if [ -f /etc/arch-release ] || command -v pacman >/dev/null 2>&1; then
		return 0
	fi
	return 1
}

# 非 Arch Linux 环境退出（DRY_RUN=1 时跳过并提示）
require_arch() {
	local reason=${1:-"该脚本仅支持在 Arch Linux 中使用 / This script only supports Arch Linux"}
	if [ "${DRY_RUN:-0}" = "1" ]; then
		if ! is_arch; then
			note "[dry-run] 当前环境不是 Arch Linux，跳过系统校验 / Not Arch Linux, skipping OS guard"
		fi
		return 0
	fi
	if ! is_arch; then
		err "当前环境不是 Arch Linux / Current environment is not Arch Linux"
		err "$reason"
		exit 1
	fi
}

# 要求以非 root 用户运行且系统已安装 sudo（DRY_RUN=1 时跳过并提示）
require_non_root_with_sudo() {
	if [ "${DRY_RUN:-0}" = "1" ]; then
		if [ "${EUID:-$(id -u)}" -eq 0 ] || ! command -v sudo >/dev/null 2>&1; then
			note "[dry-run] 跳过非 root 与 sudo 校验 / Skipping non-root and sudo guard"
		fi
		return 0
	fi
	if [ "${EUID:-$(id -u)}" -eq 0 ]; then
		err "请勿直接以 root 运行此脚本（AUR 编译与用户服务需要普通用户 + sudo）/ Do not run as root; use a regular user with sudo"
		exit 1
	fi
	if ! command -v sudo >/dev/null 2>&1; then
		err "未检测到 sudo，请先安装并配置 sudo / sudo not found; please install and configure sudo first"
		exit 1
	fi
}

# 检测可用 AUR 助手（优先 paru，其次 yay）；输出名称并返回 0，均无则返回 1
detect_aur_helper() {
	if command -v paru >/dev/null 2>&1; then
		printf '%s\n' "paru"
		return 0
	fi
	if command -v yay >/dev/null 2>&1; then
		printf '%s\n' "yay"
		return 0
	fi
	return 1
}

# 安全启用 systemd --user 服务：用户总线不可用时回退为仅 enable（不带 --now），失败记录 add_failure 不中断
enable_user_service() {
	local service=${1:-}
	[ -n "$service" ] || return 0

	if [ "${DRY_RUN:-0}" = "1" ]; then
		qs_run_cmd systemctl --user enable --now "$service"
		return 0
	fi

	if systemctl --user status >/dev/null 2>&1; then
		if qs_run_cmd systemctl --user enable --now "$service"; then
			return 0
		fi
		warn "启用并启动用户服务失败: $service / Failed to enable and start user service: $service"
		add_failure "systemd --user enable --now $service"
		return 1
	fi

	warn "systemd --user 总线不可用，回退为仅 enable（不立即启动）: $service / User bus unavailable, falling back to enable only"
	if qs_run_cmd systemctl --user enable "$service"; then
		return 0
	fi

	warn "启用用户服务失败: $service / Failed to enable user service: $service"
	add_failure "systemd --user enable $service"
	return 1
}
