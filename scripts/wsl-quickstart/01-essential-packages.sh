#!/bin/bash

# 常用软件安装（Debian/Arch 同时存在且仅使用 Debian stable 源，apt 幂等确保）
# Essential packages: intersection of Arch quickstart list and Debian stable packages
# 排除：GUI 桌面工具（WSL 无需）
#       ruff/yazi（Debian trixie 无对应包）
# fish 4：Debian stable 的 fish 为旧版 3.x，单独从 openSUSE 官方仓库安装
# fish 4: Debian stable ships old 3.x, installed separately from the openSUSE official repo

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
	git-delta \
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
	subversion \
	unzip \
	zoxide \
	podman \
	podman-compose
ok "命令行工具安装完成 / Command line tools installed"

step "安装 fish 4（openSUSE 官方仓库）/ Installing fish 4 (openSUSE official repo)"
if command -v fish >/dev/null 2>&1 && fish --version 2>/dev/null | grep -q 'version 4'; then
	ok "fish 4 已安装，跳过 / fish 4 already installed, skipping"
else
	echo 'deb http://download.opensuse.org/repositories/shells:/fish:/release:/4/Debian_13/ /' | sudo tee /etc/apt/sources.list.d/shells:fish:release:4.list >/dev/null
	curl -fsSL "https://download.opensuse.org/repositories/shells:/fish:/release:/4/Debian_13/Release.key" | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/shells_fish_release_4.gpg >/dev/null
	sudo apt-get update -qq
	sudo apt-get install -y fish
	ok "fish 4 安装完成 / fish 4 installed"
fi

# 将 fish 设为默认 shell（重新登录后生效）
# Set fish as the default shell (effective after re-login)
step "设置 fish 为默认 shell / Setting fish as the default shell"
if [ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v fish)" ]; then
	ok "默认 shell 已是 fish / fish is already the default shell"
else
	sudo chsh -s "$(command -v fish)" "$USER"
	ok "默认 shell 已设为 fish（重新登录生效）/ Default shell set to fish (effective after re-login)"
fi

# uv：使用官方安装脚本（而非 apt）
# uv: install via the official installer script
step "安装 uv（官方脚本）/ Installing uv (official installer)"
if command -v uv >/dev/null 2>&1; then
	ok "uv 已安装，跳过 / uv already installed, skipping"
else
	curl -LsSf https://astral.sh/uv/install.sh | sh
	ok "uv 安装完成（~/.local/bin/uv）/ uv installed (~/.local/bin/uv)"
fi

# fnm：使用官方安装脚本（Debian stable 无对应包）；fish 集成由 12-fnm.fish 提供，故始终 --skip-shell
# fnm: install via the official installer script; fish integration lives in 12-fnm.fish, always --skip-shell
step "安装 fnm（官方脚本）/ Installing fnm (official installer)"
if command -v fnm >/dev/null 2>&1 || [ -x "${XDG_DATA_HOME:-$HOME/.local/share}/fnm/fnm" ] || [ -x "$HOME/.fnm/fnm" ]; then
	ok "fnm 已安装，跳过 / fnm already installed, skipping"
else
	curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
	ok "fnm 安装完成 / fnm installed"
fi

# codex：使用官方独立安装器（原生 Rust 二进制，无需 Node）
# codex: install via the official standalone installer (native Rust binary, no Node needed)
step "安装 codex（官方独立安装器）/ Installing codex (official standalone installer)"
if command -v codex >/dev/null 2>&1; then
	ok "codex 已安装，跳过 / codex already installed, skipping"
else
	curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
	ok "codex 安装完成（~/.local/bin/codex，数据在 ~/.codex）/ codex installed (~/.local/bin/codex, data in ~/.codex)"
fi

# 手动安装（官方脚本）工具的更新命令提示
# Update commands for manually-installed (official-script) tools
header "手动安装工具 / Manually-Installed Tools"
note "它们的更新命令 / Their update commands:"
note "  chezmoi  → chezmoi upgrade"
note "  uv      → uv self update"
note "  fnm     → fnm self install"
note "  codex   → codex update（或重跑 install.sh）/ codex update (or re-run install.sh)"

ok "常用软件安装完成 / Essential packages installed"
