#!/bin/bash
# SSH 动态代理选择脚本 (Linux)
# 检查 Clash SOCKS5 代理 (127.0.0.1:7898)，有就用，没有就直连

HOST=$1
PORT=$2

# 检查 Clash SOCKS5 代理
if timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/7898" 2>/dev/null; then
  exec ncat --proxy 127.0.0.1:7898 --proxy-type socks5 "$HOST" "$PORT"
fi

# 不可用，直连
exec nc -X none "$HOST" "$PORT"
