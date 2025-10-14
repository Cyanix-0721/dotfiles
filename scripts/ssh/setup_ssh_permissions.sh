#!/usr/bin/env bash

# SSH 目录权限设置脚本
# 更安全、幂等地设置 ~/.ssh 目录及其文件的权限

set -euo pipefail
IFS=$'\n\t'

SSH_DIR="${SSH_DIR:-$HOME/.ssh}"
DRY_RUN=0
VERBOSE=1

usage() {
	cat <<EOF
用法: $(basename "$0") [选项]

选项:
  -n, --dry-run    仅显示将要执行的操作，不做实际修改
  -q, --quiet      静默模式，最小输出
  -h, --help       显示此帮助
EOF
	exit 0
}

log() {
	if [ "$VERBOSE" -eq 1 ]; then
		printf "%s\n" "$*"
	fi
}

die() {
	printf "错误: %s\n" "$*" >&2
	exit 1
}

trap 'ret=$?; if [ "$ret" -ne 0 ]; then die "脚本异常退出 (code=$ret)"; fi' EXIT

# 参数解析
while [ "$#" -gt 0 ]; do
	case "$1" in
	-n | --dry-run)
		DRY_RUN=1
		shift
		;;
	-q | --quiet)
		VERBOSE=0
		shift
		;;
	-h | --help) usage ;;
	*) die "未知选项: $1" ;;
	esac
done

if [ ! -d "$SSH_DIR" ]; then
	die "SSH 目录不存在: $SSH_DIR"
fi

log "正在设置 SSH 目录权限: $SSH_DIR"

run_cmd() {
	if [ "$DRY_RUN" -eq 1 ]; then
		printf "DRY-RUN: %s\n" "$*"
	else
		eval "$*"
	fi
}

# 1) 设置目录本身权限为 700
log "设置目录权限 -> 700"
run_cmd "chmod 700 -- \"$SSH_DIR\""

# 2) 对目录下的文件做更安全、更可靠的迭代（处理空目录及带空格的文件）
changed_any=0
while IFS= read -r -d '' file; do
	# 仅处理普通文件（跳过目录、设备等）
	if [ ! -f "$file" ]; then
		continue
	fi

	base=$(basename -- "$file")
	mode=600

	case "$base" in
	config | known_hosts | known_hosts.old | authorized_keys)
		mode=600
		;;
	*.pub | authorized_keys.pub)
		mode=644
		;;
	id_*)
		# 私钥名通常以 id_ 开头，但排除 .pub
		if [[ "$base" == *.pub ]]; then
			mode=644
		else
			mode=600
		fi
		;;
	*)
		mode=600
		;;
	esac

	log "设置文件权限: $base -> $mode"
	run_cmd "chmod $mode -- \"$file\""
	changed_any=1
done < <(find -- "$SSH_DIR" -maxdepth 1 -type f -print0)

if [ "$changed_any" -eq 0 ]; then
	log "注意: 未找到要修改的文件（目录可能为空）"
fi

# 3) 只有在以 root 身份运行时才尝试 chown（避免普通用户执行失败）
if [ "$(id -u)" -eq 0 ]; then
	target_user="${SUDO_USER:-$USER}"
	log "以 root 运行，设置所有者 -> $target_user:$target_user"
	run_cmd "chown -R -- \"$target_user:$target_user\" \"$SSH_DIR\""
else
	log "非 root 用户，跳过 chown 操作（通常不需要）"
fi

trap - EXIT
log "\n✅ SSH 目录权限设置完成！\n当前权限状态:"
run_cmd "ls -la -- \"$SSH_DIR\""
