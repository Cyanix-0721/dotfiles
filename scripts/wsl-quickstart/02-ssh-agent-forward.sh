#!/bin/bash

# 默认启用项：WSL → Windows OpenSSH agent（KeePassXC）SSH 转发
# 生成 win-ssh 包装脚本（WSL ~/bin 与 Windows .local/bin）；git 经 ~/.gitconfig 的 core.sshCommand 调用 win-ssh
# Default-enabled: forward WSL git SSH to the Windows OpenSSH agent (KeePassXC)
# git calls win-ssh via core.sshCommand in ~/.gitconfig (managed by chezmoi)

set -euo pipefail # 遇到错误立即退出；-u 未定义变量即报错；管道任一环节失败即视为失败

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
if command -v wslpath >/dev/null 2>&1; then
	WIN_SSH_PS1_PATH_WIN=$(wslpath -w "$WIN_SSH_PS1_PATH" 2>/dev/null) || WIN_SSH_PS1_PATH_WIN=$WIN_SSH_PS1_PATH
elif [[ "$WIN_SSH_PS1_PATH" =~ ^/mnt/([A-Za-z])(/.*)$ ]]; then
	WIN_SSH_PS1_PATH_WIN="${BASH_REMATCH[1]^^}:${BASH_REMATCH[2]//\//\\}"
else
	WIN_SSH_PS1_PATH_WIN="$WIN_SSH_PS1_PATH"
fi

# 解析 WSL 侧可用的 powershell.exe（优先 interop PATH，回退系统默认位置）
# Resolve the WSL-side powershell.exe (prefer interop PATH, fall back to default location)
POWERSHELL_EXE="$(command -v powershell.exe 2>/dev/null || true)"
[ -n "$POWERSHELL_EXE" ] || POWERSHELL_EXE="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
WSL_SSH_PATH="$HOME/bin/win-ssh"

# 2) 生成 Windows 侧 win-ssh.ps1（写入 $1 指定路径）
write_win_ps1() {
	local target="${1:-$WIN_SSH_PS1_PATH}"
	mkdir -p "$(dirname "$target")"
	cat >"$target" <<'PS1'
Remove-Item Env:SSH_AUTH_SOCK -ErrorAction SilentlyContinue
# winget 版 OpenSSH Preview 装在 Program Files，系统内置版在 System32；两者都缺时退回 PATH 解析
$ssh = @(
    "$env:ProgramFiles\OpenSSH\ssh.exe"
    "$env:SystemRoot\System32\OpenSSH\ssh.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ssh) { $ssh = "ssh.exe" }
& $ssh @args
exit $LASTEXITCODE
PS1
}

# 3) 生成 WSL 侧 win-ssh 包装脚本（写入 $1 指定路径）
write_wsl_wrapper() {
	local target="${1:-$WSL_SSH_PATH}"
	mkdir -p "$(dirname "$target")"
	cat >"$target" <<EOF
#!/usr/bin/env sh
exec $POWERSHELL_EXE -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$WIN_SSH_PS1_PATH_WIN" "\$@"
EOF
	chmod +x "$target"
}

# 用 case 分派写入函数，避免动态函数名调用（write_target "$fn"）的脆弱写法
# Dispatch the writer via case instead of a dynamic function name
write_target() {
	case "${1:-}" in
	win_ps1) write_win_ps1 "${2:-}" ;;
	wsl_wrapper) write_wsl_wrapper "${2:-}" ;;
	*) err "未知写入目标 / unknown write target: ${1:-}"; return 1 ;;
	esac
}

# 写入：目标不存在则生成；存在且内容一致则跳过；不一致（或 FORCE=1）且用户同意时覆盖
ensure_file() {
	local f="${1:-}" fn="${2:-}" tmp
	if [ "$FORCE" = "1" ]; then
		step "写入 / Writing $f"
		write_target "$fn" "$f"
		ok "已生成 / Generated: $f"
		return 0
	fi
	if [ ! -f "$f" ]; then
		step "写入 / Writing $f"
		write_target "$fn" "$f"
		ok "已生成 / Generated: $f"
		return 0
	fi
	tmp="$(mktemp)" || return 1
	if ! write_target "$fn" "$tmp"; then
		rm -f "$tmp"
		err "写入临时文件失败 / failed to write temp file"
		return 1
	fi
	if diff -q "$tmp" "$f" >/dev/null 2>&1; then
		rm -f "$tmp"
		ok "已存在且内容一致，跳过 / Up to date: $f"
		return 0
	fi
	rm -f "$tmp"
	if confirm_install 1 "检测到 $f 内容不一致，覆盖？/ Content differs, overwrite?"; then
		step "覆盖 / Overwriting $f"
		write_target "$fn" "$f"
		ok "已更新 / Updated: $f"
	else
		warn "保留现有文件 / Keeping existing: $f"
	fi
}

ensure_file "$WIN_SSH_PS1_PATH" win_ps1
ensure_file "$WSL_SSH_PATH" wsl_wrapper

# 4) git 不再在此设置 GIT_SSH_COMMAND：chezmoi 管理的 ~/.gitconfig 已把 core.sshCommand 指向 win-ssh，
#    保证任意 shell（含非交互）下 git 均经 Windows OpenSSH agent 认证（详见 dot_gitconfig.tmpl）
#    GIT_SSH_COMMAND is no longer set here: chezmoi-managed ~/.gitconfig points core.sshCommand at win-ssh,
#    so git authenticates via the Windows OpenSSH agent in any shell (see dot_gitconfig.tmpl)

# 5) 自检（可选）
note "部署完成 / Deployment complete"
note "验证命令 / Verify with: git ls-remote <remote> HEAD"
if [ "${AUTO_YES:-0}" != "1" ] && confirm_install 0 "现在验证 GitHub 连通性（需 Windows agent 已注入密钥）？/ Verify GitHub connectivity now (requires a key injected into the Windows agent)?"; then
	# 注意：ssh -T git@github.com 认证成功时 GitHub 仍以退出码 1 结束（git 用户无 shell），
	# 所以不能按退出码判断，必须检测输出中的 "successfully authenticated"。
	# 另加 3 次重试，容忍代理节点的偶发抖动（偶发连接失败 rc=255）。
	attempt=0
	verified=1
	while [ "$attempt" -lt 3 ]; do
		attempt=$((attempt + 1))
		if "$WSL_SSH_PATH" -o BatchMode=yes -o ConnectTimeout=10 -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
			verified=0
			break
		fi
		if [ "$attempt" -lt 3 ]; then
			warn "GitHub 连接第 ${attempt} 次未通过，2 秒后重试… / attempt $attempt failed, retrying…"
			sleep 2
		fi
	done
	if [ "$verified" -eq 0 ]; then
		ok "GitHub SSH 转发验证通过 / GitHub SSH forwarding verified"
	else
		err "GitHub SSH 转发验证失败（请确认 KeePassXC 已解锁并注入密钥）"
		err "GitHub SSH forwarding failed (unlock KeePassXC and make sure the key is injected)"
		note "  转发已配置，但连通性验证未通过；请稍后手动验证 / forwarding configured but connectivity check failed; verify manually later"
	fi
fi

ok "SSH Agent 转发配置完成 / SSH agent forwarding configured"
