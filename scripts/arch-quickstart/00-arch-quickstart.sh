#!/bin/bash

set -e  # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 显示主菜单
show_menu() {
    clear
    echo "=== Arch Linux 快速配置菜单 / Quick Setup Menu ==="
    echo "1. 全部运行 / Run All (Complete Setup)"
    echo "2. 基础工具和AUR助手 / Base Tools & AUR Helper"
    echo "3. ArchlinuxCN仓库配置 / ArchlinuxCN Repository Setup"
    echo "4. Flatpak安装 / Flatpak Installation"
    echo "5. rEFInd引导管理器 / rEFInd Boot Manager"
    echo "6. Chezmoi配置管理 / Chezmoi Configuration Manager"
    echo "7. 备份工具安装 / Backup Tools Installation"
    echo "8. 命令行效率工具 / CLI Efficiency Tools"
    echo "9. 常用软件 (Pacman) / Common Software (Pacman)"
    echo "10. 常用软件 (AUR) / Common Software (AUR)"
    echo "11. 中文本地化配置 / Chinese Localization Setup"
    echo "0. 退出 / Exit"
    echo ""
}

# 运行指定脚本
run_script() {
    local script_num=$1
    local script_name=""
    
    case $script_num in
        0) echo "再见! / Goodbye!"; exit 0 ;;
        1) echo "开始完整配置... / Starting complete setup..." ;;
        2) script_name="01-base.sh" ;;
        3) script_name="02-archlinuxcn.sh" ;;
        4) script_name="03-flatpak.sh" ;;
        5) script_name="04-refind.sh" ;;
        6) script_name="05-chezmoi.sh" ;;
        7) script_name="06-backup-tools.sh" ;;
        8) script_name="07-cli-tools.sh" ;;
        9) script_name="08-software-pacman.sh" ;;
        10) script_name="09-software-aur.sh" ;;
        11) script_name="10-localization.sh" ;;
        *) echo "无效选项 / Invalid option"; return 1 ;;
    esac
    
    if [ "$script_num" -eq 0 ]; then
        # 选项 0 是退出，在 case 语句中已经处理
        return 0
    elif [ "$script_num" -eq 1 ]; then
        # 运行所有脚本（按数字顺序）
        for script in "$SCRIPT_DIR"/{01,02,03,04,05,06,07,08,09,10}-*.sh; do
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
    read -p "请选择操作 / Please select an option [0-11]: " choice
    
    if run_script "$choice"; then
        # 所有成功的选项都需要等待用户按键
        echo ""
        read -p "按回车键返回主菜单... / Press Enter to return to main menu..."
    else
        echo "执行失败，请检查错误信息 / Execution failed, please check error messages"
        read -p "按回车键返回主菜单... / Press Enter to return to main menu..."
    fi
done
