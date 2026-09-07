# Dotfiles

个人 dotfiles 配置仓库，使用 [Chezmoi](https://www.chezmoi.io/) 进行跨平台（Windows / Arch Linux / WSL Debian）管理。

> 本文档面向**使用者**（部署与日常使用）。AI 助手与维护者请阅读 [AGENTS.md](./AGENTS.md)：仓库内部机制、平台生效规则、模板与改动规范都在那里。

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

WSL quickstart 默认启用 **Windows OpenSSH agent 转发（win-ssh）**：WSL 内 git 借助 Windows OpenSSH agent（KeePassXC 注入的密钥）完成认证，接线由 chezmoi 模板 `dot_gitconfig.tmpl` 自动完成（检测到 `WSL_DISTRO_NAME` 时写入 `core.sshCommand = ~/bin/win-ssh`）。机制细节与排查见 [AGENTS.md](./AGENTS.md)「机制说明：WSL git SSH 转发」。

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
| `scripts/rsync/rsync.py` | 通用文件同步（Linux/Windows 跨平台，rsync 驱动，在 Linux 端执行；用法见 `scripts/rsync/README.md`） |
| `scripts/rename/batch_rename_images.py` | 批量重命名图片（按子文件夹前缀，支持名称/时间/大小排序） |
| `scripts/rename/batch_pack_cbz.py` | 图片文件夹打包为 CBZ 漫画（自动推导目录结构、生成 ComicInfo.xml，依赖 Pillow） |
| `scripts/reflector/setup_reflector.sh` | Arch 镜像源自动更新（systemd timer） |
| `scripts/install_uv_dependencies.py` | 按 `scripts/.python-version`（3.14）用 uv 建虚拟环境并安装 `requirements*.txt` 依赖（当前为 Pillow） |

## 代码质量

push/PR 由 GitHub Actions（`.github/workflows/ci.yml`）自动校验：模板渲染、ruff、shellcheck、PSScriptAnalyzer。本地自测命令、编辑器插件与维护规范见 [AGENTS.md](./AGENTS.md)「代码质量」。

## 相关

- [AGENTS.md](./AGENTS.md) — 面向 AI 助手与维护者的仓库内部规范
- [Chezmoi 文档](https://www.chezmoi.io/)
- [Conventional Commits](https://www.conventionalcommits.org/zh-hans/)（提交规范）
