#!/bin/bash

set -euo pipefail # 遇到错误立即退出；-u 未定义变量即报错；管道任一环节失败即视为失败

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数
. "$SCRIPT_DIR/00-common.sh"

# 支持 QUICKSTART_DRY_RUN=1 进入 dry-run（只打印不执行）
if [ "${QUICKSTART_DRY_RUN:-0}" = "1" ]; then export DRY_RUN=1; fi

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
		err "无效选项 / Invalid option"
		return 1
	fi

	case $script_num in
	0)
		note "再见 / Goodbye"
		exit 0
		;;
	1)
		step "开始完整配置 / Starting complete setup"
		if confirm_install 1 "是否全选 Y（自动确认所有安装）？/ Select all Y (auto-confirm all installations)?"; then
			export AUTO_YES=1
			note "自动确认模式已启用 / Auto-yes mode enabled"
		fi
		for script in "$SCRIPT_DIR"/0[1-2]-*.sh; do
			if [ -f "$script" ] && [ -x "$script" ]; then
				step "执行 $(basename "$script") / Executing $(basename "$script")"
				"$script" || return 1
				echo
			fi
		done
		ok "所有配置完成 / All configurations completed"
		;;
	esac

	if [ -n "$script_name" ]; then
		local script_path="$SCRIPT_DIR/$script_name"
		if [ -f "$script_path" ] && [ -x "$script_path" ]; then
			step "执行 $script_name / Executing $script_name"
			"$script_path" || return 1
		else
			err "脚本 $script_name 不存在或不可执行 / Script $script_name does not exist or is not executable"
			return 1
		fi
	fi

	return 0
}

# 主循环
while true; do
	show_menu
	read -r -p "请选择操作 / Please select an option [0-3]: " choice || break

	if run_script "$choice"; then
		# 所有成功的选项都需要等待用户按键
		echo
		read -r -p "回车返回主菜单 / Press Enter to return to main menu…" || break
	else
		err "执行失败，请检查错误信息 / Execution failed, please check errors"
		read -r -p "回车返回主菜单 / Press Enter to return to main menu…" || break
	fi
done
