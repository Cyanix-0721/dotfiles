#!/bin/bash

# 常用软件安装（Debian/Arch 同时存在且仅使用 Debian stable 源，apt 幂等确保）
# Essential packages: intersection of Arch quickstart list and Debian stable packages
# 排除：GUI 桌面工具（WSL 无需）、podman/podman-compose（暂不选用容器方案）、
#       ruff/yazi（Debian trixie 无对应包）

set -e # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数
. "$SCRIPT_DIR/00-common.sh"

require_wsl "常用软件安装仅支持 WSL / Essential packages only install inside WSL"

header "常用软件安装 / Essential Packages"

# 启用自动确认（菜单 Run All 时传入 AUTO_YES=1）
init_auto_yes

# 与 arch-quickstart 相同、且 Debian stable 中存在的常用包（Debian 命名）
# Common packages from the Arch quickstart that exist in Debian stable
step "安装常用命令行工具 / Installing command line tools"
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
	7zip \
	bat \
	btop \
	delta \
	eza \
	fastfetch \
	fd-find \
	ffmpeg \
	fzf \
	gh \
	git \
	imagemagick \
	jq \
	lazygit \
	less \
	neovim \
	nmap \
	openssh-client \
	poppler-utils \
	ripgrep \
	shfmt \
	starship \
	zoxide
ok "命令行工具安装完成 / Command line tools installed"

# uv：使用官方安装脚本（而非 apt）
# uv: install via the official installer script
step "安装 uv（官方脚本）/ Installing uv (official installer)"
if command -v uv >/dev/null 2>&1; then
	ok "uv 已安装，跳过 / uv already installed, skipping"
else
	curl -LsSf https://astral.sh/uv/install.sh | sh
	ok "uv 安装完成（~/.local/bin/uv）/ uv installed (~/.local/bin/uv)"
fi

# opencode：使用官方安装脚本（而非 apt）
# opencode: install via the official installer script
step "安装 opencode（官方脚本）/ Installing opencode (official installer)"
if command -v opencode >/dev/null 2>&1; then
	ok "opencode 已安装，跳过 / opencode already installed, skipping"
else
	curl -fsSL https://opencode.ai/install | bash
	ok "opencode 安装完成（~/.opencode/bin/opencode）/ opencode installed (~/.opencode/bin/opencode)"
fi

# 手动安装（官方脚本）工具的更新命令提示
# Update commands for manually-installed (official-script) tools
header "手动安装工具 / Manually-Installed Tools"
note "它们的更新命令 / Their update commands:"
note "  uv      → uv self update"
note "  opencode → opencode upgrade"
note "  chezmoi  → chezmoi upgrade"

ok "常用软件安装完成 / Essential packages installed"
