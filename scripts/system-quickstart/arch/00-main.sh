#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数（含 QUICKSTART_DRY_RUN / QUICKSTART_AUTO_YES 归一化）
# shellcheck source=00-common.sh
. "$SCRIPT_DIR/00-common.sh"

usage() {
	cat <<EOF
用法 / Usage: $(basename "$0") [选项 / options]

选项 / Options:
  --dry-run   演练模式：只打印将要执行的变更，不修改系统 / Print mutations without executing
  --auto-yes  自动确认默认 Y/n 推荐项（跳过 y/N 项）/ Auto-confirm default Y/n items (skips y/N)
  -h, --help  显示此帮助 / Show this help
EOF
}

while [ "$#" -gt 0 ]; do
	case "$1" in
	--dry-run)
		DRY_RUN=1
		export DRY_RUN
		;;
	--auto-yes)
		AUTO_YES=1
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		err "未知参数 / Unknown option: $1"
		usage >&2
		exit 1
		;;
	esac
	shift
done

# Arch 专用脚本，非 Arch 环境退出（DRY_RUN=1 时跳过校验）
require_arch "Arch Linux 快速配置仅支持在 Arch Linux 中运行 / Arch quick setup only runs on Arch Linux"

# ===== 菜单单一真源 / Single source of truth =====
# 格式: 选项键|标题|脚本名（空=特殊动作：0 退出、1 全部运行）
MENU_ITEMS=(
	"1|全部运行 / Run All|"
	"2|系统基础环境 / System Foundation|01-system-foundation.sh"
	"3|中文本地化 / Chinese Localization|02-chinese-localization.sh"
	"4|必备软件包 / Essential Packages|03-essential-packages.sh"
	"0|退出 / Exit|"
)

# 显示主菜单（读取 MENU_ITEMS，与分派共用一份数据）
show_menu() {
	clear 2>/dev/null || true
	header "Arch Linux 快速配置 / Quick Setup"
	if [ "${DRY_RUN:-0}" = "1" ]; then
		note "当前处于演练模式（DRY_RUN=1）/ Running in dry-run mode"
	fi
	if [ "${AUTO_YES:-0}" = "1" ]; then
		note "当前已开启自动确认模式（AUTO_YES=1，仅自动确认默认 Y/n 项）/ Auto-yes enabled (default Y/n items only)"
	fi
	local item key title _script
	for item in "${MENU_ITEMS[@]}"; do
		IFS='|' read -r key title _script <<<"$item"
		echo " [$key] $title"
	done
	echo
}

# 运行指定脚本
run_script() {
	local script_num=${1:-}
	local item key title script_name="" found=0

	for item in "${MENU_ITEMS[@]}"; do
		IFS='|' read -r key title script_name <<<"$item"
		[ "$key" = "$script_num" ] || continue
		found=1
		break
	done

	if [ "$found" -eq 0 ]; then
		err "无效选项 / Invalid option: $script_num"
		return 1
	fi

	case "$script_num" in
	0)
		note "再见 / Goodbye"
		exit 0
		;;
	1)
		step "开始完整配置 / Starting complete setup"
		local run_auto_yes="${AUTO_YES:-0}"
		if [ "$run_auto_yes" = "1" ]; then
			note "自动确认模式已启用（仅自动确认默认 Y/n 推荐项）/ Auto-yes mode enabled (default Y/n items only)"
		elif confirm_install 1 "是否自动确认所有推荐项（默认 Y/n，跳过 y/N）？/ Auto-confirm recommended items (Y/n, skips y/N)?"; then
			run_auto_yes=1
			note "本次批量执行已启用自动确认模式 / Auto-yes enabled for this Run All"
		fi

		local rc=0
		local failed_scripts=()
		local m_item _m_key _m_title m_script script_path child_rc
		for m_item in "${MENU_ITEMS[@]}"; do
			IFS='|' read -r _m_key _m_title m_script <<<"$m_item"
			[ -n "$m_script" ] || continue
			script_path="$SCRIPT_DIR/$m_script"
			if [ ! -f "$script_path" ] || [ ! -x "$script_path" ]; then
				err "脚本 $m_script 不存在或不可执行 / Script $m_script does not exist or is not executable"
				failed_scripts+=("$m_script")
				rc=1
				continue
			fi
			step "执行 $m_script / Executing $m_script"
			child_rc=0
			AUTO_YES="$run_auto_yes" "$script_path" || child_rc=$?
			if [ "$child_rc" -ne 0 ]; then
				err "脚本 $m_script 执行失败（退出码 $child_rc）/ Script $m_script failed (exit $child_rc)"
				failed_scripts+=("$m_script")
				rc=1
			fi
			echo
		done

		if [ "$rc" -ne 0 ]; then
			err "以下脚本执行失败 / Failed script(s): ${failed_scripts[*]}"
			return "$rc"
		fi
		ok "所有配置完成 / All configurations completed"
		return 0
		;;
	esac

	if [ -n "$script_name" ]; then
		local script_path="$SCRIPT_DIR/$script_name"
		if [ -f "$script_path" ] && [ -x "$script_path" ]; then
			step "执行 $script_name / Executing $script_name"
			local child_rc=0
			AUTO_YES="${AUTO_YES:-0}" "$script_path" || child_rc=$?
			return "$child_rc"
		else
			err "脚本 $script_name 不存在或不可执行 / Script $script_name does not exist or is not executable"
			return 1
		fi
	fi

	return 0
}

# 主循环
last_rc=0
while true; do
	show_menu
	if ! read -r -p "请选择操作 / Please select an option [0-4]: " choice; then
		break
	fi
	choice="${choice%$'\r'}"

	run_rc=0
	run_script "$choice" || run_rc=$?
	last_rc=$run_rc

	if [ "$run_rc" -eq 0 ]; then
		echo
		read -r -p "回车返回主菜单 / Press Enter to return to main menu…" || break
	else
		err "执行失败（退出码 $run_rc），请检查错误信息 / Execution failed (exit $run_rc), please check errors"
		read -r -p "回车返回主菜单 / Press Enter to return to main menu…" || break
	fi
done

exit "$last_rc"
