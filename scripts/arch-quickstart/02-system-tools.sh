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
