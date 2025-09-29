#!/bin/bash

set -e

echo "=== 安装 rEFInd 引导管理器 ==="

# 安装 rEFInd
echo "安装 rEFInd 引导管理器..."
sudo pacman -S --noconfirm refind
echo "安装 rEFInd 到 EFI 系统分区..."
sudo refind-install
echo "✓ rEFInd 安装完成"
