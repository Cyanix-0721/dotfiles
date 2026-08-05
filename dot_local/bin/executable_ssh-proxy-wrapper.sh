#!/bin/bash
# SSH 动态代理选择脚本 (Linux)
# 代理来源优先级：
#   1. CLASH_SOCKS_PORT（显式指定 SOCKS 端口）
#   2. 当前 shell 环境变量的代理 (ALL_PROXY > HTTPS_PROXY > HTTP_PROXY，含小写，兼容各 shell)
#   3. 回退 127.0.0.1:7898
# 代理可用则走代理，否则直连

HOST=$1
PORT=$2

# 默认回退地址
PROXY_HOST="127.0.0.1"
PROXY_PORT="7898"
PROXY_TYPE="socks5"

# 1. 显式指定的 SOCKS 端口
if [ -n "$CLASH_SOCKS_PORT" ]; then
    PROXY_PORT="$CLASH_SOCKS_PORT"
else
    # 2. 从 shell 环境变量解析代理
    PROXY_URL=""
    for var in ALL_PROXY HTTPS_PROXY HTTP_PROXY all_proxy https_proxy http_proxy; do
        val="${!var}"
        if [ -n "$val" ]; then
            PROXY_URL="$val"
            break
        fi
    done

    if [ -n "$PROXY_URL" ]; then
        # 按 scheme 判断代理类型
        case "$PROXY_URL" in
            socks5://* | socks://*) PROXY_TYPE="socks5" ;;
            http://*) PROXY_TYPE="http" ;;
        esac
        # 去掉 scheme 与路径，取出 host[:port]
        PROXY_URL="${PROXY_URL#*://}"
        PROXY_URL="${PROXY_URL%%/*}"
        if [[ "$PROXY_URL" == *:* ]]; then
            PROXY_HOST="${PROXY_URL%:*}"
            PROXY_PORT="${PROXY_URL##*:}"
        else
            PROXY_HOST="$PROXY_URL"
        fi
    fi
fi

# 代理可用则走代理，否则直连
if timeout 1 bash -c "echo >/dev/tcp/$PROXY_HOST/$PROXY_PORT" 2>/dev/null; then
    exec ncat --proxy "$PROXY_HOST:$PROXY_PORT" --proxy-type "$PROXY_TYPE" "$HOST" "$PORT"
fi

# 不可用，直连
exec nc -X none "$HOST" "$PORT"
