# AGENTS

这个仓库是一个个人 dotfiles 配置仓库，使用 [Chezmoi](https://www.chezmoi.io/) 管理跨平台配置，覆盖 Windows / Arch Linux / WSL (Debian)。

## 仓库范围

- `dot_config/`：大多数应用和终端配置（fish、powershell、kitty、niri、yazi 等）
- `dot_local/`：自定义执行文件、脚本和本地共享数据
- `dot_aria2/`：aria2 下载器配置
- `scripts/`：安装、快速启动和同步脚本
  - `windows-quickstart/`、`arch-quickstart/`、`wsl-quickstart/`：各平台快速配置脚本
  - `rsync/`、`rename/`、`reflector/`：跨平台辅助工具脚本
- `private_dot_ssh/`：SSH 私有配置模板（敏感）

## Chezmoi 模板须知

- 以 `.tmpl` 结尾的文件是 chezmoi 模板，内容为 Go template 语法。
- 模板变量来自 `~/.config/chezmoi/chezmoi.toml` 的 `[data]`（`name`/`email`/`editor`/`aria2RpcSecret`），不要硬编码敏感值。
- 修改模板后需 `chezmoi apply` 才会同步到主目录；只改源码仓库不会自动生效。
- 渲染校验：`chezmoi execute-template --init --override-data '{"name":"CI","email":"ci@example.com","editor":"nvim","aria2RpcSecret":"ci-secret"}' < file.tmpl`

## 使用注意

- 这是个人配置仓库，改动应尽量保持安全、可移植、尽量不破坏默认终端/系统行为。
- 脚本是平台相关的：`.ps1` 面向 Windows，`scripts/arch-quickstart/` 面向 Arch，`scripts/wsl-quickstart/` 面向 WSL (Debian)；改通用脚本（如 `scripts/rsync/`）时注意跨平台兼容。
- 私有模板和敏感信息不应被公开写入仓库。对 `private_dot_ssh/` 的改动要特别谨慎。
- 如果需要添加说明文档，优先更新 `README.md`。

## 代码质量

改动后请自行检查，CI 也会在 push/PR 时自动校验：

- Python：遵循 `ruff.toml`，运行 `ruff check scripts/`
- Shell：通过 shellcheck（`-S warning`）
- PowerShell：通过 PSScriptAnalyzer（针对 `scripts/windows-quickstart/`）
- JSON/MD/YAML：遵循 `.prettierrc`

## Git 提交规范

- 所有提交必须遵循 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/) 规范，格式为 `type(scope): 描述`，例如 `feat(scripts): 添加某功能`、`fix(docs): 修复文档错误`、`refactor(scripts): 重构安装逻辑`。
- `type` 使用小写，可选 `feat`、`fix`、`refactor`、`chore`、`docs`、`style`、`test`、`perf` 等；`scope` 一般为改动所属的目录或模块（如 `scripts`、`docs`、`config`）。
- 描述使用中文，简要说明改动内容；必要时在 `type(scope): 描述` 下方补充详细说明（body）。
- 禁止使用无规范格式的提交信息（如仅一句话描述、缺少 type 前缀）。
