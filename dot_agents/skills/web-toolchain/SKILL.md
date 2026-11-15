---
name: web-toolchain
description: "DSH web profile 的网页搜索/抓取与 MCP 工具链——web_search/web_fetch 走哪条链、firecrawl/playwright/chrome-devtools/markitdown/magpie-image 怎么用、哪些坑。需要联网检索、抓网页、做 JS 渲染或结构化提取、或排查 web_search/web_fetch 行为时加载。"
---

# 网页工具链与 MCP 工具（DSH web profile）

**升级链（成本从低到高，日常只走前两级）**：`web_search` → `web_fetch` → `firecrawl__firecrawl_scrape`（JS 渲染/结构化）→ `firecrawl__firecrawl_crawl` / `firecrawl__firecrawl_map` / `firecrawl__firecrawl_agent`（站点级/批量）。

## 搜索与抓取
- web profile 装 `dsh-search-fetch-router`，`web.searchProvider` / `web.fetchProvider` pin 到它（插件自带 bundle patch；profile patch 里只放 key refs）。
- 搜索链：按 providerOrder 默认 `tavily → exa → firecrawl`，全失败回落官方 `deepseek-official`。抓取链：Tavily `/extract` → Exa `/contents` → Firecrawl `/scrape`，全失败回落本机 `http`。
- key 以 credentials 引用名存在 `C:\Users\Administrator\.dsh\profiles\web\cordis.patch.yml`（如 `TAVILY_GitHub` / `EXA_Google` / `FIRECRAWL_GitHub`），值在 `~/.dsh/.credentials.yaml`（0600）或环境层，永不进 patch 本体。
- 输入框左侧「搜索增强」开关可一键旁路（关 = 不用第三方 key，搜索走官方、抓取走本机 http）。
- 纪律：`web_search` 默认 Tavily（basic 1 credit/次，免费 1000/月）。`firecrawl__firecrawl_search` 同免费档（1000 credits/月，搜索 2 credits/10 条 = 500 次/月），更慢更重，只在要更多结果/更好摘要时用。
- 保护：「设置 → 插件 → 内置插件设置 → 网络搜索」页**不要点保存**（会把 provider 写回官方 id）。

## 抓取（MCP 高级）
- 单页正文优先 `web_fetch`（是否走第三方 key 取决于当前 profile）。
- JS 渲染 / 结构化提取 / 站点爬取 / 论文与 GitHub 检索 → `firecrawl__*`。`firecrawl__firecrawl_scrape` 的 `objective` **必填**，漏传报 `-32602`；`firecrawl__firecrawl_extract` **不存在**，结构化研究用 `firecrawl__firecrawl_agent`；`firecrawl__firecrawl_map` 只列 URL 不抓正文。
- **禁止** curl / wget 裸抓网页（无 JS 渲染、易被反爬；内网/本地服务除外）。

## MCP 工具（经 magpie MCP 路由）
路由把 5 个 server 合成一个 `magpie` 条目，背后 93 个工具。只有两个入口：`mcp__magpie__find_tools`（按 query 查工具，空 query 列全部）和 `mcp__magpie__call_tool`（按名执行）。**先 find 再 call**，不要猜工具名。按需加载：工具数 > 10 且 dsh 不在 magpie 的 `hubSearchesItself` 名单里。
- `firecrawl__*`（34）— 抓取/爬取/搜索/结构化研究/论文检索/站点监控/开发者与政务搜索。
- `context7__*`（2）— 库/框架版本文档（不属于搜索链）。
- `playwright__*`（25）— 浏览器自动化，独立 profile 不碰登录态。
- `chrome-devtools__*`（32）— 前端性能剖析（`performance_start_trace`、`lighthouse_audit`、`take_heapsnapshot`）、网络响应体、CSS。与 playwright 不重复，性能问题用它。
- `find_tools` **不要带 `server` 参数查 `markitdown`**：走 direct 不在路由，会报 `No server called markitdown is behind this one`。

## 路由外 MCP（`mcp__` 前缀，独立条目）
- `mcp__markitdown__convert_to_markdown` — 文档转 markdown，读本地路径。
- `mcp__magpie-image__*`（3）— 文生图/图生视频；在 library.json 标 shared，但对本地 agent 直连，不占路由 93 名额。
