# 基础环境变量配置
set -Ux EDITOR nvim
set -Ux BROWSER zen-browser
set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"

# 添加本地bin目录到PATH
fish_add_path ~/.local/bin

# 动态配置代理（如果可用）
function __setup_proxy --description "Setup proxy if available"
  set -l proxy_addr "127.0.0.1"
  set -l proxy_port 7897
  set -l proxy_url "http://$proxy_addr:$proxy_port"
  
  # 使用 nc 检查端口
  if command -v nc &>/dev/null
    if nc -z $proxy_addr $proxy_port 2>/dev/null
      set -gx http_proxy $proxy_url
      set -gx https_proxy $proxy_url
    end
  # 备选：使用 timeout
  else if command -v timeout &>/dev/null
    timeout 1 bash -c "echo >/dev/tcp/$proxy_addr/$proxy_port" 2>/dev/null
    if test $status -eq 0
      set -gx http_proxy $proxy_url
      set -gx https_proxy $proxy_url
    end
  end
end

__setup_proxy
