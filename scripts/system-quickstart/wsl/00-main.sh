#!/bin/bash

set -euo pipefail # 遇到错误立即退出；-u 未定义变量即报错；管道任一环节失败即视为失败

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数（已内置 QUICKSTART_DRY_RUN=1 / QUICKSTART_AUTO_YES=1 归一化）
. "$SCRIPT_DIR/00-common.sh"

# 解析 CLI 参数（--dry-run / --auto-yes / -h）
parse_wsl_args "$@"

# WSL 专用脚本，非 WSL 直接退出
require_wsl "WSL 快速配置仅支持在 WSL 中运行 / WSL quick setup only runs inside WSL"

# ===== 菜单单一真源 / Single source of truth =====
# 格式: 选项键|标题|脚本名（空=特殊动作：0 退出、1 全部运行）
MENU_ITEMS=(
	"1|全部运行 / Run All|"
	"2|常用软件安装 / Essential Packages|01-essential-packages.sh"
	"3|SSH Agent 转发（win-ssh，默认启用）/ SSH Agent Forwarding (win-ssh, enabled by default)|02-ssh-agent-forward.sh"
	"0|退出 / Exit|"
)

# 显示主菜单（读取 MENU_ITEMS，与分派共用一份数据）
show_menu() {
	clear 2>/dev/null || true
	header "WSL 快速配置 / WSL Quick Setup"
	if [ "${DRY_RUN:-0}" = "1" ]; then
		note "当前模式: DRY-RUN（只打印不执行）/ Mode: DRY-RUN (print only)"
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
	local item key title script_name found=0

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
			note "自动确认模式已启用（仅自动确认默认 Y/n 推荐项）/ Auto-yes mode enabled (default Y/n items only)"
		fi

		local failed=0
		local failed_scripts=()
		local m_item _m_key _m_title m_script m_path m_rc
		for m_item in "${MENU_ITEMS[@]}"; do
			IFS='|' read -r _m_key _m_title m_script <<<"$m_item"
			[ -n "$m_script" ] || continue
			m_path="$SCRIPT_DIR/$m_script"
			if [ ! -f "$m_path" ] || [ ! -x "$m_path" ]; then
				err "脚本 $m_script 不存在或不可执行 / Script $m_script does not exist or is not executable"
				failed=$((failed + 1))
				failed_scripts+=("$m_script")
				continue
			fi
			step "执行 $m_script / Executing $m_script"
			m_rc=0
			AUTO_YES="$run_auto_yes" "$m_path" || m_rc=$?
			if [ "$m_rc" -ne 0 ]; then
				err "脚本 $m_script 执行失败（退出码 $m_rc）/ Script $m_script failed (exit code $m_rc)"
				failed=$((failed + 1))
				failed_scripts+=("$m_script (exit $m_rc)")
			fi
			echo
		done

		if [ "$failed" -gt 0 ]; then
			err "全部运行完成，但有 $failed 个脚本失败 / Run All completed with $failed failed script(s): ${failed_scripts[*]}"
			return 1
		fi
		ok "所有配置完成 / All configurations completed"
		return 0
		;;
	esac

	if [ -n "$script_name" ]; then
		local script_path="$SCRIPT_DIR/$script_name"
		if [ ! -f "$script_path" ] || [ ! -x "$script_path" ]; then
			err "脚本 $script_name 不存在或不可执行 / Script $script_name does not exist or is not executable"
			return 1
		fi
		step "执行 $script_name / Executing $script_name"
		local rc=0
		AUTO_YES="${AUTO_YES:-0}" "$script_path" || rc=$?
		return "$rc"
	fi

	return 0
}

# 主循环（保留最近一次失败的退出码，避免 stdin EOF 吞掉非零状态）
last_rc=0
while true; do
	show_menu
	if ! read -r -p "请选择操作 / Please select an option [0-3]: " choice; then
		break
	fi
	choice="${choice%$'\r'}"
	[ -z "$choice" ] && continue

	rc=0
	run_script "$choice" || rc=$?
	last_rc=$rc
	if [ "$rc" -eq 0 ]; then
		# 所有成功的选项都需要等待用户按键
		echo
		read -r -p "回车返回主菜单 / Press Enter to return to main menu…" || break
	else
		err "执行失败，请检查错误信息 / Execution failed, please check errors"
		read -r -p "回车返回主菜单 / Press Enter to return to main menu…" || break
	fi
done

exit "$last_rc"
