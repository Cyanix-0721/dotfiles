#!/bin/bash

set -e

# 统一日志输出样式（仅影响提示，不改变脚本行为）
if [ -t 1 ]; then
	RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m";
	RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; BLUE="\033[34m"; CYAN="\033[36m";
else
	RESET=""; BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN="";
fi

header() { printf "\n%s%s==> %s%s\n" "$BOLD" "$BLUE" "$1" "$RESET"; }
step()   { printf "%s→ %s…%s\n" "$CYAN" "$1" "$RESET"; }
ok()     { printf "%s✓ %s%s\n" "$GREEN" "$1" "$RESET"; }
warn()   { printf "%s⚠ %s%s\n" "$YELLOW" "$1" "$RESET"; }
err()    { printf "%s✗ %s%s\n" "$RED" "$1" "$RESET"; }
note()   { printf "%s∙ %s%s\n" "$DIM" "$1" "$RESET"; }

header "中文本地化配置 / Chinese Localization"

# 安装中文字体 / Install Chinese fonts
step "安装中文字体 / Installing Chinese fonts"
sudo pacman -S --noconfirm adobe-source-han-sans-cn-fonts adobe-source-han-serif-cn-fonts noto-fonts-cjk noto-fonts-emoji wqy-microhei wqy-microhei-lite wqy-bitmapfont wqy-zenhei ttf-arphic-ukai ttf-arphic-uming ttf-jetbrains-mono ttf-jetbrains-mono-nerd ttf-sarasa-gothic
ok "中文字体安装完成 / Chinese fonts installed"

# 清除字体缓存 / Clear font cache
step "清除字体缓存 / Clearing font cache"
fc-cache -fv
ok "字体缓存清除完成 / Font cache cleared"

# 安装输入法 / Install input method
step "安装输入法 / Installing input method"
sudo pacman -S --noconfirm fcitx5-im fcitx5-rime fcitx5-chinese-addons

# 检测并安装 rime-wanxiang-pinyin / Detect and install rime-wanxiang-pinyin
step "检测 rime-wanxiang-pinyin 安装方式 / Detecting installation method"
if pacman -Si rime-wanxiang-pinyin &>/dev/null; then
	# 从官方仓库安装 / Install from official repository
	step "从官方仓库安装 rime-wanxiang-pinyin / Installing from official repo"
	sudo pacman -S --noconfirm rime-wanxiang-pinyin
elif command -v paru &>/dev/null && paru -Si rime-wanxiang-pinyin &>/dev/null; then
	# 从 AUR 安装 / Install from AUR
	step "从 AUR 安装 rime-wanxiang-pinyin / Installing from AUR (paru)"
	paru -S --noconfirm rime-wanxiang-pinyin
elif command -v yay &>/dev/null && yay -Si rime-wanxiang-pinyin &>/dev/null; then
	# 从 AUR 安装 / Install from AUR
	step "从 AUR 安装 rime-wanxiang-pinyin / Installing from AUR (yay)"
	yay -S --noconfirm rime-wanxiang-pinyin
else
	warn "无法安装 rime-wanxiang-pinyin；请确保已添加 archlinuxcn 或安装 AUR 助手"
	note "跳过 rime-wanxiang-pinyin 安装 / Skipping installation"
fi

ok "输入法安装完成 / Input method installed"

# 配置输入法环境变量（可选） / Configure input method environment variables (optional)
read -p "配置输入法环境变量？[y/N] / Configure input method env vars? [y/N]: " -r configure_im

if [[ "$configure_im" =~ ^[Yy]$ ]]; then
	step "配置输入法环境变量 / Configuring input method env vars"

	# 创建配置目录（如果不存在）
	mkdir -p ~/.config/environment.d

	# 创建输入法环境变量配置文件
	cat >~/.config/environment.d/fcitx.conf <<'EOF'
# 基础输入法环境变量
INPUT_METHOD=fcitx
XMODIFIERS=@im=fcitx

# 各框架输入法模块
QT_IM_MODULE=fcitx
GTK_IM_MODULE=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=fcitx
EOF

	ok "输入法环境变量配置完成 / Env vars configured"
	note "配置文件：~/.config/environment.d/fcitx.conf"
	note "重新登录或重启后生效 / Re-login or reboot to take effect"
else
	note "跳过输入法环境变量配置 / Skipping env vars configuration"
fi

header "中文本地化配置完成 / Chinese Localization Completed"
