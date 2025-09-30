#!/bin/bash

set -e

echo "=== 中文本地化配置 ==="

# 安装中文字体
echo "安装中文字体..."
sudo pacman -S --noconfirm adobe-source-han-sans-cn-fonts adobe-source-han-serif-cn-fonts noto-fonts-cjk noto-fonts-emoji wqy-microhei wqy-microhei-lite wqy-bitmapfont wqy-zenhei ttf-arphic-ukai ttf-arphic-uming ttf-jetbrains-mono ttf-jetbrains-mono-nerd ttf-sarasa-gothic
echo "✓ 中文字体安装完成"

# 清除字体缓存
echo "清除字体缓存..."
fc-cache -fv
echo "✓ 字体缓存清除完成"

# 安装输入法
echo "安装输入法..."
sudo pacman -S --noconfirm fcitx5-im fcitx5-rime fcitx5-chinese-addons
echo "✓ 输入法安装完成"

# 配置输入法环境变量
echo "配置输入法环境变量..."
if ! sudo grep -q "GTK_IM_MODULE=fcitx" /etc/environment; then
    echo -e "\nexport GTK_IM_MODULE=fcitx\nexport QT_IM_MODULE=fcitx\nexport XMODIFIERS=@im=fcitx" | sudo tee -a /etc/environment > /dev/null
    echo "✓ 输入法环境变量配置完成"
else
    echo "✓ 输入法环境变量已配置，跳过"
fi

# 安装万象拼音方案
echo "安装万象拼音方案..."
sudo pacman -S --noconfirm rime-wanxiang-pinyin
echo "✓ 万象拼音方案安装完成"

echo "注意: 中文本地化配置可能需要重新启动才能完全生效"
