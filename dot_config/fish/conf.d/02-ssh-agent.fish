# SSH代理配置 - 使用临时文件静默启动
if not set -q SSH_AUTH_SOCK
    ssh-agent -c | sed 's/^setenv/set -gx/' | source > /dev/null 2>&1
end
