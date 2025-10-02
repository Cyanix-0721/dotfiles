#!/bin/bash

set -e  # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 显示主菜单
show_menu() {
    clear
    echo "=== Arch Linux 快速配置菜单 / Quick Setup Menu ==="
    echo "1. 全部运行 / Run All (Complete Setup)"
    echo "2. 系统基础环境配置 / System Foundation Setup"
    echo "3. 系统工具安装 / System Tools Installation"
    echo "4. 中文本地化配置 / Chinese Localization Setup"
    echo "5. 必备软件包安装 / Essential Packages Installation"
    echo "0. 退出 / Exit"
    echo ""
}

# 运行指定脚本
run_script() {
    local script_num=$1
    local script_name=""
    
    case $script_num in
        0) echo "再见! / Goodbye!"; exit  ;;
        1) echo "开始完整配置… / Starting complete setup…" ;;
        2) script_name="01-system-foundation.sh" ;;
        3) script_name="02-system-tools.sh" ;;
        4) script_name="03-chinese-localization.sh" ;;
        5) script_name="04-essential-packages.sh" ;;
        *) echo "无效选项 / Invalid option"; return 1 ;;
    esac
    
    if [ "$script_num" -eq 0 ]; then
        # 选项 0 是退出，在 case 语句中已经处理
        return 0
    elif [ "$script_num" -eq 1 ]; then
        # 运行所有脚本（按数字顺序）
        for script in "$SCRIPT_DIR"/{01,02,03,04}-*.sh; do
            if [ -f "$script" ] && [ -x "$script" ]; then
                echo "执行: $(basename "$script") / Executing: $(basename "$script")"
                "$script"
                echo ""
            fi
        done
        echo "✓ 所有配置完成! / All configurations completed!"
    elif [ -n "$script_name" ]; then
        local script_path="$SCRIPT_DIR/$script_name"
        if [ -f "$script_path" ] && [ -x "$script_path" ]; then
            echo "执行: $script_name / Executing: $script_name"
            "$script_path"
        else
            echo "错误: 脚本 $script_name 不存在或不可执行 / Error: Script $script_name does not exist or is not executable"
            return 1
        fi
    fi
    
    return 0
}

# 主循环
while true; do
    show_menu
    read -p "请选择操作 / Please select an option [0-5]: " choice
    
    if run_script "$choice"; then
        # 所有成功的选项都需要等待用户按键
        echo ""
        read -p "按回车键返回主菜单… / Press Enter to return to main menu…"
    else
        echo "执行失败，请检查错误信息 / Execution failed, please check error messages"
        read -p "按回车键返回主菜单… / Press Enter to return to main menu…"
    fi
done
