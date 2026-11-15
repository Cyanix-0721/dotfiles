---
name: betterleaks-scanning
description: "密钥扫描与凭据隐私——betterleaks（含 rc.2/3/4 版本行为、git 与文件系统扫描、假绿判别）、gitleaks、会话日志不脱敏风险、读写密钥的红线。要扫密钥、查提交历史泄露、或处理/读取凭据时加载。"
---

# 密钥与隐私（工具输出会原样落盘）

**会话日志不脱敏**：`grep` 回显、`cat` 内容等工具输出以明文持久化到 `~/.dsh/sessions/<workspace>/session-<id>/session.v3.jsonl.zstd`（多帧 zstd，需按 magic `28 b5 2f fd` 逐帧解压）。DSH 无内置拦截：better-sidebar 的遮蔽仅渲染层（源码自述 "display-only"），`tools/result` 是 `emit` 而非 `waterfall`，挂不上改写钩子。**密钥进入工具输出即视为已失陷，须轮换。**

- **搜密钥类内容**（`.env`、`*credential*`、`*secret*`、`*token*`）：用 `grep -rl` 只列文件名，或 `grep -c` 只数次数；**不要用 `grep -r` 回显匹配行**。
- **读凭据**：只报形态（长度、前缀、是否等于旧值），不复述值，不写进报告或文档。
- **写示例**：用 `fc-CANARY-NOT-A-REAL-KEY` 这类一眼假的值，避免扫描器误报。
- **配置里不放字面量密钥**：用 `!!js process.env.X` + `~/.dsh/.env`（600）。注意 `${VAR}` 不是 DSH 语法（会当字面字符串传给 MCP），凭据库也不进 `process.env`。

## betterleaks 扫密钥
**默认会把命中值明文打进输出**（因此落盘）⇒ **必须显式带 `--redact`**，否则等于亲手把密钥写进会话日志。
查提交历史 `betterleaks git <path>`——只扫跟踪内容，天然避开被忽略的产物，**日常首选**；WSL / Windows 两侧同一套用法，无需额外配置。

**`2.0.0-rc.3` 起 git 扫描改走 go-git，不再 fork `git` 二进制**（rc.2 及更早会 shell out）。`2.0.0-rc.4` 把 v6 换成 **go-git v5** 并自建 object/pack 读取器，仍是纯进程内扫描：不执行 `git`、hook、diff/textconv helper、filter、SSH、credential helper，所以扫不受信任的仓库不会被它自己配置的东西执行代码。由此产生的变化：
- Windows 侧不再需要 git 垫片。旧版会给子进程注入 `GIT_CONFIG_GLOBAL=NUL` / `GIT_CONFIG_SYSTEM=NUL` / `GIT_CONFIG_NOSYSTEM=1`，而 Git for Windows ≥2.56.0 拒绝全大写设备名 `NUL` ⇒ `git log` exit 128、只扫 0 字节却打印 `no leaks found in incomplete scan`（假绿）。rc.3 里这条注入路径已随 `cmd.Run()` 一起消失，故 `~/.local/share/git-shim/`、mise 的 `_.path` 垫片条目、`.chezmoiignore` 里的对应规则均已删除。判别依据是实测：把会记账且 `exit 128` 的假 `git.cmd` 放在 PATH 最前，rc.3 仍完整扫出 101.9 MB / `leaks found: 3`，而假 git 的调用计数为 0（rc.2 及更早则会记到调用）。
- 假绿的判别口径仍然有效：真扫描必有 `INF scanned ~NNNN bytes`（百万级）且退出码 0；见到 `scanned ~0 bytes` + `incomplete scan` 一律当**失败**，不许当绿。这条主要识别路径写错、权限不足之类的新问题，不再是 git 垫片的专属症状。
- `--log-opts`、`--staged`、`--unstaged`、`--pre-receive`、`--pre-receive-error-message` 在 rc.3 已删除，再传会 `unknown flag`。要让 git 自己决定扫什么就管道进来：`git log -p -B | betterleaks stdin --git-diff`（pre-commit hook 就是这么做的）。
- 合并提交默认不再 diff（rc.2 及更早的 `git log -p` 默认跳过合并提交，rc.3 同样跳过）。彻底口径从旧的 `--log-opts="--all -m"` 换成 `--include=merges`；可选资源还有 `--include=objects,unreachable-objects,commit-messages,notes,tag-messages,reflogs`。
- 提交过滤器：`--revision=A..B`、`--since`、`--until`、`--author`、`--committer`、`--max-commits`。远端扫描默认不再拉 PR/MR ref（rc.2 会镜像全部 ref），要旧行为用 `--clone-all-refs`，单个 PR 用 `--clone-ref=refs/pull/123/head`。
- 大 blob 默认上限 `--git-max-blob-mib=64`：超过的包对象会打 `skipped Git content over a limit` 警告并跳过（本仓库 `dot_local/share/fcitx5/rime/build/wanxiang.table.bin` 历史上就超限），这不是扫描失败，但要知道历史里那一块没被覆盖。
- 速度：rc.3 比 rc.2 快约 2×（go-git 化 + 合并提交不 diff），本仓库 `betterleaks git .` 约 1.7s / 101.9 MB。
- **rc.4 收窄了「假绿」的边界**：go-git v5 移植后引入一类结构性不支持，表现为「日志里只有 WRN、结果残缺」，容易被当成绿。已实测（本机 Git 2.x + rc.4）：
  - reftable 仓库（`git config extensions.refstorage reftable`）⇒ `ERR failed to scan Git repository error="unknown extension: refstorage"` + `scanned ~0 bytes` + `incomplete scan`，退出码 1。这种残缺是安全的（会判失败），可放心用退出码判断。
  - SHA-1 / SHA-256 仓库同一二进制都支持（实测 `--object-format=sha256` 正常，rc.3 也正常），无需 build tag。但 HTTP(S) 克隆目前只支持 SHA-1 仓库，要扫 SHA-256 仓库得先本地 clone 再 `betterleaks git <path>`。
  - `--shared` / `--reference` 克隆出的仓库、以及直接扫 submodule checkout，需要 `--allow-external-objects`；否则因对象库在仓库目录之外而被拒。
  - 硬上限：配置文件 16 MiB、单 ref 1 MiB、ref 目录嵌套 128 层、alternates 最多 4096 个对象目录、无 mmap 时 pack/index 最多同时开 64 个文件、单仓库最多 800 万个 object id 参与可达性分类。超限是错误（不是静默跳过），大仓库改用 `--include=objects` 替代 `--include=unreachable-objects`。
  - rename 检测在相似度打平时配对可能不同（继承自 go-git），可能导致两次运行命中的行不同。需要可比对的结果时用 `-o x.json` 存 JSON 再 diff，别肉眼比对终端。

扫工作树用 `betterleaks filesystem <path>`：注意它**不读 `.gitignore`**，会连构建产物一起遍历（全局配置已排除 `.git/`、`.uvcache/`、`.gradle/`、`.kotlin/`，以及内嵌默认的 `node_modules/`、lockfile、图片字体等；但未排除 `build/`、`dist/`、`target/` 等通用产物名）；在大仓库上先确认路径范围，别直接扫仓库根。

**回报只给 `rule_id` / 路径 / 行号，不复述 `match.value`。**
