#!/bin/bash

# 脚本名称：setup_yazi_symlink.sh
# 功能：在 ~/.config 内创建 yazi 软链接，指向 com.cyanix.dotfiles/yazi
# 可在任意仓库位置运行

# 获取脚本所在目录（即 com.cyanix.dotfiles 根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 定义源目录（仓库中的 yazi 目录）
SOURCE_DIR="$SCRIPT_DIR/yazi"

# 定义目标目录（~/.config）和软链接名称（yazi）
CONFIG_DIR="$HOME/.config"
TARGET_LINK="$CONFIG_DIR/yazi"

# 检查源目录是否存在
if [ ! -d "$SOURCE_DIR" ]; then
  echo "错误：源目录 $SOURCE_DIR 不存在！请确保 yazi 目录在仓库根目录下。"
  exit 1
fi

# 确保 ~/.config 目录存在
if [ ! -d "$CONFIG_DIR" ]; then
  echo "创建 ~/.config 目录"
  mkdir -p "$CONFIG_DIR"
fi

# 检查目标软链接是否存在
if [ -e "$TARGET_LINK" ]; then
  # 如果目标是目录或文件但不是符号链接，备份
  if [ ! -L "$TARGET_LINK" ]; then
    echo "备份现有 $TARGET_LINK 到 $TARGET_LINK.bak"
    mv "$TARGET_LINK" "$TARGET_LINK.bak"
  else
    # 如果目标是符号链接，删除旧链接
    echo "删除旧符号链接 $TARGET_LINK"
    rm "$TARGET_LINK"
  fi
fi

# 创建符号链接
echo "创建软链接：$TARGET_LINK -> $SOURCE_DIR"
ln -s "$SOURCE_DIR" "$CONFIG_DIR"

# 验证符号链接
if [ -L "$TARGET_LINK" ] && [ "$(readlink -f "$TARGET_LINK")" = "$SOURCE_DIR" ]; then
  echo "成功：软链接已创建，$TARGET_LINK 指向 $SOURCE_DIR"
else
  echo "错误：软链接创建失败！请检查权限或路径。"
  exit 1
fi

# （可选）清空 Yazi 缓存以应用新配置
if command -v yazi >/dev/null 2>&1; then
  echo "清空 Yazi 缓存..."
  yazi --clear-cache
else
  echo "警告：未找到 Yazi 命令，可能未安装。"
fi
