# AGENTS

> **读者对象:AI 助手与仓库维护者。** 本文件回答「仓库**内部怎么运作**、改动怎样才安全」;「怎么安装部署、有哪些配置和脚本(功能清单)」见 [README.md](./README.md)。
> 本仓库是**个人真实环境配置**,改动会直接影响主目录,请以「可移植、可回滚、不破坏默认终端/系统行为」为原则:先理解,再动手,能不动就不动。

## 仓库概览

- 个人 dotfiles 配置仓库,使用 [Chezmoi](https://www.chezmoi.io/) 管理,覆盖 **Windows / Arch Linux / WSL Debian** 三套环境。本目录(`~/.local/share/chezmoi`)就是源仓库,chezmoi 将源文件渲染后同步到 `$HOME`。
- 远端:`git@github.com:Cyanix-0721/dotfiles.git`;CI:`.github/workflows/ci.yml`(push/PR 自动校验)。
- **文档分工**:各配置/脚本的用途以 README「主要配置 / 辅助脚本」为唯一清单;本文件只描述目录映射、平台生效规则、模板纪律与改动规范,同一事实不在两处重复维护。

## 目录结构

### 结构树(映射视角)

```
.chezmoi.toml.tmpl        init 生成 ~/.config/chezmoi/chezmoi.toml:
                          定义 [data] 变量(name/email/editor/aria2RpcSecret)
                          及 edit/diff/update 行为
.chezmoiignore            平台条件忽略规则(Go template,按 .chezmoi.os 分支)
.github/workflows/ci.yml  模板渲染 + ruff + shellcheck + PSScriptAnalyzer
dot_config/               → ~/.config/<app>
dot_local/                → ~/.local/share(共享数据)
dot_aria2/                → ~/.aria2(aria2.conf + run_once session 初始化)
dot_condarc / dot_gitconfig.tmpl / dot_wezterm.lua / dot_wslconfig
                          → ~/ 根级点文件
private_dot_ssh/          → ~/.ssh(敏感,0600)
scripts/                  独立工具脚本(.chezmoiignore 排除,不同步 home)
├─ windows-quickstart/    Windows 配置菜单,入口 00-main.ps1
├─ arch-quickstart/       Arch 配置菜单,入口 00-main.sh
├─ wsl-quickstart/        WSL 配置菜单,入口 00-main.sh(require_wsl 强校验)
└─ rsync/ rename/ reflector/ install_uv_dependencies.py 等
                          各工具用途见 README「辅助脚本」
```

`README.md`、`AGENTS.md`、`ruff.toml`、`.prettierrc` 等仓库级文件同样被 `.chezmoiignore` 排除,不会同步到 home。

### Chezmoi 命名前缀(源文件约定)

| 前缀 | 含义 |
| --- | --- |
| `dot_*` | 映射为 home 下的隐藏文件/目录,如 `dot_config/fish/` → `~/.config/fish/` |
| `private_*` | 安装权限为 `0600`,内容通常敏感(如 `private_dot_ssh/`、`private_fcitx5/`) |
| `executable_*` | 安装后保留可执行位(如 fish 的 `executable_config.fish`) |
| `run_once_*` | 首次 apply 时作为脚本执行一次,不安装到 home(如 aria2 session 创建) |
| `.tmpl` 后缀 | Go template,渲染后才安装;渲染失败会影响整机 apply |

### dot_config 平台速查

| 内容 | 生效平台 | 说明 |
| --- | --- | --- |
| `fish`、`kitty`、`btop`、`niri`、`fuzzel`、`fontconfig`、`mpd`、`rmpc`、`fcitx5`、`environment.d`、`noctalia`(+ `dot_local/share/fcitx5`) | Linux(Arch / WSL) | Windows 侧由 `.chezmoiignore` 忽略 |
| `powershell`(+ `dot_wslconfig`) | Windows | 非 Windows 侧忽略 |
| `fastfetch`、`mise`、`starship.toml`、`yazi`、wezterm、gitconfig、condarc、aria2、ssh | 全部 | 通用 |

**新增应用配置时的流程**:想清目标平台 → 放入 `dot_config/<app>/`(敏感则 `private_` 前缀)→ 若为平台限定,在 `.chezmoiignore` 对应 `{{- if eq .chezmoi.os "..." }}` 分支补忽略规则。

## 模板须知

- 模板变量**只**来自 `~/.config/chezmoi/chezmoi.toml` 的 `[data]`,共 4 个:`name` / `email` / `editor` / `aria2RpcSecret`。不要硬编码个人值,也不要凭空引入新变量(交互输入的说明见 README「快速开始」变量表)。
- 确需新增变量时,需同步修改三处:① `.chezmoi.toml.tmpl` 的 `promptStringOnce`;② CI 中 `--override-data`;③ `README.md` 的变量表。
- 常用分支:`{{- if eq .chezmoi.os "windows" }}`(如 gitconfig 的 autocrlf / sshCommand)、`"linux"`(如 aria2 run_once 脚本)、`.name` / `.email` 注入。
- 修改模板后必须 `chezmoi apply` 才会写进主目录;**只改源仓库不生效**。
- 渲染校验(与 CI 相同参数,改动任何 `.tmpl` 后建议先自测):

```bash
chezmoi execute-template --init \
  --override-data '{"name":"CI","email":"ci@example.com","editor":"nvim","aria2RpcSecret":"ci-secret"}' \
  < dot_gitconfig.tmpl
```

## 机制说明:WSL git SSH 转发(win-ssh)

背景:WSL 侧无法直接桥接 Windows OpenSSH agent(git 需使用 KeePassXC 注入的密钥),故 git 的 SSH 落到 Windows 侧 `ssh.exe`。该链路涉及 wsl-quickstart 脚本与 `dot_gitconfig.tmpl` 两处,改动任一方都要保持一致:

- **部署脚本** `scripts/wsl-quickstart/02-ssh-agent-forward.sh`(默认启用,Run All 亦含)生成两个包装脚本,均幂等(已存在且内容一致则跳过;`FORCE=1` 或内容不一致且用户确认时覆盖):
  - WSL 侧 `~/bin/win-ssh`:`sh` 包装 → 调 Windows PowerShell 执行下方脚本;
  - Windows 侧 `%USERPROFILE%\.local\bin\win-ssh.ps1`:清掉 `SSH_AUTH_SOCK`,exec Windows OpenSSH `ssh.exe`。
- **git 接线**由 chezmoi 完成,脚本**不**设置 `GIT_SSH_COMMAND`、不注入 `.bashrc`:`dot_gitconfig.tmpl` 的非 Windows 分支检测 `WSL_DISTRO_NAME` 环境变量,存在即写 `core.sshCommand = ~/bin/win-ssh`,保证任意 shell(含非交互)下 git 均走该通道。Windows 分支则写 `C:/Windows/System32/OpenSSH/ssh.exe`。
- **验证注意**:脚本可选自检用 `ssh -T git@github.com`,但 GitHub 认证成功仍以退出码 1 结束,须匹配输出中的 `successfully authenticated`,并带 3 次重试以容忍代理节点抖动。

## 改动工作流

1. 改**本仓库源文件**,不要直接编辑 `$HOME` 下已应用的文件(会被下次 apply 覆盖丢失)。
2. 新增文件:手动放入正确的 `dot_*` / `private_*` 路径,或用 `chezmoi add ~/.config/<path>` 由工具生成。
3. 同步检查是否需要更新 `.chezmoiignore`、`README.md`、本文件。
4. 涉及模板时,先用上文命令渲染自测。
5. 本地跑一遍代码质量检查,再提交。

## 安全与隐私

- `private_dot_ssh/`、fcitx5 私有数据、aria2 RPC 密钥等敏感内容:**不得**明文出现在 diff、commit message 或日志里。
- `aria2RpcSecret` 默认值只是 init 的占位建议;真实密钥仅存在于用户本机 `~/.config/chezmoi/chezmoi.toml`,不要在文档/对话中要求用户贴出。
- 个人仓库,避免激进重构;改动尽量保持默认安全、可回滚。

## 代码质量

push/PR 时 CI 全量校验,本地应先行自测(命令与 CI 对齐,为本仓库唯一权威;README 不再重复):

| 语言 | 规则 | 自测命令 |
| --- | --- | --- |
| Python | `ruff.toml`(仅 `scripts/**/*.py`,target py39,line-length 100) | `ruff check scripts/` |
| Shell | shellcheck `-S warning` | `shellcheck -x -S warning $(git ls-files 'scripts/**/*.sh')` |
| PowerShell | PSScriptAnalyzer | `Invoke-ScriptAnalyzer -Path scripts/windows-quickstart -Recurse` |
| JSON / MD / YAML | `.prettierrc` / `.prettierignore` | prettier 格式 |
| Chezmoi 模板 | — | 逐个渲染全部 `*.tmpl`(见上) |

本地编辑器提示(可选):VS Code 下可用 Ruff、Prettier、PowerShell(PSScriptAnalyzer)、ShellCheck 扩展获得即时反馈;推送前仍以上表命令为准。

## Git 提交规范

- 遵循 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/),格式 `type(scope): 描述`,**描述使用中文**。
- `type` 小写:`feat` / `fix` / `refactor` / `chore` / `docs` / `style` / `test` / `perf`。
- `scope` 为改动所属目录或模块(如 `scripts`、`windows-quickstart`、`config`、`docs`)。
- 示例:`feat(scripts): 添加某功能`、`fix(docs): 修复文档错误`;必要时在标题下方补充 body。
- 一个提交只做一件事;禁止无 type 前缀、或描述过于笼统的提交信息。
