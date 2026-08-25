#!/bin/bash

# 默认启用项：WSL → Windows OpenSSH agent（KeePassXC）SSH 转发
# 生成 win-ssh 包装脚本（WSL ~/bin 与 Windows .local/bin），并注入 GIT_SSH_COMMAND
# Default-enabled: forward WSL git SSH to the Windows OpenSSH agent (KeePassXC)

set -e # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数
. "$SCRIPT_DIR/00-common.sh"

require_wsl "SSH agent 转发仅支持 WSL / SSH agent forwarding only supports WSL"

header "SSH Agent 转发 / SSH Agent Forwarding"

# 启用自动确认（菜单 Run All 时传入 AUTO_YES=1）
init_auto_yes

# 本机/目标主机都已存在包装脚本时，默认不再重复写入；可传 FORCE=1 强制覆盖
: "${FORCE:=0}"

# 1) 解析 Windows 用户目录（WSL 路径）与 Windows 风格路径
WIN_HOME="$(get_win_user_home)" || {
	err "无法解析 Windows 用户目录（需要从 WSL 调用 powershell.exe）"
	err "Cannot resolve Windows user profile (requires powershell.exe from WSL)"
	exit 1
}
note "Windows 用户目录 / Windows user profile: $WIN_HOME"

WIN_SSH_PS1_PATH="$WIN_HOME/.local/bin/win-ssh.ps1"
WIN_SSH_PS1_PATH_WIN=$(printf '%s' "$WIN_SSH_PS1_PATH" | sed \
	-e 's#^/mnt/\([A-Za-z]\)#\U\1:#' \
	-e 's#/#\\#g')
WSL_SSH_PATH="$HOME/bin/win-ssh"

# 2) 生成 Windows 侧 win-ssh.ps1（写入 $1 指定路径）
write_win_ps1() {
	local target="${1:-$WIN_SSH_PS1_PATH}"
	mkdir -p "$(dirname "$target")"
	cat >"$target" <<'PS1'
Remove-Item Env:SSH_AUTH_SOCK -ErrorAction SilentlyContinue
& 'C:\Windows\System32\OpenSSH\ssh.exe' @args
exit $LASTEXITCODE
PS1
}

# 3) 生成 WSL 侧 win-ssh 包装脚本（写入 $1 指定路径）
write_wsl_wrapper() {
	local target="${1:-$WSL_SSH_PATH}"
	mkdir -p "$(dirname "$target")"
	cat >"$target" <<EOF
#!/usr/bin/env sh
exec /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$WIN_SSH_PS1_PATH_WIN" "\$@"
EOF
	chmod +x "$target"
}

# 写入：目标不存在则生成；存在且内容一致则跳过；不一致（或 FORCE=1）且用户同意时覆盖
ensure_file() {
	local f="$1" fn="$2" tmp
	if [ "$FORCE" = "1" ]; then
		step "写入 / Writing $f"
		write_"$fn" "$f"
		ok "已生成 / Generated: $f"
		return 0
	fi
	if [ ! -f "$f" ]; then
		step "写入 / Writing $f"
		write_"$fn" "$f"
		ok "已生成 / Generated: $f"
		return 0
	fi
	tmp="$(mktemp)"
	write_"$fn" "$tmp"
	if diff -q "$tmp" "$f" >/dev/null 2>&1; then
		rm -f "$tmp"
		ok "已存在且内容一致，跳过 / Up to date: $f"
		return 0
	fi
	rm -f "$tmp"
	if confirm_install 1 "检测到 $f 内容不一致，覆盖？/ Content differs, overwrite?"; then
		step "覆盖 / Overwriting $f"
		write_"$fn" "$f"
		ok "已更新 / Updated: $f"
	else
		warn "保留现有文件 / Keeping existing: $f"
	fi
}

ensure_file "$WIN_SSH_PS1_PATH" win_ps1
ensure_file "$WSL_SSH_PATH" wsl_wrapper

# 4) 设置 GIT_SSH_COMMAND：仅 WSL 使用，用 fish universal variable 持久化（不写入跨平台配置文件）
#    默认 shell 为 fish，~/.bashrc 注入对其无效，故改用 fish -U（universal）设置
if command -v fish >/dev/null 2>&1; then
	step "设置 GIT_SSH_COMMAND（fish universal）/ Setting GIT_SSH_COMMAND (fish universal)"
	fish -c 'set -Ux GIT_SSH_COMMAND "$HOME/bin/win-ssh"'
	ok "GIT_SSH_COMMAND 已设置（fish universal）/ GIT_SSH_COMMAND set (fish universal)"
else
	warn "未检测到 fish，跳过 GIT_SSH_COMMAND / fish not found, skipping GIT_SSH_COMMAND"
fi

# 5) 自检（可选）
note "部署完成 / Deployment complete"
note "验证命令 / Verify with: GIT_SSH_COMMAND=\"\$HOME/bin/win-ssh\" git ls-remote <remote> HEAD"
if confirm_install 0 "现在验证 GitHub 连通性（需 Windows agent 已注入密钥）？/ Verify GitHub connectivity now (requires a key injected into the Windows agent)?"; then
	if "$WSL_SSH_PATH" -o BatchMode=yes -o ConnectTimeout=10 -T git@github.com >/dev/null 2>&1; then
		ok "GitHub SSH 转发验证通过 / GitHub SSH forwarding verified"
	else
		err "GitHub SSH 转发验证失败（请确认 KeePassXC 已解锁并注入密钥）"
		err "GitHub SSH forwarding failed (unlock KeePassXC and make sure the key is injected)"
		exit 1
	fi
fi

ok "SSH Agent 转发配置完成 / SSH agent forwarding configured"
