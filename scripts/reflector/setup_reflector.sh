#!/bin/bash

# 创建Reflector服务文件
cat > /etc/systemd/system/reflector.service << 'EOF'
[Unit]
Description=Pacman mirrorlist update with Reflector

[Service]
Type=oneshot
ExecStart=/usr/bin/reflector -c 'China,Hong Kong,Taiwan,Japan,United States' -p https -l 40 -a 24 --save /etc/pacman.d/mirrorlist
EOF

# 创建Reflector定时器文件
cat > /etc/systemd/system/reflector.timer << 'EOF'
[Unit]
Description=Run reflector weekly to update mirrorlist

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
