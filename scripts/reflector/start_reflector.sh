#!/bin/bash

set -e

# 检查权限
if [ "$EUID" -ne 0 ]; then
  echo "请使用 sudo 运行此脚本"
  exit 1
fi

echo "正在重新加载 systemd 配置..."
systemctl daemon-reload

echo "正在启动 Reflector 服务..."
if systemctl start reflector.service; then
  echo "✓ 镜像列表更新成功"

  # 显示镜像统计信息
  total_lines=$(wc -l </etc/pacman.d/mirrorlist)
  total_servers=$(grep -E '^Server' /etc/pacman.d/mirrorlist | wc -l)

  echo -e "\n镜像文件统计:"
  echo "总行数: $total_lines"
  echo "实际镜像服务器数量: $total_servers"

  # 显示前10个镜像服务器
  echo -e "\n前10个镜像服务器:"
  echo "=========================================="
  grep -E '^Server' /etc/pacman.d/mirrorlist | head -10 | cat -n
  echo "=========================================="

  # 显示各国家/地区的镜像分布
  echo -e "\n镜像分布统计:"
  echo "中国镜像: $(grep -c 'China' /etc/pacman.d/mirrorlist)"
  echo "香港镜像: $(grep -c 'Hong Kong' /etc/pacman.d/mirrorlist)"
  echo "台湾镜像: $(grep -c 'Taiwan' /etc/pacman.d/mirrorlist)"
  echo "日本镜像: $(grep -c 'Japan' /etc/pacman.d/mirrorlist)"
  echo "美国镜像: $(grep -c 'United States' /etc/pacman.d/mirrorlist)"

else
  echo "✗ 镜像列表更新失败"
  exit 1
fi
