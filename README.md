# Dotfiles

个人 dotfiles 配置仓库，使用 [Chezmoi](https://www.chezmoi.io/) 进行跨平台（Windows / Arch Linux）管理。

## 快速开始

```bash
# 1. 安装 chezmoi
scoop install chezmoi              # Windows
sudo pacman -S chezmoi             # Arch

# 2. 初始化（首次交互输入 Git 用户名/邮箱/编辑器/aria2 密钥）
chezmoi init Cyanix-0721 --apply
```

或用官方脚本一步到位（下载 + 初始化 + 应用，始终为最新版）：

```bash
sh -c "$(curl -fsLS https://get.chezmoi.io/lb)" -- init --apply Cyanix-0721
```

初始化时会询问以下变量（输入一次，持久化到 `~/.config/chezmoi/chezmoi.toml`）：

| 变量 | 说明 | 默认值 |
| ------ | ------ | -------- |
| `name` | Git 用户名 | 无（从 `git config user.name` 读取作为建议） |
| `email` | Git 邮箱 | 无（从 `git config user.email` 读取作为建议） |
| `editor` | 默认编辑器 | `nvim` |
| `aria2RpcSecret` | Aria2 RPC 密钥 | `1145141919810`（可回车跳过） |

> 之后需要改值：编辑 `~/.config/chezmoi/chezmoi.toml` 的 `[data]` 部分，再 `chezmoi apply`。

## 平台快速配置

```bash
# Windows（本机）
cd ~/.local/share/chezmoi
./scripts/windows-quickstart/00-main.ps1

# Arch Linux
cd ~/.local/share/chezmoi
./scripts/arch-quickstart/00-main.sh

# WSL（Debian 等）
cd ~/.local/share/chezmoi
./scripts/wsl-quickstart/00-main.sh
```

WSL quickstart 内置 Windows OpenSSH agent 转发（默认启用），让 git 的 SSH 直接调用 Windows 侧 `ssh.exe`（经 KeePassXC 注入的密钥），避免 WSL 侧无法桥接 Windows agent 的问题。脚本会生成 `~/bin/win-ssh` 与 Windows 侧 `.local/bin/win-ssh.ps1`，并在 `~/.bashrc` 注入 `GIT_SSH_COMMAND`。

交互式菜单，可选择安装：

- **系统基础**：包管理器（Scoop/pacman）、终端、字体、基础工具
- **开发工具**：Neovim、lazygit、GitHub CLI、uv、mise、shellcheck、ollama 等
- **常用软件**：浏览器、办公、媒体、备份等

## 主要配置

| 配置 | 说明 |
| ------ | ------ |
| `dot_gitconfig.tmpl` | Git 全局配置（delta diff、自动 push 上游、rebase autoStash 等） |
| `dot_wezterm.lua` | WezTerm 终端（GPU 加速、分屏、字体） |
| `dot_wslconfig` | WSL 资源限制（内存 10GB、6 核、镜像网络） |
| `dot_condarc` | Conda 镜像源 + 代理 |
| `dot_aria2/aria2.conf.tmpl` | Aria2 下载器（RPC 密钥由变量注入） |
| `private_dot_ssh/config.tmpl` | SSH 配置（github 直连，serv00 走代理） |
| `dot_config/fish/` / `powershell/` | Shell 配置（starship、zoxide、fzf、mise、yazi） |

## 辅助脚本

| 脚本 | 用途 |
| ------ | ------ |
| `scripts/rsync/rsync.py` | 通用文件同步（Linux/Windows 跨平台，基于 rsync） |
| `scripts/rename/batch_rename_images.py` | 批量重命名图片（按子文件夹前缀，支持名称/时间/大小排序） |
| `scripts/reflector/setup_reflector.sh` | Arch 镜像源自动更新（systemd timer） |
| `scripts/install_uv_dependencies.py` | uv 虚拟环境 + 依赖安装（占位，当前无第三方依赖） |

## 代码质量

VS Code 插件覆盖日常检查，无需额外安装命令行工具：

| 语言 | VS Code 插件 | 配置文件 |
| ------ | ------------- | --------- |
| Python | Ruff | `ruff.toml` |
| Bash | ShellCheck（需装 `scoop install shellcheck`） | — |
| PowerShell | 官方 PowerShell 插件（内置 PSScriptAnalyzer） | — |
| JSON/MD/YAML | Prettier | `.prettierrc` / `.prettierignore` |

CI（GitHub Actions）在每次 push/PR 自动校验：模板渲染、ruff、shellcheck、PSScriptAnalyzer。

## 相关

- [Chezmoi 文档](https://www.chezmoi.io/)
- [Conventional Commits](https://www.conventionalcommits.org/zh-hans/)（提交规范）
