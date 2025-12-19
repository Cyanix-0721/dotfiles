#!/bin/bash

set -e

echo "=== 中文本地化配置 / Chinese Localization Configuration ==="

# 安装中文字体 / Install Chinese fonts
echo "安装中文字体… / Installing Chinese fonts…"
sudo pacman -S --noconfirm adobe-source-han-sans-cn-fonts adobe-source-han-serif-cn-fonts noto-fonts-cjk noto-fonts-emoji wqy-microhei wqy-microhei-lite wqy-bitmapfont wqy-zenhei ttf-arphic-ukai ttf-arphic-uming ttf-jetbrains-mono ttf-jetbrains-mono-nerd ttf-sarasa-gothic
echo "✓ 中文字体安装完成 / ✓ Chinese fonts installation completed"

# 清除字体缓存 / Clear font cache
echo "清除字体缓存… / Clearing font cache…"
fc-cache -fv
echo "✓ 字体缓存清除完成 / ✓ Font cache cleared"

# 安装输入法 / Install input method
echo "安装输入法… / Installing input method…"
sudo pacman -S --noconfirm fcitx5-im fcitx5-rime fcitx5-chinese-addons

# 检测并安装 rime-wanxiang-pinyin / Detect and install rime-wanxiang-pinyin
echo "检测 rime-wanxiang-pinyin 安装方式… / Detecting installation method for rime-wanxiang-pinyin…"
if pacman -Si rime-wanxiang-pinyin &>/dev/null; then
	# 从官方仓库安装 / Install from official repository
	echo "从官方仓库安装 rime-wanxiang-pinyin… / Installing rime-wanxiang-pinyin from official repository…"
	sudo pacman -S --noconfirm rime-wanxiang-pinyin
elif command -v paru &>/dev/null && paru -Si rime-wanxiang-pinyin &>/dev/null; then
	# 从 AUR 安装 / Install from AUR
	echo "从 AUR 安装 rime-wanxiang-pinyin… / Installing rime-wanxiang-pinyin from AUR…"
	paru -S --noconfirm rime-wanxiang-pinyin
elif command -v yay &>/dev/null && yay -Si rime-wanxiang-pinyin &>/dev/null; then
	# 从 AUR 安装 / Install from AUR
	echo "从 AUR 安装 rime-wanxiang-pinyin… / Installing rime-wanxiang-pinyin from AUR…"
	yay -S --noconfirm rime-wanxiang-pinyin
else
	echo "警告: 无法安装 rime-wanxiang-pinyin，请确保已添加 archlinuxcn 仓库或安装 AUR 助手 / Warning: Cannot install rime-wanxiang-pinyin, please ensure archlinuxcn repository is added or AUR helper is installed"
	echo "跳过 rime-wanxiang-pinyin 安装 / Skipping rime-wanxiang-pinyin installation"
fi

echo "✓ 输入法安装完成 / ✓ Input method installation completed"

# 配置输入法环境变量（可选） / Configure input method environment variables (optional)
read -p "是否配置输入法环境变量？(y/N) / Configure input method environment variables? (y/N): " -r configure_im

if [[ "$configure_im" =~ ^[Yy]$ ]]; then
	echo "配置输入法环境变量… / Configuring input method environment variables…"

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

	echo "✓ 输入法环境变量配置完成 / ✓ Input method environment variables configured"
	echo "配置文件位置：~/.config/environment.d/fcitx.conf"
	echo "注意：需要重新登录或重启系统才能使环境变量生效 / Note: You need to re-login or reboot for environment variables to take effect"
else
	echo "✓ 跳过输入法环境变量配置 / ✓ Skipping input method environment variables configuration"
fi

echo "=== 中文本地化配置完成 / Chinese Localization Configuration Completed ==="
