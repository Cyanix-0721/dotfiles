#!/bin/bash

set -e

echo "=== 安装 rEFInd 引导管理器 / Installing rEFInd Boot Manager ==="

# 安装 rEFInd / Install rEFInd
echo "安装 rEFInd 引导管理器... / Installing rEFInd boot manager..."
sudo pacman -S --noconfirm refind

echo "安装 rEFInd 到 EFI 系统分区... / Installing rEFInd to EFI system partition..."
sudo refind-install

echo "✓ rEFInd 安装完成 / rEFInd installation completed"
