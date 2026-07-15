# AGENTS

这个仓库是一个个人 dotfiles 配置仓库，使用 [Chezmoi](https://www.chezmoi.io/) 管理跨平台配置。

## 仓库范围

- `dot_config/`：大多数应用和终端配置
- `dot_local/`：自定义执行文件、脚本和本地共享数据
- `dot_aria2/`：aria2 下载器配置
- `scripts/`：安装、快速启动和同步脚本
- `private_dot_ssh/`：SSH 私有配置模板

## 推荐 Agent

- `general-purpose`：处理大多数配置改动、脚本编辑和文档更新
- `explore`：审查和理解复杂配置、查找跨文件依赖
- `code-review`：对改动进行高质量审查
- `security-review`：检查是否有敏感信息泄露或不安全的配置

## 使用注意

- 这是个人配置仓库，改动应尽量保持安全、可移植、尽量不破坏默认终端/系统行为。
- 私有模板和敏感信息不应被公开写入仓库。对 `private_dot_ssh/` 的改动要特别谨慎。
- 如果需要添加说明文档，优先更新 `README.md`。
