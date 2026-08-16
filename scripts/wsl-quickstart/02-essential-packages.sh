#!/bin/bash

# 常用软件安装（Debian/Arch 同时存在且本机当前已装的交集，apt 幂等确保）
# Essential packages: intersection of Arch quickstart list and apt-available packages

set -e # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数
. "$SCRIPT_DIR/00-common.sh"

require_wsl "常用软件安装仅支持 WSL / Essential packages only install inside WSL"

header "常用软件安装 / Essential Packages"

# 启用自动确认（菜单 Run All 时传入 AUTO_YES=1）
init_auto_yes

# 与 arch-quickstart 相同、且当前系统已安装的包（Debian 命名）
# Packages present in the Arch quickstart that are also installed here today
step "安装常用命令行工具 / Installing command line tools"
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
	git \
	bat \
	eza \
	fastfetch \
	fzf \
	less \
	openssh-client \
	shfmt \
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

# 手动安装（官方脚本）工具的更新命令提示
# Update commands for manually-installed (official-script) tools
header "手动安装工具 / Manually-Installed Tools"
note "它们的更新命令 / Their update commands:"
note "  uv      → uv self update"
note "  opencode → opencode upgrade"
note "  chezmoi  → chezmoi upgrade"

ok "常用软件安装完成 / Essential packages installed"