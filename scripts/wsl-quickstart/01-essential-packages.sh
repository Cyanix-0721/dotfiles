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
	bubblewrap \
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

# Node.js：可选安装最新 LTS（默认否）；AUTO_YES 时安装最新 LTS 并设为全局默认
# Node.js: optionally install latest LTS (default no); AUTO_YES installs latest LTS and sets it as global default
step "安装 Node.js LTS（fnm）/ Installing Node.js LTS (fnm)"
export PATH="${XDG_DATA_HOME:-$HOME/.local/share}/fnm:$HOME/.fnm:$PATH"
if command -v fnm >/dev/null 2>&1; then
	# 本次会话加载 fnm（fish 集成由 12-fnm.fish 提供）
	# Load fnm for this session (fish integration lives in 12-fnm.fish)
	eval "$(fnm env --use-on-cd --shell bash)"
	# 询问是否安装最新 LTS（默认否，回车跳过）；按项目切换由 12-fnm.fish 的 --use-on-cd 提供（读取 .node-version / .nvmrc）
	# Ask whether to install latest LTS (default no); per-project switching handled by --use-on-cd in 12-fnm.fish (.node-version / .nvmrc)
	if confirm_install 0 "是否安装最新 LTS Node.js？(y/N) / Install latest LTS Node.js?"; then
		fnm install --lts
		ok "最新 LTS Node.js 安装完成 / Latest LTS Node.js installed"
		# 默认非全局；是否设为全局默认同样可选（AUTO_YES 时自动设为全局默认）
		# Global default is off by default; setting it is also optional (AUTO_YES sets it automatically)
		if confirm_install 0 "是否将最新 LTS 设为全局默认？(y/N) / Set latest LTS as global default?"; then
			lts_version="$(fnm list 2>/dev/null | grep 'lts-latest' | head -n1 | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
			if [ -n "$lts_version" ]; then
				fnm default "$lts_version"
				ok "已将 Node.js $lts_version 设为全局默认 / Node.js $lts_version set as global default"
			else
				warn "未能识别 LTS 版本，跳过设为全局默认 / Could not identify LTS version, skipping global default"
			fi
		fi
	fi
else
	warn "fnm 不可用，跳过 Node.js 安装 / fnm unavailable, skipping Node.js install"
fi

# pnpm：官方 standalone 脚本安装（pnpm 自身无需 Node；运行 JS 项目/DSH 仍需上面的 Node）
# pnpm: official standalone installer (pnpm itself needs no Node; running JS/DSH still needs Node above)
step "安装 pnpm（官方脚本）/ Installing pnpm (official installer)"
if command -v pnpm >/dev/null 2>&1; then
	ok "pnpm 已安装，跳过 / pnpm already installed, skipping"
else
	# glibc 构建需要 libatomic.so.1（WSL 完整发行版通常已含，缺失时补装）
	# The glibc build needs libatomic.so.1 (normally present on full distros; install if missing)
	sudo apt-get install -y --no-install-recommends libatomic1 >/dev/null 2>&1 || true
	curl -fsSL https://get.pnpm.io/install.sh | sh -
	# standalone 默认装到 ~/.local/share/pnpm；本次会话立即可用，fish 侧由 01-env.fish 的 fish_add_path 提供
	# Default install dir is ~/.local/share/pnpm; exported for this session, fish PATH comes from 01-env.fish
	export PATH="$HOME/.local/share/pnpm:$PATH"
	ok "pnpm 安装完成（~/.local/share/pnpm）/ pnpm installed (~/.local/share/pnpm)"
fi

# mise：使用官方安装脚本（mise.run，自带 self-update）
# mise: install via the official installer (mise.run, with self-update)
step "安装 mise（官方安装脚本）/ Installing mise (official installer)"
if command -v mise >/dev/null 2>&1; then
	ok "mise 已安装，跳过 / mise already installed, skipping"
else
	curl https://mise.run | sh
	ok "mise 安装完成（~/.local/bin/mise）/ mise installed (~/.local/bin/mise)"
fi

# bash 激活：官方推荐写法，追加到 ~/.bashrc（幂等）
# bash activation: official recommended line, appended to ~/.bashrc (idempotent)
# fish 激活由 chezmoi 管理的 dot_config/fish/conf.d/11-mise.fish 提供，这里无需重复
# fish activation is provided by the chezmoi-managed dot_config/fish/conf.d/11-mise.fish
step "配置 mise bash 激活 / Configuring mise bash activation"
MISE_ACT_BASH='eval "$(mise activate bash)"'
BASHRC="$HOME/.bashrc"
if [ -f "$BASHRC" ] && grep -qF "$MISE_ACT_BASH" "$BASHRC"; then
	ok "bash 已配置 mise 激活 / bash already has mise activation"
else
	printf '\n# mise activate (added by wsl-quickstart)\n%s\n' "$MISE_ACT_BASH" >> "$BASHRC"
	ok "已追加 mise 激活行到 ~/.bashrc / mise activation appended to ~/.bashrc"
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
note "  mise    → mise self-update"
note "  codex   → codex update（或重跑 install.sh）/ codex update (or re-run install.sh)"

ok "常用软件安装完成 / Essential packages installed"
