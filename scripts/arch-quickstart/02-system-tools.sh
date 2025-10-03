#!/bin/bash

set -e

echo "=== 安装系统工具 / Installing System Tools ==="

# rEFInd 引导管理器
echo "=== rEFInd 引导管理器 / rEFInd Boot Manager ==="

# 检查 rEFInd 是否已安装
if command -v refind-install &> /dev/null; then
    echo "✓ rEFInd 已安装 / rEFInd is already installed"
    refind_available=true
else
    read -p "是否安装 rEFInd 引导管理器？(Y/n) / Install rEFInd boot manager? (Y/n): " install_refind
    if [[ ! $install_refind =~ ^[Nn]$ ]]; then
        echo "安装 rEFInd 引导管理器… / Installing rEFInd boot manager…"
        sudo pacman -S --noconfirm refind
        
        # 验证安装是否成功
        if command -v refind-install &> /dev/null; then
            echo "✓ rEFInd 安装完成 / rEFInd installation completed"
            refind_available=true
        else
            echo "✗ rEFInd 安装失败 / rEFInd installation failed"
            refind_available=false
        fi
    else
        echo "跳过 rEFInd 安装 / Skipping rEFInd installation"
        refind_available=false
    fi
fi

# 询问是否运行 refind-install (仅在工具可用时)
if [[ $refind_available == "true" ]]; then
    read -p "是否运行 refind-install 安装到 EFI 系统分区？(Y/n) / Run refind-install to install to EFI system partition? (Y/n): " run_refind_install
    if [[ ! $run_refind_install =~ ^[Nn]$ ]]; then
        echo "安装 rEFInd 到 EFI 系统分区… / Installing rEFInd to EFI system partition…"
        sudo refind-install
        echo "✓ rEFInd 已安装到 EFI 系统分区 / rEFInd installed to EFI system partition"
    else
        echo "跳过 refind-install / Skipping refind-install"
    fi
fi

# 安装 rEFInd 主题 (仅在 rEFInd 可用时)
if [[ $refind_available == "true" ]]; then
    echo "=== rEFInd 主题安装 / rEFInd Theme Installation ==="
    read -p "是否安装 Catppuccin 主题？(Y/n) / Install Catppuccin theme? (Y/n): " install_refind_theme
    if [[ ! $install_refind_theme =~ ^[Nn]$ ]]; then
        
        # 查找 rEFInd 目录
        REFIND_DIR=""
        if [[ -d "/boot/EFI/refind" ]]; then
            REFIND_DIR="/boot/EFI/refind"
            echo "找到 rEFInd 目录: $REFIND_DIR / Found rEFInd directory: $REFIND_DIR"
        else
            # 在 /boot 下搜索 refind 文件夹
            echo "在 /boot 下搜索 rEFInd 目录… / Searching for rEFInd directory in /boot…"
            REFIND_SEARCH=$(find /boot -type d -name "refind" 2>/dev/null | head -n1)
            if [[ -n "$REFIND_SEARCH" && -d "$REFIND_SEARCH" ]]; then
                REFIND_DIR="$REFIND_SEARCH"
                echo "找到 rEFInd 目录: $REFIND_DIR / Found rEFInd directory: $REFIND_DIR"
            else
                echo "✗ 未找到 rEFInd 目录，跳过主题安装 / rEFInd directory not found, skipping theme installation"
            fi
        fi
        
        # 如果找到 rEFInd 目录，安装主题
        if [[ -n "$REFIND_DIR" ]]; then
            # 创建 themes 目录
            THEMES_DIR="$REFIND_DIR/themes"
            echo "创建主题目录: $THEMES_DIR / Creating theme directory: $THEMES_DIR"
            sudo mkdir -p "$THEMES_DIR"
            
            # 克隆主题
            echo "克隆 Catppuccin 主题… / Cloning Catppuccin theme…"
            if command -v git &> /dev/null; then
                sudo git clone https://github.com/catppuccin/refind.git "$THEMES_DIR/catppuccin"
                
                # 选择主题口味
                echo "请选择主题口味 / Please select theme flavor:"
                echo "1) latte"
                echo "2) frappe" 
                echo "3) macchiato"
                echo "4) mocha (默认/default)"
                read -p "输入选择 (1-4) / Enter choice (1-4) [4]: " flavor_choice
                
                case $flavor_choice in
                    1) FLAVOR="latte" ;;
                    2) FLAVOR="frappe" ;;
                    3) FLAVOR="macchiato" ;;
                    *) FLAVOR="mocha" ;;
                esac
                
                echo "选择的口味: $FLAVOR / Selected flavor: $FLAVOR"
                
                # 检查主题文件是否存在
                THEME_CONF="$THEMES_DIR/catppuccin/${FLAVOR}.conf"
                if [[ -f "$THEME_CONF" ]]; then
                    # 备份原配置文件
                    REFIND_CONF="$REFIND_DIR/refind.conf"
                    if [[ -f "$REFIND_CONF" ]]; then
                        sudo cp "$REFIND_CONF" "$REFIND_CONF.bak"
                        echo "已备份原配置文件: $REFIND_CONF.bak / Original config backed up: $REFIND_CONF.bak"
                    fi
                    
                    # 添加主题配置到 refind.conf
                    echo "添加主题配置到 refind.conf… / Adding theme configuration to refind.conf…"
                    INCLUDE_LINE="include themes/catppuccin/${FLAVOR}.conf"
                    
                    # 检查是否已包含该主题
                    if ! sudo grep -q "include themes/catppuccin/" "$REFIND_CONF" 2>/dev/null; then
                        echo "$INCLUDE_LINE" | sudo tee -a "$REFIND_CONF" > /dev/null
                        echo "✓ 主题配置已添加 / Theme configuration added"
                    else
                        echo "✓ 主题配置已存在 / Theme configuration already exists"
                    fi
                    
                    echo "✓ Catppuccin 主题安装完成 / Catppuccin theme installation completed"
                else
                    echo "✗ 主题配置文件不存在: $THEME_CONF / Theme config file not found: $THEME_CONF"
                fi
            else
                echo "✗ git 未安装，无法克隆主题 / git not installed, cannot clone theme"
            fi
        fi
    else
        echo "跳过 rEFInd 主题安装 / Skipping rEFInd theme installation"
    fi
fi

# 备份工具
echo "=== 备份工具 / Backup Tools ==="
read -p "是否安装备份工具？(Y/n) / Install backup tools? (Y/n): " install_backup_tools
if [[ ! $install_backup_tools =~ ^[Nn]$ ]]; then
    echo "安装备份工具… / Installing backup tools…"
    sudo pacman -S --noconfirm snapper btrfs-assistant
    echo "✓ 备份工具安装完成 / Backup tools installation completed"
else
    echo "跳过备份工具安装 / Skipping backup tools installation"
fi

# Chezmoi 配置管理工具
echo "=== Chezmoi 配置管理工具 / Chezmoi Configuration Management Tool ==="

# 检查 Chezmoi 是否已安装
if command -v chezmoi &> /dev/null; then
    echo "✓ Chezmoi 已安装 / Chezmoi is already installed"
    chezmoi_available=true
else
    read -p "是否安装 Chezmoi 配置管理工具？(Y/n) / Install Chezmoi configuration management tool? (Y/n): " install_chezmoi
    if [[ ! $install_chezmoi =~ ^[Nn]$ ]]; then
        echo "安装 Chezmoi… / Installing Chezmoi…"
        sudo pacman -S --noconfirm chezmoi
        
        # 验证安装是否成功
        if command -v chezmoi &> /dev/null; then
            echo "✓ Chezmoi 安装完成 / Chezmoi installation completed"
            chezmoi_available=true
        else
            echo "✗ Chezmoi 安装失败 / Chezmoi installation failed"
            chezmoi_available=false
        fi
    else
        echo "跳过 Chezmoi 安装 / Skipping Chezmoi installation"
        chezmoi_available=false
    fi
fi

# 询问是否初始化 dotfiles (仅在工具可用时)
if [[ $chezmoi_available == "true" ]]; then
    read -p "是否初始化 dotfiles 配置？(Y/n) / Initialize dotfiles configuration? (Y/n): " init_chezmoi
    if [[ ! $init_chezmoi =~ ^[Nn]$ ]]; then
        echo "初始化 dotfiles 配置… / Initializing dotfiles configuration…"
        chezmoi init https://github.com/Cyanix-0721/dotfiles.git -a
        echo "✓ dotfiles 配置初始化完成 / dotfiles configuration initialized"
    else
        echo "跳过 dotfiles 配置初始化 / Skipping dotfiles configuration initialization"
    fi
fi

echo "✓ 系统工具安装完成 / System tools installation completed"
