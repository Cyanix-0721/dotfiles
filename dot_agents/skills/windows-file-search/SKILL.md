---
name: windows-file-search
description: "文件检索分工——Windows 盘（C、D、E 盘）按文件名/后缀/大小/修改时间找文件用 Everything CLI（es.exe），WSL ext4 找名用 fd、任意找内容用 rg。需要在大盘上快速定位文件、或纠结该用 find 还是 es.exe 时加载。"
---

# 文件检索分工（Windows 侧优先 Everything CLI）

**硬规则：在 Windows 盘（C:/D:/E:）上按「文件名 / 后缀 / 大小 / 修改时间」找文件，一律先用 `es.exe`，不要用 `find` / `fdfind` 遍历 `/mnt/c`。**

- 已 `scoop install everything-cli`：`C:\Users\Administrator\scoop\shims\es.exe`（ES 1.1.1.39；后端 Everything 1.5.0.1423b 常驻，索引 `C:,D:,E:` 约 287 万对象）。
- WSL 侧可直接裸名调用（shim 在 drvfs 下可执行，无需 `chmod +x`），实测 ≈0.15s/次。

**为什么**：`/mnt/c` 是 9p/drvfs（`trans=fd`），每次 stat 都是一次 9p 往返；`es.exe` 直接查预建的 NTFS USN 索引。差距是数量级：

| 任务 | `es.exe` | WSL `find` / `fdfind` |
| --- | --- | --- |
| C: 全部 `*.mp4` | 0.07–0.15s，4274 条 | 90s 超时，只数到 109 |
| C:\Users 下 `*.scoop*` | 0.08s | 29.9s |
| E: 按大小排序 top20 | 0.11s | 24s（`sort` 还被 SIGPIPE 打断） |
| `find .../scoop -type f`（47 万文件） | — | 2m4s；换 `fdfind` 仍 56s |

**三个边界（越过就换工具）**：
1. **看不到 WSL ext4**：`es.exe -get-result-count "wsl.localhost"` = 0。WSL 仓库内找文件仍用 `fd` / `fdfind`。
2. **不索引内容**：`content_indexing_enabled=0`（`Everything.ini:989`）⇒ `content:` 查询会挂死（实测 >120s 无返回）。找文件内容一律 `rg`。
3. `Everything.exe` 是 GUI 二进制，**没有** `-export-csv`（写它会弹搜索窗口并挂死）；只有 `es.exe` 有导出开关。

**编码两条坑（均实测踩过）**：
- 搜索词必须是 UTF-8 原文：`es.exe -get-result-count "青水庵"` → 23；GBK 转码后 → 0。
- stdout 是 GBK 字节（`-json` 也一样），不是 UTF-8；直接管道给下游会乱码。
  - 只要文本路径：`es.exe … | iconv -f GBK -t UTF-8`
  - 要结构化：`es.exe … -export-csv "C:\\…\\out.csv" -utf8-bom`（产物是真 UTF-8 BOM + CRLF）。⚠️ `/mnt/c` 对 WSL 只读（挂载带 `ro`）⇒ 导出文件只能落 Windows 侧路径，再由 WSL 读。

**常用调用**：
```bash
es.exe -n 20 -sort size -size -path 'E:\' '*'   # 某盘最大文件
es.exe -n 10 'dm:today' -sort dm                 # 今天改过的
es.exe -path 'D:\' 'pyproject.toml'              # 某目录下找名
es.exe -regex '^requirements.*\.txt$'            # 正则
es.exe -get-result-count 'ext:pdf'               # 只数条数
```

**速查表**：Windows 盘找名 → `es.exe`；WSL ext4 找名 → `fd`；任一找内容 → `rg`。
