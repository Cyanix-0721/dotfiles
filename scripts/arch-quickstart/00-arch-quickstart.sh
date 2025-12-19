#!/bin/bash

set -e # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 统一日志输出样式（仅影响提示，不改变脚本行为）
if [ -t 1 ]; then
	RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m";
	RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; BLUE="\033[34m"; CYAN="\033[36m";
else
	RESET=""; BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN="";
fi

header() { printf "\n%s%s==> %s%s\n" "$BOLD" "$BLUE" "$1" "$RESET"; }
step()   { printf "%s→ %s…%s\n" "$CYAN" "$1" "$RESET"; }
ok()     { printf "%s✓ %s%s\n" "$GREEN" "$1" "$RESET"; }
warn()   { printf "%s⚠ %s%s\n" "$YELLOW" "$1" "$RESET"; }
err()    { printf "%s✗ %s%s\n" "$RED" "$1" "$RESET"; }
note()   { printf "%s∙ %s%s\n" "$DIM" "$1" "$RESET"; }

# 显示主菜单
show_menu() {
	clear
	header "Arch Linux 快速配置 / Quick Setup"
	echo " [1] 全部运行 / Run All"
	echo " [2] 系统基础环境 / System Foundation"
	echo " [3] 中文本地化 / Chinese Localization"
	echo " [4] 必备软件包 / Essential Packages"
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
	1) step "开始完整配置 / Starting complete setup" ;;
	2) script_name="01-system-foundation.sh" ;;
	3) script_name="02-chinese-localization.sh" ;;
	4) script_name="03-essential-packages.sh" ;;
	*)
		err "无效选项 / Invalid option"
		return 1
		;;
	esac

	if [ "$script_num" -eq 0 ]; then
		# 选项 0 是退出，在 case 语句中已经处理
		return 0
	elif [ "$script_num" -eq 1 ]; then
		# 运行所有脚本（按数字顺序）
		for script in "$SCRIPT_DIR"/{01,02,03}-*.sh; do
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
	read -p "请选择操作 / Please select an option [0-4]: " choice

	if run_script "$choice"; then
		# 所有成功的选项都需要等待用户按键
		echo
		read -p "回车返回主菜单 / Press Enter to return to main menu…"
	else
		err "执行失败，请检查错误信息 / Execution failed, please check errors"
		read -p "回车返回主菜单 / Press Enter to return to main menu…"
	fi
done
