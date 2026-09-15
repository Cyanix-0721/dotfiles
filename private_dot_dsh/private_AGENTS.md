# Global AGENTS.md — DSH 全局环境约定

> 注入方式：`$DSH_HOME/AGENTS.md`，由 `dsh-agent-instructions` 在首次请求时作为
> durable baseline 消息注入（上限 65,536 字节），随后是项目根到工作目录的
> `AGENTS.md` / `CLAUDE.md` 链，broad-to-specific 顺序。
> 生效范围：所有工作目录；项目级 `AGENTS.md` 存在时以项目级优先。

## 0. 启动协议（Superpowers 接管流程）
- DSH 已安装 `@wenaixi/dsh-superpower` 插件（`obra/superpowers` 的 DSH 移植版，
  14 个技能经 `ctx.skills` 注入，全中文）。
- 任何用户任务**先按 Superpowers 协议匹配 skill**（brainstorming → writing-plans →
  executing-plans → TDD → debugging → code-review → verification），再决定具体动作。
- 本文件不重复列 Superpowers 自带的 skill；以插件注入为准。本文件只补环境约束与本地 skills 清单。

## 1. 本地 skills 清单
技能来自两个来源，合并注入（共 38 个）：

- **`$DSH_AGENTS_HOME/skills`**（rank 500）— Windows 侧共享技能库，由 chezmoi/ccswitch
  在 Windows 上维护，经 `DSH_AGENTS_HOME` 指向 `/mnt/c/Users/<user>/.agents`。24 个。
- **`@wenaixi/dsh-superpower`** — 插件注入的 14 个 `superpower-*`。

`~/.dsh/skills`（rank 400）当前空闲，留给 WSL 本地技能；同名时 rank 小者胜，
故本地技能可覆盖 Windows 侧同名项。

以下为 `$DSH_AGENTS_HOME/skills` 的 24 个，描述已带触发场景，按 description 匹配：

**流程 / 盘问**
- `grilling` — 对计划/决策的反复盘问（"grill me" / 压方案）
- `domain-modeling` — 术语 / CONTEXT.md / ADR 落盘（设计讨论中术语分歧时触发）
- `handoff` — 把会话压成交接文档给下一个 agent
- `writing-for-agents` — 写/编辑 skill、AGENTS.md、CLAUDE.md
- `writing-beats` — 写作节奏与结构

**Git**
- `resolving-merge-conflicts` — 解决进行中的 merge/rebase 冲突

**文档产出**（按文件类型自动触发）
- `docx` / `pptx` / `xlsx` / `pdf` — Office 与 PDF
- `canvas-design` — 海报/单图等静态视觉（.png / .pdf）
- `theme-factory` — 给已有产物套配色+字体主题

**Web / 前端**
- `frontend-design` — 视觉方向与排版风格
- `web-design-guidelines` — 审查 UI 合规 / 可访问性
- `webapp-testing` — 用 Playwright 测本地 web 应用
- `web-artifacts-builder` — 复杂多组件 HTML artifact

**元 / 自举**
- `find-skills` — 发现并安装 skill
- `skill-creator` — 新建 / 优化 / 评估 skill
- `mcp-builder` — 编写 MCP 服务器

**杂项**
- `obsidian-cli` / `obsidian-markdown` — 操作 Obsidian vault（用户使用时才触发）
- `defuddle` — 网页转干净 markdown（Obsidian 剪藏配套）
- `teach` — 在工作区教用户技能/概念
- `wizard` — 生成交互式 bash 向导，引导手动步骤

## 2. MCP 工具（经 `cordis.patch.yml` 的 `insert` 挂载）
三个 server 均以 `dsh-mcp-client` 挂载，工具名形如 `mcp__<serverName>__<tool>`：

- `mcp__firecrawl__*`（27 工具）— 网页抓取/爬取/搜索/结构化提取/论文研究/变更监控。
  **网页检索优先于 curl/wget**；`firecrawl_scrape` 带 JS 渲染，`firecrawl_crawl`/`map`
  可做站点级操作，`firecrawl_extract` 按 schema 出结构化数据。
- `mcp__context7__*`（2 工具）— 查库版本文档；提示里写 "use context7" 触发。
- `mcp__playwright__*`（~19 类）— 浏览器自动化；交互式探索用它，可复现的测试脚本
  用 `webapp-testing` 技能（`uv run --with playwright python <script>`）。

**关于原生搜索**：`dsh-web-search-deepseek` 由 `dsh-base` 默认挂载并已配好
（`searchProvider: deepseek-official`、`apiKeyEnv: DEEPSEEK_API_KEY`、端点默认
`https://api.deepseek.com/anthropic/v1`、`tool-web.searchTimeoutMs: 60000`），
**只需在凭据库提供 `DEEPSEEK_API_KEY` 的值即可**，`cordis.patch.yml` 无需改动。

该后端走官方端点（独立于 buddy/华为 CodeArts 通道），一次搜索是一次完整的辅助模型
请求（故超时放宽到 60s），返回结构化 `sources[]`（url/title/publishedAt + 片段），
**不含正文**。与 Firecrawl 的分工：
- 快速查事实、要来源列表 → `web_search`（原生，轻量、结构化）
- 抓单页正文 → `web_fetch`（静态页）或 `firecrawl_scrape`（需要 JS 渲染时）
- 整站爬取 / 结构化提取 / 论文与 GitHub 检索 → Firecrawl 专用工具

**关于 MCP 配置的两条硬约束**（改 `cordis.patch.yml` 时须遵守）：
1. `command` 必须用 fnm aliases/default 的**绝对路径 node** 显式执行 `npx-cli.js`，
   不要用裸 `npx`：后者的 shebang 是 `#!/usr/bin/env node`，要靠 PATH 找 node，
   而 fnm 的 PATH 条目是带会话临时 ID 的 multishell 目录，DSH 重启后即失效。
2. `env` 必须**显式声明**：MCP 子进程环境会清洗掉匹配 `/KEY|PASSWORD|SECRET|TOKEN/i`
   的变量，只有显式赋值才传得进去。

## 3. 密钥与隐私（工具输出会原样落盘）
**会话日志不脱敏**：`grep` 回显、`cat` 内容等工具输出以明文持久化到
`~/.dsh/sessions/<workspace>/session-<id>/session.v3.jsonl.zstd`（多帧 zstd，
需按 magic `28 b5 2f fd` 逐帧解压）。DSH 无内置拦截：`better-sidebar` 的遮蔽仅渲染层
（源码自述 "display-only"），`tools/result` 是 `emit` 而非 `waterfall`，挂不上改写钩子。
**密钥进入工具输出即视为已失陷，须轮换。**

- **搜密钥类内容**（`.env`、`*credential*`、`*secret*`、`*token*`）：用 `grep -rl`
  只列文件名，或 `grep -c` 只数次数；**不要用 `grep -r` 回显匹配行**。
- **读凭据**：只报形态（长度、前缀、是否等于旧值），不复述值，不写进报告或文档。
- **写示例**：用 `fc-CANARY-NOT-A-REAL-KEY` 这类一眼假的值，避免扫描器误报。
- **配置里不放字面量密钥**：用 `!!js process.env.X` + `~/.dsh/.env`（600）。
  注意 `${VAR}` **不是** DSH 语法（会当字面字符串传给 MCP），凭据库也不进 `process.env`。

## 4. 调研纪律
- **只认一手来源**：官方文档、源码、RFC/spec、第一方 API；博客/StackOverflow 仅作线索不作引用。
- **版本敏感事实**须注明 `library@version`，不沿用训练数据旧版本。
- **长调研用 background agent 执行，主会话继续**；后台 worker **不得再派生 agent** 或再调用本工作流。
- 结论落盘 `docs/notes/<topic>.md`（无目录则建），每条结论附 URL，并告知用户位置。

## 5. Git 认证链路（WSL 约束）
- git 认证**不经过 WSL ssh agent**（`SSH_AUTH_SOCK` 在 WSL 下是死变量，且已由
  chezmoi 模板条件化移除）。
- 链路：`core.sshCommand → ~/bin/win-ssh → powershell → win-ssh.ps1 →
  C:\Windows\System32\OpenSSH\ssh.exe → Windows OpenSSH agent → KeePassXC`。
- **push 前先验证**：`~/bin/win-ssh -o BatchMode=yes -T git@github.com`，
  看到 `successfully authenticated` 再继续。
- push 被拒（publickey）：不去 WSL 找 key，优先查 KeePassXC 是否解锁 + Windows agent 是否有 key。
- **注意**：`git push` 在 WSL 侧需 `GIT_SSH_COMMAND="$HOME/bin/win-ssh"`，
  因为仓库的 `core.sshCommand` 若为 Windows 路径形式在 WSL 下会 `cannot exec`。

## 6. 用户偏好
- **不直接改动用户的 Codex / WSL / chezmoi 环境**——安装/配置类操作**只给命令**，由用户执行。
  （例外：用户当回合明确要求代执行。）
- **避免显式/被托管的 systemd unit**——用户偏好隐式；agent socket 命名以 Arch 习惯
  （`$XDG_RUNTIME_DIR/ssh-agent.socket`）为准。
- chezmoi 仓库是双克隆（Windows + WSL，同源 GitHub `Cyanix-0721/dotfiles`），
  改动须两处同步。
- **Python 一律用 uv，不污染全局**：脚本走 `uv run --with <pkg> python <script>`。
- **本文件（`~/.dsh/AGENTS.md`）由 chezmoi 管理**（源为 `dot_dsh/AGENTS.md`）。
  改动本文件后，提醒用户提交并同步 chezmoi 仓库，否则变更只存在于本机。

## 7. 生效优先级（强 → 弱）
1. **用户当回合指令** — 可覆盖 2/3/4 的行为细节；不得违反 §5/§6 的认证链路与用户偏好硬约束。
2. **项目根目录 `AGENTS.md`**（若存在）— 最具体，项目内优先于全局。
3. **本文件（全局）** — 通用环境约束与 skills 清单。
4. **Superpowers 插件注入的协议引导** — 流程基线，与上三层一般不冲突。
