#!/bin/bash

# SSH 目录权限设置脚本
# 安全地设置 ~/.ssh 目录及其文件的权限

set -e # 遇到错误立即退出

SSH_DIR="$HOME/.ssh"

echo "正在设置 SSH 目录权限..."

# 检查 SSH 目录是否存在
if [ ! -d "$SSH_DIR" ]; then
  echo "错误: SSH 目录不存在: $SSH_DIR"
  exit 1
fi

# 设置 SSH 目录权限为 700 (drwx------)
chmod 700 "$SSH_DIR"
echo "✓ 设置目录权限: $SSH_DIR -> 700"

# 设置文件权限
for file in "$SSH_DIR"/*; do
  if [ -f "$file" ]; then
    case "$(basename "$file")" in
    # 配置文件设置为 600 (-rw-------)
    "config" | "known_hosts" | "known_hosts.old" | "authorized_keys")
      chmod 600 "$file"
      echo "✓ 设置文件权限: $(basename "$file") -> 600"
      ;;
    # 公钥文件设置为 644 (-rw-r--r--)
    *.pub)
      chmod 644 "$file"
      echo "✓ 设置文件权限: $(basename "$file") -> 644"
      ;;
    # 私钥文件设置为 600 (-rw-------)
    id_*)
      if [[ "$file" != *.pub ]]; then
        chmod 600 "$file"
        echo "✓ 设置文件权限: $(basename "$file") -> 600"
      fi
      ;;
    # 其他文件设置为 600
    *)
      chmod 600 "$file"
      echo "✓ 设置文件权限: $(basename "$file") -> 600"
      ;;
    esac
  fi
done

# 设置目录所有权（确保属于当前用户）
chown -R "$USER:$USER" "$SSH_DIR"
echo "✓ 设置目录所有权: $USER:$USER"

echo ""
echo "✅ SSH 目录权限设置完成！"
echo "当前权限状态:"
ls -la "$SSH_DIR"
