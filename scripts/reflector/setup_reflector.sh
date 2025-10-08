#!/bin/bash

set -e

# 检查root权限
if [[ $EUID -ne 0 ]]; then
  echo "错误：请以root权限运行此脚本"
  exit 1
fi

# 检查并安装reflector
if ! command -v reflector &>/dev/null; then
  echo "检测到reflector未安装，正在安装..."
  pacman -Sy reflector --noconfirm
  echo "reflector安装完成！"
fi

# 创建Reflector服务文件
cat >/etc/systemd/system/reflector.service <<'EOF'
[Unit]
Description=Pacman mirrorlist update with Reflector
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/reflector -c 'China,Hong Kong,Taiwan,Japan,United States' -p https -l 20 -a 24 --save /etc/pacman.d/mirrorlist
User=root

[Install]
WantedBy=multi-user.target
EOF

# 创建Reflector定时器文件
cat >/etc/systemd/system/reflector.timer <<'EOF'
[Unit]
Description=Run reflector weekly to update mirrorlist
Requires=reflector.service

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

# 重新加载Systemd配置
systemctl daemon-reload

# 启用并启动定时器
systemctl enable reflector.timer
systemctl start reflector.timer

echo "Reflector定时任务配置完成！"

# 调用启动脚本进行首次更新
echo "正在执行首次镜像列表更新..."
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
"$SCRIPT_DIR/start_reflector.sh"
