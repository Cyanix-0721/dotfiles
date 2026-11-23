#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数
# shellcheck source=00-common.sh
. "$SCRIPT_DIR/00-common.sh"

# 运行环境校验（DRY_RUN=1 时跳过）
require_arch "中文本地化配置仅支持在 Arch Linux 中运行 / Chinese localization setup only runs on Arch Linux"
require_non_root_with_sudo

# 自动确认模式（仅自动确认默认 Y/n 推荐项）
init_auto_yes

header "中文本地化配置 / Chinese Localization"

# 安装中文字体 / Install Chinese fonts
step "安装中文字体 / Installing Chinese fonts"
if qs_run_cmd sudo pacman -S --needed --noconfirm \
	adobe-source-han-sans-cn-fonts \
	adobe-source-han-serif-cn-fonts \
	noto-fonts-cjk \
	noto-fonts-emoji \
	wqy-microhei \
	wqy-microhei-lite \
	wqy-bitmapfont \
	wqy-zenhei \
	ttf-arphic-ukai \
	ttf-arphic-uming \
	ttf-jetbrains-mono \
	ttf-jetbrains-mono-nerd \
	ttf-sarasa-gothic; then
	ok "中文字体安装完成 / Chinese fonts installed"
else
	err "中文字体安装失败 / Failed to install Chinese fonts"
	add_failure "中文字体安装"
fi

# 清除字体缓存 / Clear font cache
step "刷新字体缓存 / Refreshing font cache"
if qs_run_cmd fc-cache -fv; then
	ok "字体缓存刷新完成 / Font cache refreshed"
else
	err "刷新字体缓存失败 / Failed to refresh font cache"
	add_failure "fc-cache 刷新"
fi

# 安装输入法 / Install input method
step "安装输入法 / Installing input method"
if qs_run_cmd sudo pacman -S --needed --noconfirm fcitx5-im fcitx5-rime fcitx5-chinese-addons; then
	ok "Fcitx5 基础包安装完成 / Fcitx5 base packages installed"
else
	err "Fcitx5 基础包安装失败 / Failed to install Fcitx5 base packages"
	add_failure "Fcitx5 基础包安装"
fi

# 检测并安装 rime-wanxiang-pinyin / Detect and install rime-wanxiang-pinyin
step "检测 rime-wanxiang-pinyin 安装方式 / Detecting installation method"
if [ "${DRY_RUN:-0}" = "1" ]; then
	note "[dry-run] 检测并安装 rime-wanxiang-pinyin（优先官方/archlinuxcn，其次 paru/yay）"
elif pacman -Si rime-wanxiang-pinyin &>/dev/null; then
	step "从官方/ArchlinuxCN 仓库安装 rime-wanxiang-pinyin / Installing from repo"
	if ! qs_run_cmd sudo pacman -S --needed --noconfirm rime-wanxiang-pinyin; then
		err "安装 rime-wanxiang-pinyin 失败 / Failed to install rime-wanxiang-pinyin"
		add_failure "rime-wanxiang-pinyin (pacman)"
	fi
elif command -v paru &>/dev/null && paru -Si rime-wanxiang-pinyin &>/dev/null; then
	step "从 AUR 安装 rime-wanxiang-pinyin / Installing from AUR (paru)"
	if ! qs_run_cmd paru -S --needed --noconfirm rime-wanxiang-pinyin; then
		err "安装 rime-wanxiang-pinyin 失败 / Failed to install rime-wanxiang-pinyin (paru)"
		add_failure "rime-wanxiang-pinyin (paru)"
	fi
elif command -v yay &>/dev/null && yay -Si rime-wanxiang-pinyin &>/dev/null; then
	step "从 AUR 安装 rime-wanxiang-pinyin / Installing from AUR (yay)"
	if ! qs_run_cmd yay -S --needed --noconfirm rime-wanxiang-pinyin; then
		err "安装 rime-wanxiang-pinyin 失败 / Failed to install rime-wanxiang-pinyin (yay)"
		add_failure "rime-wanxiang-pinyin (yay)"
	fi
else
	warn "无法安装 rime-wanxiang-pinyin；请确保已添加 archlinuxcn 或安装 AUR 助手"
	note "跳过 rime-wanxiang-pinyin 安装 / Skipping installation"
fi

ok "输入法安装步骤完成 / Input method step completed"

# 配置输入法环境变量（可选） / Configure input method environment variables (optional)
if confirm_install 0 "配置输入法环境变量？/ Configure input method env vars?"; then
	step "配置输入法环境变量 / Configuring input method env vars"

	env_dir="$HOME/.config/environment.d"
	fcitx_conf="$env_dir/fcitx.conf"
	fcitx_content="$(
		cat <<'EOF'
# 基础输入法环境变量
INPUT_METHOD=fcitx
XMODIFIERS=@im=fcitx

# 各框架输入法模块
# 注意：在 Wayland / niri 环境下，Fcitx5 原生支持 text-input 协议，
# 设置 GTK_IM_MODULE / QT_IM_MODULE 可能引起部分原生 Wayland 应用异常，请按需调整或注释。
QT_IM_MODULE=fcitx
GTK_IM_MODULE=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=fcitx
EOF
	)"

	if [ -f "$fcitx_conf" ] && cmp -s "$fcitx_conf" <(printf '%s\n' "$fcitx_content"); then
		ok "fcitx.conf 内容已一致，跳过写入 / fcitx.conf already up to date, skipping"
	elif [ "${DRY_RUN:-0}" = "1" ]; then
		if [ -f "$fcitx_conf" ]; then
			note "[dry-run] 备份现有 $fcitx_conf 并写入新配置"
		else
			note "[dry-run] 创建目录 $env_dir 并写入 $fcitx_conf"
		fi
	else
		mkdir -p "$env_dir"
		if [ -f "$fcitx_conf" ]; then
			backup_path="${fcitx_conf}.bak.$(date +%Y%m%d%H%M%S)"
			cp "$fcitx_conf" "$backup_path"
			note "已备份原配置: $backup_path / Backed up existing config"
		fi
		printf '%s\n' "$fcitx_content" >"$fcitx_conf"
		ok "输入法环境变量配置完成 / Env vars configured"
		note "配置文件：$fcitx_conf"
		note "重新登录或重启后生效 / Re-login or reboot to take effect"
	fi
else
	note "跳过输入法环境变量配置 / Skipping env vars configuration"
fi

header "中文本地化配置完成 / Chinese Localization Completed"
write_failure_summary
