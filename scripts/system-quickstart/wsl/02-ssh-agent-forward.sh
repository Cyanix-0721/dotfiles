#!/bin/bash

# 默认启用项：WSL → Windows OpenSSH agent（KeePassXC）SSH 转发
# 生成 win-ssh 包装脚本（WSL ~/bin 与 Windows .local/bin）；git 经 ~/.gitconfig 的 core.sshCommand 调用 win-ssh
# Default-enabled: forward WSL git SSH to the Windows OpenSSH agent (KeePassXC)
# git calls win-ssh via core.sshCommand in ~/.gitconfig (managed by chezmoi)

set -euo pipefail # 遇到错误立即退出；-u 未定义变量即报错；管道任一环节失败即视为失败

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数
. "$SCRIPT_DIR/00-common.sh"

# 解析 CLI 参数（--dry-run / --auto-yes / -h）
parse_wsl_args "$@"

require_wsl "SSH agent 转发仅支持 WSL / SSH agent forwarding only supports WSL"

header "SSH Agent 转发 / SSH Agent Forwarding"

# 启用自动确认（菜单 Run All 时传入 AUTO_YES=1）
init_auto_yes

# 本机/目标主机都已存在包装脚本时，默认不再重复写入；可传 FORCE=1 强制覆盖
: "${FORCE:=0}"

# 临时文件清理（异常退出/中断时自动删除 mktemp 文件）
_TMP_FILES=()
cleanup_tmp_files() {
	if [ "${#_TMP_FILES[@]}" -gt 0 ]; then
		rm -f "${_TMP_FILES[@]}"
	fi
}
trap cleanup_tmp_files EXIT INT TERM

# POSIX sh 安全单引号转义（防止路径中的空格、$、`、\ 或单引号破坏包装脚本）
sh_single_quote() {
	local s="${1:-}"
	printf "'%s'" "${s//\'/\'\\\'\'}"
}

# 1) 解析 powershell.exe 与 Windows 用户目录（WSL 路径 / Windows 路径）
POWERSHELL_EXE="$(resolve_powershell_exe)" || {
	err "未找到 powershell.exe，无法配置 win-ssh 转发 / powershell.exe not found; cannot configure win-ssh forwarding"
	add_failure "resolve_powershell_exe"
	write_failure_summary || true
	exit 1
}

WIN_HOME="$(get_win_user_home)" || {
	err "无法解析 Windows 用户目录（需要从 WSL 调用 powershell.exe）"
	err "Cannot resolve Windows user profile (requires powershell.exe from WSL)"
	add_failure "get_win_user_home"
	write_failure_summary || true
	exit 1
}
note "Windows 用户目录 / Windows user profile: $WIN_HOME"

WIN_SSH_PS1_PATH="$WIN_HOME/.local/bin/win-ssh.ps1"
WIN_SSH_PS1_PATH_WIN=""
if command -v wslpath >/dev/null 2>&1; then
	WIN_SSH_PS1_PATH_WIN="$(wslpath -w "$WIN_SSH_PS1_PATH" 2>/dev/null || true)"
fi
if [ -z "$WIN_SSH_PS1_PATH_WIN" ]; then
	if [[ "$WIN_SSH_PS1_PATH" =~ ^/mnt/([A-Za-z])(/.*)$ ]]; then
		WIN_SSH_PS1_PATH_WIN="${BASH_REMATCH[1]^^}:${BASH_REMATCH[2]//\//\\}"
	else
		WIN_SSH_PS1_PATH_WIN="$WIN_SSH_PS1_PATH"
	fi
fi

WSL_SSH_PATH="$HOME/bin/win-ssh"

# 2) 渲染 Windows 侧 win-ssh.ps1 内容（仅 ASCII 注释，避免 Windows PowerShell 5.1 无 BOM UTF-8 乱码）
render_win_ps1() {
	cat <<'PS1'
Remove-Item Env:SSH_AUTH_SOCK -ErrorAction SilentlyContinue
# Prefer winget OpenSSH Preview in Program Files, then System32, then PATH
$ssh = @(
    "$env:ProgramFiles\OpenSSH\ssh.exe"
    "$env:SystemRoot\System32\OpenSSH\ssh.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ssh) { $ssh = "ssh.exe" }
try {
    $sshCmd = Get-Command $ssh -ErrorAction Stop
} catch {
    [Console]::Error.WriteLine("win-ssh.ps1: ssh executable not found: $ssh")
    exit 127
}
$global:LASTEXITCODE = $null
& $sshCmd.Source @args
if ($null -eq $LASTEXITCODE) {
    exit 127
}
exit $LASTEXITCODE
PS1
}

# 3) 渲染 WSL 侧 win-ssh 包装脚本内容（安全单引号包裹路径）
render_wsl_wrapper() {
	local ps_quoted win_ps1_quoted
	ps_quoted="$(sh_single_quote "$POWERSHELL_EXE")"
	win_ps1_quoted="$(sh_single_quote "$WIN_SSH_PS1_PATH_WIN")"
	cat <<EOF
#!/usr/bin/env sh
exec $ps_quoted -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $win_ps1_quoted "\$@"
EOF
}

# 用 case 分派渲染函数，避免动态函数名调用
render_target() {
	case "${1:-}" in
	win_ps1) render_win_ps1 ;;
	wsl_wrapper) render_wsl_wrapper ;;
	*)
		err "未知写入目标 / unknown write target: ${1:-}"
		return 1
		;;
	esac
}

# 写入目标文件（DRY_RUN=1 时只打印不落盘；wsl_wrapper 自动设置 +x）
write_target() {
	local fn="${1:-}" target="${2:-}"
	if [ "${DRY_RUN:-0}" = "1" ]; then
		qs_run_cmd mkdir -p "$(dirname "$target")"
		note "[dry-run] write $target ($fn)"
		if [ "$fn" = "wsl_wrapper" ]; then
			qs_run_cmd chmod +x "$target"
		fi
		return 0
	fi
	mkdir -p "$(dirname "$target")"
	render_target "$fn" >"$target"
	if [ "$fn" = "wsl_wrapper" ]; then
		chmod +x "$target"
	fi
}

# 写入：目标不存在则生成；存在且内容一致则跳过（wsl_wrapper 同步确保 +x）；不一致（或 FORCE=1）且用户同意时覆盖
ensure_file() {
	local f="${1:-}" fn="${2:-}" tmp=""
	if [ "$FORCE" = "1" ]; then
		step "写入 / Writing $f"
		if write_target "$fn" "$f"; then
			ok "已生成 / Generated: $f"
			return 0
		fi
		err "写入失败 / Failed to write: $f"
		return 1
	fi
	if [ ! -f "$f" ]; then
		step "写入 / Writing $f"
		if write_target "$fn" "$f"; then
			ok "已生成 / Generated: $f"
			return 0
		fi
		err "写入失败 / Failed to write: $f"
		return 1
	fi
	tmp="$(mktemp)" || return 1
	_TMP_FILES+=("$tmp")
	if ! render_target "$fn" >"$tmp"; then
		rm -f "$tmp"
		err "写入临时文件失败 / failed to write temp file"
		return 1
	fi
	if diff -q "$tmp" "$f" >/dev/null 2>&1; then
		rm -f "$tmp"
		if [ "$fn" = "wsl_wrapper" ] && [ ! -x "$f" ]; then
			if qs_run_cmd chmod +x "$f"; then
				ok "已修复可执行权限 / Restored executable bit: $f"
				return 0
			fi
			err "设置可执行权限失败 / Failed to chmod +x: $f"
			return 1
		fi
		ok "已存在且内容一致，跳过 / Up to date: $f"
		return 0
	fi
	rm -f "$tmp"
	if confirm_install 1 "检测到 $f 内容不一致，覆盖？/ Content differs, overwrite?"; then
		step "覆盖 / Overwriting $f"
		if write_target "$fn" "$f"; then
			ok "已更新 / Updated: $f"
			return 0
		fi
		err "覆盖失败 / Failed to overwrite: $f"
		return 1
	else
		warn "保留现有文件 / Keeping existing: $f"
	fi
}

ensure_file "$WIN_SSH_PS1_PATH" win_ps1 || add_failure "write $WIN_SSH_PS1_PATH"
ensure_file "$WSL_SSH_PATH" wsl_wrapper || add_failure "write $WSL_SSH_PATH"

# 4) git 不再在此设置 GIT_SSH_COMMAND：chezmoi 管理的 ~/.gitconfig 已把 core.sshCommand 指向 win-ssh，
#    保证任意 shell（含非交互）下 git 均经 Windows OpenSSH agent 认证（详见 dot_gitconfig.tmpl）
#    GIT_SSH_COMMAND is no longer set here: chezmoi-managed ~/.gitconfig points core.sshCommand at win-ssh,
#    so git authenticates via the Windows OpenSSH agent in any shell (see dot_gitconfig.tmpl)

# 5) 自检（可选）
note "部署完成 / Deployment complete"
note "验证命令 / Verify with: git ls-remote <remote> HEAD"
if [ "${DRY_RUN:-0}" = "1" ]; then
	note "[dry-run] 跳过 GitHub SSH 连通性实测 / Skipping live GitHub SSH connectivity check"
elif confirm_install 0 "现在验证 GitHub 连通性（需 Windows agent 已注入密钥）？/ Verify GitHub connectivity now (requires a key injected into the Windows agent)?"; then
	# 注意：ssh -T git@github.com 认证成功时 GitHub 仍以退出码 1 结束（git 用户无 shell），
	# 在 pipefail 下不可直接管道给 grep，须先捕获输出再匹配 "successfully authenticated"。
	# 另加 3 次重试，容忍代理节点的偶发抖动（偶发连接失败 rc=255）。
	attempt=0
	verified=1
	while [ "$attempt" -lt 3 ]; do
		attempt=$((attempt + 1))
		out="$("$WSL_SSH_PATH" -o BatchMode=yes -o ConnectTimeout=10 -T git@github.com 2>&1 || true)"
		if grep -q "successfully authenticated" <<<"$out"; then
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
		add_failure "GitHub SSH connectivity check"
	fi
fi

if ! write_failure_summary; then
	exit 1
fi

ok "SSH Agent 转发配置完成 / SSH agent forwarding configured"
