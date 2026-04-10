#!/bin/bash

set -euo pipefail

usage() {
	cat <<EOF
用法: $(basename "$0") [选项]

选项:
  --setup    安装并配置 reflector 服务（默认）
  --run      手动触发一次镜像列表更新
  -h, --help 显示此帮助
EOF
}

MODE=""
while [ "$#" -gt 0 ]; do
	case "$1" in
	--setup) MODE="setup" ;;
	--run) MODE="run" ;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		usage
		exit 1
		;;
	esac
	shift
done

: "${MODE:=setup}"

check_root() {
	if [ "$(id -u)" -ne 0 ]; then
		echo "错误: 请以 root 权限运行此脚本" >&2
		exit 1
	fi
}

install_reflector() {
	if ! command -v reflector &>/dev/null; then
		echo "正在安装 reflector..."
		pacman -Sy reflector --noconfirm
	fi
}

setup_service() {
	check_root

	local -r service_file="/etc/systemd/system/reflector.service"
	local -r timer_file="/etc/systemd/system/reflector.timer"

	cat >"$service_file" <<'EOF'
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

	cat >"$timer_file" <<'EOF'
[Unit]
Description=Run reflector weekly to update mirrorlist
Requires=reflector.service

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

	systemctl daemon-reload
	systemctl enable reflector.timer
	systemctl start reflector.timer

	echo "✓ Reflector 服务已配置"
}

run_reflector() {
	check_root

	echo "正在更新镜像列表..."
	if systemctl start reflector.service; then
		echo "✓ 镜像列表更新成功"

		local total_servers
		total_servers=$(grep -c '^Server' /etc/pacman.d/mirrorlist)

		echo -e "\n当前镜像服务器数量: $total_servers"
		echo -e "\n前10个镜像服务器:"
		echo "=========================================="
		grep '^Server' /etc/pacman.d/mirrorlist | head -10 | nl -w2
		echo "=========================================="
	else
		echo "✗ 镜像列表更新失败" >&2
		exit 1
	fi
}

show_status() {
	check_root

	local total_servers
	total_servers=$(grep -c '^Server' /etc/pacman.d/mirrorlist)

	echo "=========================================="
	echo "Reflector 定时任务状态:"
	systemctl status reflector.timer --no-pager || true
	echo -e "\n当前镜像服务器数量: $total_servers"
	echo -e "\n前10个镜像服务器:"
	grep '^Server' /etc/pacman.d/mirrorlist | head -10 | nl -w2
	echo "=========================================="
}

case "$MODE" in
setup)
	install_reflector
	setup_service
	run_reflector
	show_status
	;;
run)
	run_reflector
	;;
esac
