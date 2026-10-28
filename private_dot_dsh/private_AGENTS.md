# Global AGENTS.md — DSH 全局环境约定

> 注入方式：`$DSH_HOME/AGENTS.md`，由 `dsh-agent-instructions` 在首次请求时作为
> durable baseline 消息注入（上限 65,536 字节），随后是项目根到工作目录的
> `AGENTS.md` / `CLAUDE.md` 链，broad-to-specific 顺序。
> 生效范围：所有工作目录；项目级 `AGENTS.md` 存在时以项目级优先。

## 0. 启动协议（Superpowers 接管流程）
- DSH 已安装 `@wenaixi/dsh-superpower` 插件（`obra/superpowers` 的 DSH 移植版，
  15 个技能经 `ctx.skills` 注入，全中文）。
- 任何用户任务**先按 Superpowers 协议匹配 skill**（brainstorming → writing-plans →
  executing-plans 或 subagent-driven-development → TDD → debugging → code-review →
  verification），再决定具体动作。
- **委派面判据**：任务可切成互不依赖的独立块 → 用 `subagent` / `subagent_fork` 并行派发
  （`dispatching-parallel-agents`）；强串行 → 内联 `executing-plans`。`spawn_teammate`
  （Agent Teams）仅在用户显式要求 teammates 时用。
- 本文件不重复列 Superpowers 自带的 skill；以插件注入为准。本文件只补环境约束与本地 skills 清单。
- **技能名以插件目录 frontmatter 为准**（`name:` 字段），当前 15 个均**无前缀**；
  历史文档里的 `superpower-*` 是旧版命名，照旧名调用会失败。
- **任务面板纪律**：任何多步任务，开工第一件事用 `todo_write`（由 `dsh-base` 默认挂载的
  `@deepseek-ai/dsh-tool-todo` 提供）把**全量**步骤写成清单，**每完成一步立刻标 `completed`，
  不得留到收尾一次性结账**。依据 = 上述 `executing-plans` 步骤 2 逐字要求「针对每项任务：
  1. 标记为 `in_progress` … 4. 标记为 `completed`」。**为什么必须全程维护**：面板快照跨上下文
  压缩持久（整表替换、无部分更新、无回读工具），是压缩后**唯一**能自证进度的载体 ——
  攒着不更新，用户看到的就是「任务卡住」。

## 1. 本地 skills 清单
技能来自三个来源，合并注入（共 40 个，其中 39 个模型可见）：

- **`$DSH_AGENTS_HOME/skills`**（rank 500）— Windows 侧共享技能库，由 chezmoi/ccswitch
  在 Windows 上维护，经 `DSH_AGENTS_HOME` 指向 `/mnt/c/Users/<user>/.agents`。24 个
  （`handoff` 带 `disable-model-invocation: true`，模型不可见）。
- **`@wenaixi/dsh-superpower`** — 插件注入的 15 个，**名称无 `superpower-` 前缀**
  （`brainstorming` / `using-superpowers` / `writing-plans` / `executing-plans` / `test-driven-development` /
  `systematic-debugging` / `verification-before-completion` / `requesting-code-review` / `receiving-code-review` /
  `finishing-a-development-branch` / `subagent-driven-development` / `dispatching-parallel-agents` /
  `using-git-worktrees` / `writing-skills` / `diagnosing-superpowers`）。叫错名 = 调不到。
- **`@deepseek-ai/dsh-experimental-badge-skill-bundle`** — 注入 1 个 `dsh-badge`。

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

## 3. 文件检索分工（Windows 侧优先 Everything CLI）

**硬规则：在 Windows 盘（C:/D:/E:）上按「文件名 / 后缀 / 大小 / 修改时间」找文件，
一律先用 `es.exe`，不要用 `find` / `fdfind` 遍历 `/mnt/c`。**

- 用户已 `scoop install everything-cli`：`C:\Users\Administrator\scoop\shims\es.exe`
  （ES 1.1.0.38；后端 Everything 1.5.0.1423b 常驻，索引 `C:,D:,E:` 约 287 万对象）。
- WSL 侧**可直接裸名调用**（shim 在 drvfs 下可执行，无需 `chmod +x`），实测 ≈0.15s/次。

**为什么**：`/mnt/c` 是 9p/drvfs（`trans=fd`），每次 stat 都是一次 9p 往返；`es.exe` 直接查
预建的 NTFS USN 索引。实测差距是**数量级**：

| 任务 | `es.exe` | WSL `find` / `fdfind` |
| --- | --- | --- |
| C: 全部 `*.mp4` | **0.07–0.15s**，4274 条 | 90s 超时，只数到 109 |
| C:\Users 下 `*.scoop*` | **0.08s** | 29.9s |
| E: 按大小排序 top20 | **0.11s** | 24s（`sort` 还被 SIGPIPE 打断） |
| `find .../scoop -type f`（47 万文件） | — | 2m4s；换 `fdfind` 仍 56s |

**三个边界（越过就换工具）**：
1. **看不到 WSL ext4**：`es.exe -get-result-count "wsl.localhost"` = 0。
   WSL 仓库内找文件仍用 `fd` / `fdfind`。
2. **不索引内容**：`content_indexing_enabled=0`（`Everything.ini:989`）⇒ `content:` 查询会挂死
   （实测 >120s 无返回）。找文件**内容**一律 `rg`。
3. `Everything.exe` 是 GUI 二进制，**没有** `-export-csv`（写它会弹搜索窗口并挂死）；
   只有 `es.exe` 有导出开关。

**编码两条坑（均已实测踩过）**：
- 搜索词**必须是 UTF-8 原文**：`es.exe -get-result-count "青水庵"` → 23；GBK 转码后 → **0**。
- **stdout 是 GBK 字节**（`-json` 也一样），不是 UTF-8；直接管道给下游会乱码。
  - 只要文本路径：`es.exe … | iconv -f GBK -t UTF-8`
  - 要结构化：`es.exe … -export-csv "C:\\…\\out.csv" -utf8-bom`（产物是真 UTF-8 BOM + CRLF）。
    ⚠️ `/mnt/c` 对 WSL **只读**（挂载选项带 `ro`）⇒ 导出文件只能落 Windows 侧路径，再由 WSL 读。

**常用调用**：
```bash
es.exe -n 20 -sort size -size -path 'E:\' '*'   # 某盘最大文件
es.exe -n 10 'dm:today' -sort dm                 # 今天改过的
es.exe -path 'D:\' 'pyproject.toml'              # 某目录下找名
es.exe -regex '^requirements.*\.txt$'            # 正则
es.exe -get-result-count 'ext:pdf'               # 只数条数
```

**速查表**：Windows 盘找名 → `es.exe`；WSL ext4 找名 → `fd`；任一找内容 → `rg`。

## 4. 密钥与隐私（工具输出会原样落盘）
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
- **跑密钥扫描器（betterleaks）**：**默认会把命中值明文打进输出**（因此落盘）⇒
  **必须显式带 `--redact`**，否则等于亲手把密钥写进会话日志。
  查提交历史 `betterleaks git <path>`——只扫跟踪内容，天然避开被忽略的产物，**日常首选**；
  WSL / Windows 两侧同一套用法，无需额外配置。
  **`2.0.0-rc.3` 起 git 扫描改走 go-git，不再 fork `git` 二进制**（rc.2 及更早会 shell out）。
  `2.0.0-rc.4` 把 v6 换成 **go-git v5** 并自建 object/pack 读取器，仍是纯进程内扫描：
  不执行 `git`、hook、diff/textconv helper、filter、SSH、credential helper，
  所以扫不受信任的仓库不会被它自己配置的东西执行代码。由此产生的变化：
  - Windows 侧**不再需要 git 垫片**。旧版 betterleaks 会给子进程注入
    `GIT_CONFIG_GLOBAL=NUL` / `GIT_CONFIG_SYSTEM=NUL` / `GIT_CONFIG_NOSYSTEM=1`，
    而 Git for Windows ≥2.56.0 拒绝全大写设备名 `NUL` ⇒ `git log` exit 128、
    只扫 0 字节却打印 `no leaks found in incomplete scan`（假绿）。
    rc.3 里这条注入路径已随 `cmd.Run()` 一起消失，故 `~/.local/share/git-shim/`、mise 的
    `_.path` 垫片条目、`.chezmoiignore` 里的对应规则**均已删除**。判别依据是实测：
    把会记账且 `exit 128` 的假 `git.cmd` 放在 PATH 最前，rc.3 仍完整扫出 101.9 MB /
    `leaks found: 3`，而假 git 的调用计数为 **0**（rc.2 及更早则会记到调用）。
  - 假绿的**判别口径仍然有效**：真扫描必有 `INF scanned ~NNNN bytes`（百万级）且退出码 0；
    见到 `scanned ~0 bytes` + `incomplete scan` 一律当**失败**，不许当绿。这条主要用于
    识别路径写错、权限不足之类的新问题，不再是 git 垫片的专属症状。
  - `--log-opts`、`--staged`、`--unstaged`、`--pre-receive`、`--pre-receive-error-message`
    在 rc.3 **已删除**，再传会 `unknown flag`。要让 git 自己决定扫什么就管道进来：
    `git log -p -B | betterleaks stdin --git-diff`（pre-commit hook 就是这么做的）。
  - **合并提交默认不再 diff**（rc.2 及更早的 `git log -p` 默认跳过合并提交，rc.3 同样跳过）。
    彻底口径从旧的 `--log-opts="--all -m"` 换成 `--include=merges`；
    可选资源还有 `--include=objects,unreachable-objects,commit-messages,notes,tag-messages,reflogs`。
  - 提交过滤器：`--revision=A..B`、`--since`、`--until`、`--author`、`--committer`、`--max-commits`。
    远端扫描默认**不再拉 PR/MR ref**（rc.2 会镜像全部 ref，等于扫别人的未合并 PR），
    要旧行为用 `--clone-all-refs`，单个 PR 用 `--clone-ref=refs/pull/123/head`。
  - 大 blob 默认上限 `--git-max-blob-mib=64`：超过的包对象会打
    `skipped Git content over a limit` 警告并跳过（本仓库的
    `dot_local/share/fcitx5/rime/build/wanxiang.table.bin` 历史上就超限），
    这**不是**扫描失败，但要知道历史里那一块没被覆盖。
  - 少重复旧版的速度预期：rc.3 比 rc.2 快约 2×（go-git 化 + 合并提交不 diff），
    本仓库 `betterleaks git .` 约 1.7s / 101.9 MB。
  - **rc.4 收窄了「假绿」的边界**：go-git v5 移植后引入了一类**结构性不支持**，
    表现为「日志里只有 WRN、结果残缺」，容易被当成绿。已实测（本机 Git 2.x + rc.4）：
    - **reftable 仓库**（`git config extensions.refstorage reftable`）⇒
      `ERR failed to scan Git repository error="unknown extension: refstorage"`
      + `scanned ~0 bytes` + `incomplete scan`，**退出码 1**。这种残缺是**安全**的
      （会判失败），可以放心用退出码判断。
    - **SHA-1 / SHA-256 仓库同一二进制都支持**（实测 `--object-format=sha256` 正常，
      rc.3 也正常），无需 build tag。但 **HTTP(S) 克隆目前只支持 SHA-1 仓库**，
      要扫 SHA-256 仓库得先本地 clone 再 `betterleaks git <path>`。
    - `--shared` / `--reference` 克隆出的仓库、以及直接扫 submodule checkout，
      需要 `--allow-external-objects`；否则因对象库在仓库目录之外而被拒。
    - 硬上限：配置文件 16 MiB、单 ref 1 MiB、ref 目录嵌套 128 层、
      alternates 最多 4096 个对象目录、无 mmap 时 pack/index 最多同时开 64 个文件、
      单仓库最多 800 万个 object id 参与可达性分类。超限是**错误**（不是静默跳过），
      大仓库改用 `--include=objects` 替代 `--include=unreachable-objects`。
    - rename 检测在相似度打平时配对可能不同（继承自 go-git），可能导致**两次运行
      命中的行不同**。需要可比对的结果时用 `-o x.json` 存 JSON 再 diff，别肉眼比对终端。
  扫工作树用 `betterleaks filesystem <path>`：注意它**不读 `.gitignore`**，会连构建产物一起遍历
  （全局配置已排除 `.git/`、`.uvcache/`、`.gradle/`、`.kotlin/`，以及内嵌默认的 `node_modules/`、
  lockfile、图片字体等；但**未**排除 `build/`、`dist/`、`target/` 等通用产物名）；
  在大仓库上先确认路径范围，别直接扫仓库根。
  回报只给 `rule_id` / 路径 / 行号，**不复述 `match.value`**。

## 5. 调研纪律
- **只认一手来源**：官方文档、源码、RFC/spec、第一方 API；博客/StackOverflow 仅作线索不作引用。
- **版本敏感事实**须注明 `library@version`，不沿用训练数据旧版本。
- **长调研用 `subagent` 派发，主会话继续**（`background agent` 不是工具名）。
- 结论落盘 `docs/notes/<topic>.md`（无目录则建），每条结论附 URL，并告知用户位置。

## 6. Git 认证链路（WSL 约束）
- git 认证**不经过 WSL ssh agent**（`SSH_AUTH_SOCK` 在 WSL 下是死变量，且已由
  chezmoi 模板条件化移除）。
- 链路：`core.sshCommand → ~/bin/win-ssh → powershell → win-ssh.ps1 →
  C:\Windows\System32\OpenSSH\ssh.exe → Windows OpenSSH agent → KeePassXC`。
- **push 前先验证**：`~/bin/win-ssh -o BatchMode=yes -T git@github.com`，
  看到 `successfully authenticated` 再继续。
- push 被拒（publickey）：不去 WSL 找 key，优先查 KeePassXC 是否解锁 + Windows agent 是否有 key。
- **注意**：`git push` 在 WSL 侧需 `GIT_SSH_COMMAND="$HOME/bin/win-ssh"`，
  因为仓库的 `core.sshCommand` 若为 Windows 路径形式在 WSL 下会 `cannot exec`。

## 7. 用户偏好
- **不直接改动用户的 Codex / WSL / chezmoi 环境**——安装/配置类操作**只给命令**，由用户执行。
  （例外：用户当回合明确要求代执行。）
- **避免显式/被托管的 systemd unit**——用户偏好隐式；agent socket 命名以 Arch 习惯
  （`$XDG_RUNTIME_DIR/ssh-agent.socket`）为准。
- chezmoi 仓库是双克隆（Windows + WSL，同源 GitHub `Cyanix-0721/dotfiles`），
  改动须两处同步。
- **Python 一律用 uv，不污染全局**：脚本走 `uv run --with <pkg> python <script>`。
- **本文件（`~/.dsh/AGENTS.md`）由 chezmoi 管理**（源为
  `private_dot_dsh/private_AGENTS.md`，即 `private_` 前缀 ⇒ 0600）。
  改动本文件后，提醒用户提交并同步 chezmoi 仓库，否则变更只存在于本机。

## 8. 生效优先级（强 → 弱）
1. **用户当回合指令** — 可覆盖 2/3/4 的行为细节；不得违反 §6/§7 的认证链路与用户偏好硬约束。
2. **项目根目录 `AGENTS.md`**（若存在）— 最具体，项目内优先于全局的**事实类**约定
   （技术栈 / 环境 / 工具链 / 构建命令 / 目录结构）。
3. **本文件（全局）** — 通用环境约束与 skills 清单。
4. **Superpowers 插件注入的协议引导** — 流程基线。

**§0 的「任何用户任务先按 Superpowers 协议匹配 skill」是下限，不受 2/3 覆盖**：
项目级 `AGENTS.md` 可以把项目事实写得比全局更具体、更严格，但不能规定「本项目不用 skill」。
只有**用户当回合本人**说「跳过 skill」才算覆盖（用户 > 项目 > 全局）。
