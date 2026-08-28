# 基础环境变量配置
set -Ux EDITOR nvim
set -Ux BROWSER zen-browser
set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"

# 添加本地二进制目录到 PATH（用户级工具，如 uv、codex 的安装位置）
fish_add_path ~/.local/bin

# fnm 默认安装目录（官方安装脚本）：优先 $XDG_DATA_HOME/fnm，未定义时回退 ~/.local/share/fnm
# fish_add_path 会自动跳过不存在的目录，故两条同时添加是安全的
fish_add_path "$XDG_DATA_HOME/fnm"
fish_add_path ~/.local/share/fnm
