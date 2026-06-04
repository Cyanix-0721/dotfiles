# 基础环境变量配置
set -Ux EDITOR nvim
set -Ux BROWSER zen-browser
set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"

# 添加本地bin目录到PATH
fish_add_path ~/.local/bin
