#!/bin/bash

set -e # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数
. "$SCRIPT_DIR/00-common.sh"

# WSL 专用脚本，非 WSL 直接退出
require_wsl "WSL 快速配置仅支持在 WSL 中运行 / WSL quick setup only runs inside WSL"

# 显示主菜单
show_menu() {
	clear
	header "WSL 快速配置 / WSL Quick Setup"
	echo " [1] 全部运行 / Run All"
	echo " [2] SSH Agent 转发（win-ssh，默认启用）/ SSH Agent Forwarding (win-ssh, enabled by default)"
	echo " [0] 退出 / Exit"
	echo
}

# 运行指定脚本
run_script() {
	local script_num=$1
	local script_name=""

	case $script_num in
	0)
		note "再见 / Goodbye"
		exit
		;;
	1)
		step "开始完整配置 / Starting complete setup"
		if confirm_install 0 "是否全选 Y（自动确认所有安装）？/ Select all Y (auto-confirm all installations)?"; then
			export AUTO_YES=1
			note "自动确认模式已启用 / Auto-yes mode enabled"
		fi
		;;
	2) script_name="01-ssh-agent-forward.sh" ;;
	*)
		err "无效选项 / Invalid option"
		return 1
		;;
	esac

	if [ "$script_num" -eq 0 ]; then
		# 选项 0 是退出，在 case 语句中已经处理
		return 0
	elif [ "$script_num" -eq 1 ]; then
		# 运行所有脚本（按数字顺序，排除主脚本）
		for script in "$SCRIPT_DIR"/0[1]-*.sh; do
			if [ -f "$script" ] && [ -x "$script" ]; then
				step "执行 $(basename "$script") / Executing $(basename "$script")"
				"$script"
				echo
			fi
		done
		ok "所有配置完成 / All configurations completed"
	elif [ -n "$script_name" ]; then
		local script_path="$SCRIPT_DIR/$script_name"
		if [ -f "$script_path" ] && [ -x "$script_path" ]; then
			step "执行 $script_name / Executing $script_name"
			"$script_path"
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
	read -p "请选择操作 / Please select an option [0-2]: " choice

	if run_script "$choice"; then
		# 所有成功的选项都需要等待用户按键
		echo
		read -p "回车返回主菜单 / Press Enter to return to main menu…"
	else
		err "执行失败，请检查错误信息 / Execution failed, please check errors"
		read -p "回车返回主菜单 / Press Enter to return to main menu…"
	fi
done
