# 包清单数据文件 / Package manifest data
# 供 windows 脚本经 Get-PackageSection 读取；纯数据，无逻辑。
# Each section: @{ Installer = 'scoop'|'winget'; Packages = @( <entry>, ... ) }
#   scoop  entry: @{ Name='<pkg>'; Desc='...'; [Global=$true]; [Default=$false]; [PostNote=@(...)]; [AlreadyNote=@(...)] }
#   winget entry: @{ Id='<id>';   Desc='...'; [InstallArgs=@('--exact','--silent')] }

@{
    Sections = @{

        # ===== 01-system-foundation.ps1 =====
        'foundation.vcredist' = @{
            Installer = 'winget'
            Packages  = @(
                @{ Id = 'Microsoft.VCRedist.2005.x64'; Desc = 'VC++ 2005 x64'; InstallArgs = @('--exact', '--silent') }
                @{ Id = 'Microsoft.VCRedist.2005.x86'; Desc = 'VC++ 2005 x86'; InstallArgs = @('--exact', '--silent') }
                @{ Id = 'Microsoft.VCRedist.2008.x64'; Desc = 'VC++ 2008 x64'; InstallArgs = @('--exact', '--silent') }
                @{ Id = 'Microsoft.VCRedist.2008.x86'; Desc = 'VC++ 2008 x86'; InstallArgs = @('--exact', '--silent') }
                @{ Id = 'Microsoft.VCRedist.2010.x64'; Desc = 'VC++ 2010 x64'; InstallArgs = @('--exact', '--silent') }
                @{ Id = 'Microsoft.VCRedist.2010.x86'; Desc = 'VC++ 2010 x86'; InstallArgs = @('--exact', '--silent') }
                @{ Id = 'Microsoft.VCRedist.2012.x64'; Desc = 'VC++ 2012 x64'; InstallArgs = @('--exact', '--silent') }
                @{ Id = 'Microsoft.VCRedist.2012.x86'; Desc = 'VC++ 2012 x86'; InstallArgs = @('--exact', '--silent') }
                @{ Id = 'Microsoft.VCRedist.2013.x64'; Desc = 'VC++ 2013 x64'; InstallArgs = @('--exact', '--silent') }
                @{ Id = 'Microsoft.VCRedist.2013.x86'; Desc = 'VC++ 2013 x86'; InstallArgs = @('--exact', '--silent') }
                @{ Id = 'Microsoft.VCRedist.2015+.x64'; Desc = 'VC++ 2015-2022 x64'; InstallArgs = @('--exact', '--silent') }
                @{ Id = 'Microsoft.VCRedist.2015+.x86'; Desc = 'VC++ 2015-2022 x86'; InstallArgs = @('--exact', '--silent') }
            )
        }
        'foundation.webview2' = @{
            Installer = 'winget'
            Packages  = @(
                @{ Id = 'Microsoft.EdgeWebView2Runtime'; Desc = 'WebView2 Runtime'; InstallArgs = @('--exact', '--silent') }
            )
        }

        # ===== 02-development-tools.ps1 =====
        'dev.editors' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'vscode'; Desc = 'Visual Studio Code'; Global = $false }
                @{ Name = 'neovim'; Desc = 'Neovim'; Global = $false }
            )
        }
        'dev.gitTools' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'lazygit'; Desc = 'lazygit'; Global = $false }
                @{ Name = 'delta'; Desc = 'delta'; Global = $false }
                @{ Name = 'gh'; Desc = 'gh (GitHub CLI)'; Global = $false }
            )
        }
        'dev.shellTools' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'shellcheck'; Desc = 'shellcheck (bash 静态检查 / bash static analysis)'; Global = $false }
                @{ Name = 'shfmt'; Desc = 'shfmt (bash 格式化 / bash formatter)'; Global = $false }
            )
        }
        'dev.svnTools' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'sliksvn'; Desc = 'SlikSVN (命令行 / Command-line)'; Global = $false }
            )
        }
        'dev.versionManager' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'mise'; Desc = 'mise (多语言版本管理器 / Multi-language version manager)'; Global = $false }
                @{ Name = 'fnm'; Desc = 'fnm (Node.js 版本管理器 / Node.js version manager)'; Global = $false }
            )
        }
        'dev.nodePkg' = @{
            Installer = 'scoop'
            Packages  = @(
                @{
                    Name     = 'pnpm'
                    Desc     = 'pnpm (Node 包管理器 / Node package manager)'
                    Global   = $false
                    PostNote = @(
                        'pnpm 为独立二进制，运行自身无需 Node / pnpm is a standalone binary, no Node needed to run itself'
                        "运行 JS 项目仍需 Node：请先执行 fnm install --lts / Running JS projects still needs Node: run 'fnm install --lts' first"
                    )
                }
            )
        }
        'dev.pythonPkg' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'uv'; Desc = 'uv (现代 Python 包管理器，推荐个人开发 / Modern Python package manager, recommended)'; Global = $false }
                @{
                    Name        = 'miniconda3'
                    Desc        = 'miniconda3 (适用于公司项目或科学计算 / For company projects or scientific computing)'
                    Global      = $false
                    Default     = $false
                    PostNote    = @(
                        '配置 Miniconda 不自动激活... / Configuring Miniconda to not auto-activate...'
                        '运行以下命令禁用自动激活 / Run to disable auto-activation: conda config --set auto_activate false'
                        '需要使用时显式激活 / Activate explicitly: conda activate <env_name>'
                    )
                    AlreadyNote = @(
                        '请运行以下命令禁用自动激活 / Run to disable auto-activation: conda config --set auto_activate false'
                    )
                }
            )
        }
        'dev.api' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'postman'; Desc = 'Postman'; Global = $false }
                @{ Name = 'hoppscotch'; Desc = 'Hoppscotch'; Global = $false }
            )
        }
        'dev.db' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'dbeaver'; Desc = 'DBeaver (数据库管理工具 / Database management tool)'; Global = $false }
                @{ Name = 'dbx'; Desc = 'DBX (轻量跨平台数据库客户端 / Lightweight cross-platform database client)'; Global = $false }
            )
        }
        'dev.misc' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'jq'; Desc = 'jq (JSON 处理器 / JSON processor)'; Global = $false }
                @{ Name = 'pandoc'; Desc = 'Pandoc (文档转换器 / Document converter)'; Global = $true }
            )
        }
        'dev.ai' = @{
            Installer = 'scoop'
            Packages  = @(
                @{
                    Name     = 'lmstudio'
                    Desc     = 'lmstudio (本地大模型运行器 / Local LLM runner)'
                    Global   = $false
                    PostNote = @(
                        "注意 CLI 名为 lms，不是 lmstudio / Note the CLI is 'lms', not 'lmstudio'"
                        '启动服务 / Start the server: lms server start（状态 lms server status，停止 lms server stop）'
                        '下载模型 / Pull a model: lms get qwen3-8b（已下载 lms ls，已加载 lms ps）'
                        '首次使用 lms 前需先启动一次 LM Studio 图形界面（依赖其守护进程）/ Launch the LM Studio app once before using lms (it needs the daemon)'
                    )
                }
                @{
                    Name     = 'rtk'
                    Desc     = 'rtk (CLI 代理，压缩常见命令输出以减少 LLM token 消耗 / CLI proxy that cuts token usage on common dev commands)'
                    Global   = $false
                    PostNote = @(
                        '用法：在命令前加 rtk，例如 rtk git status、rtk ls、rtk cargo build / Usage: prefix commands with rtk, e.g. rtk git status'
                        '可通过 rtk gain 查看节省的 token 统计 / Check token savings with: rtk gain'
                    )
                }
                @{
                    Name     = 'magpie-ai-latest'
                    Desc     = 'magpie (AI 编程助手的模型/供应商/网关管理器 / Unified model, provider and gateway manager for AI coding agents)'
                    Global   = $false
                    PostNote = @(
                        '数据目录为 scoop 持久化目录（<scoop root>\persist\magpie-ai\data）/ Data lives in the Scoop persist dir (<scoop root>\persist\magpie-ai\data)'
                        '若曾用旧版本，需手动把 %USERPROFILE%\.config\magpie 的数据迁移到上述目录 / Older versions stored data in %USERPROFILE%\.config\magpie, migrate it manually if needed'
                    )
                }
                @{ Name = 'codex'; Desc = 'OpenAI Codex CLI (AI 编程助手 / AI coding agent)'; Global = $false }
            )
        }

        # ===== 03-system-tools.ps1 =====
        'sys.sysinternals' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'sysmon'; Desc = 'Sysmon (系统监视器 / System Monitor)'; Global = $false }
                @{ Name = 'handle'; Desc = 'Handle (句柄查看工具 / View open handles)'; Global = $false }
                @{ Name = 'autoruns'; Desc = 'Autoruns (启动项管理工具 / Startup manager)'; Global = $false }
                @{ Name = 'autologon'; Desc = 'AutoLogon (自动登录工具 / Auto login utility)'; Global = $true }
                @{ Name = 'process-explorer'; Desc = 'Process Explorer (高级任务管理器 / Advanced Task Manager)'; Global = $false }
                @{ Name = 'procmon'; Desc = 'Process Monitor (文件/注册表监视 / File & Registry monitor)'; Global = $false }
                @{ Name = 'tcpview'; Desc = 'TCPView (网络连接查看 / TCP/UDP connection viewer)'; Global = $false }
                @{ Name = 'sigcheck'; Desc = 'Sigcheck (文件签名检查 / File signature checker)'; Global = $false }
            )
        }
        'sys.monitor' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'fastfetch'; Desc = 'fastfetch (系统信息显示 / System information display)'; Global = $false }
                @{ Name = 'trafficmonitor'; Desc = 'TrafficMonitor (网速监控悬浮窗 / Network traffic monitor)'; Global = $false }
            )
        }
        'sys.fileMgr' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'yazi'; Desc = 'Yazi (终端文件管理器 / Terminal file manager)'; Global = $false; PostNote = @('提示：Yazi 会自动安装以下依赖：imagemagick, poppler, resvg / Note: Yazi auto-installs deps: imagemagick, poppler, resvg') }
            )
        }
        'sys.compression' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = '7zip'; Desc = '7zip (压缩/解压工具 / Archive utility)'; Global = $false }
                @{ Name = 'peazip'; Desc = 'PeaZip (压缩/解压工具 / Archive utility)'; Global = $false }
            )
        }
        'sys.winTools' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'everything-beta'; Desc = 'Everything (快速文件搜索 / Fast file search)'; Global = $false }
                @{ Name = 'everything-cli'; Desc = 'Everything CLI (命令行文件搜索 / Command-line file search)'; Global = $false }
                @{ Name = 'fancontrol'; Desc = 'FanControl (风扇控制工具 / Fan control utility)'; Global = $false }
                @{ Name = 'hwinfo'; Desc = 'HWiNFO (系统信息与诊断工具 / System information and diagnostics)'; Global = $false }
                @{ Name = 'y-cruncher'; Desc = 'Y-Cruncher (高性能计算工具 / High-performance computing tool)'; Global = $false }
                @{ Name = 'krokiet'; Desc = 'Krokiet (图片查重工具 / picture duplicate finder)'; Global = $false }
                @{ Name = 'ventoy'; Desc = 'Ventoy (多合一启动盘制作工具 / Multi-boot USB creator)'; Global = $false }
                @{ Name = 'rufus'; Desc = 'Rufus (USB 启动盘制作工具 / USB bootable creator)'; Global = $false }
                @{ Name = 'wiztree'; Desc = 'WizTree (磁盘空间分析工具 / Disk space analyzer)'; Global = $false }
                @{ Name = 'spacesniffer'; Desc = 'SpaceSniffer (磁盘空间可视化工具 / Disk space visualizer)'; Global = $false }
                @{ Name = 'memreduct'; Desc = 'Mem Reduct (内存优化工具 / Memory optimizer)'; Global = $false }
                @{ Name = 'msiafterburner'; Desc = 'MSI Afterburner (GPU 超频与监控 / GPU overclocking and monitoring)'; Global = $false }
                @{ Name = 'rtss'; Desc = 'RivaTuner Statistics Server (OSD & FPS 限制 / OSD & FPS limiter)'; Global = $false }
                @{ Name = 'ddu'; Desc = 'Display Driver Uninstaller (显卡驱动清理工具 / GPU driver cleaner)'; Global = $false }
                @{ Name = 'quicklook'; Desc = 'QuickLook (空格键快速预览文件 / File preview with spacebar)'; Global = $false }
                @{ Name = 'geekuninstaller'; Desc = 'Geek Uninstaller (强力卸载工具 / Thorough uninstaller)'; Global = $false }
                @{ Name = 'nircmd'; Desc = 'NirCmd (命令行小工具集合 / Command-line utility collection)'; Global = $false }
            )
        }
        'sys.openHashTab' = @{
            Installer = 'winget'
            Packages  = @(
                @{ Id = 'namazso.OpenHashTab'; Desc = 'OpenHashTab (文件哈希右键扩展 / File Hash Context Menu)'; InstallArgs = @('--exact', '--silent') }
            )
        }
        'sys.term' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'windows-terminal'; Desc = 'Windows Terminal (微软官方终端 / Microsoft official terminal)'; Global = $false }
                @{ Name = 'less'; Desc = 'less (终端分页器 / Terminal pager)'; Global = $false }
                @{ Name = 'microsoft-coreutils'; Desc = 'GNU Coreutils (ls/cp/mv 等 Linux 核心命令 / GNU core utilities)'; Global = $false }
                @{ Name = 'starship'; Desc = 'Starship (跨平台命令行提示符 / Cross-platform shell prompt)'; Global = $false }
                @{ Name = 'zoxide'; Desc = 'zoxide (智能目录跳转 / Smarter cd command)'; Global = $false }
                @{ Name = 'fzf'; Desc = 'fzf (模糊查找器 / Fuzzy finder)'; Global = $false }
                @{ Name = 'ripgrep'; Desc = 'ripgrep (快速搜索工具 / Fast search tool)'; Global = $false }
                @{ Name = 'fd'; Desc = 'fd (快速文件查找 / Fast file finder)'; Global = $false }
                @{ Name = 'bat'; Desc = 'bat (cat 增强版 / cat with syntax highlighting)'; Global = $false }
                @{ Name = 'eza'; Desc = 'eza (ls 增强版 / Modern ls replacement)'; Global = $false }
            )
        }
        'sys.network' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'nmap'; Desc = 'nmap (网络扫描工具，含 ncat / Network scanner, includes ncat)'; Global = $false }
                @{ Name = 'scrcpy'; Desc = 'scrcpy (Android 投屏工具 / Android screen mirroring)'; Global = $false }
                @{ Name = 'mkcert'; Desc = 'mkcert (本地 HTTPS 证书 / Local HTTPS certificates)'; Global = $false }
                @{ Name = 'wireshark'; Desc = 'wireshark (网络协议分析器 / Network protocol analyzer)'; Global = $false }
            )
        }
        'sys.openSsh' = @{
            Installer = 'winget'
            Packages  = @(
                @{ Id = 'Microsoft.OpenSSH.Preview'; Desc = 'OpenSSH Preview (Microsoft 官方 OpenSSH 预览版 / Microsoft OpenSSH preview)'; InstallArgs = @('--exact', '--silent') }
            )
        }

        # ===== 04-essential-packages.ps1 =====
        'ess.productivity' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'obsidian'; Desc = 'Obsidian (笔记软件 / Note-taking app)'; Global = $false }
                @{ Name = 'draw.io'; Desc = 'Draw.io (流程图绘制 / Diagram drawing)'; Global = $false }
                @{ Name = 'umi-ocr'; Desc = 'Umi OCR (OCR 工具 / OCR tool)'; Global = $false }
                @{ Name = 'zeal'; Desc = 'Zeal (离线 API 文档浏览器 / Offline API documentation browser)'; Global = $false }
            )
        }
        'ess.password' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'keepassxc'; Desc = 'KeePassXC'; Global = $false }
            )
        }
        'ess.email' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'thunderbird'; Desc = 'Thunderbird'; Global = $false }
            )
        }
        'ess.comm' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'vesktop'; Desc = 'Vesktop (Discord 客户端 / Discord client)'; Global = $false }
                @{ Name = 'telegram'; Desc = 'Telegram (Telegram 客户端 / Telegram client)'; Global = $false }
            )
        }
        'ess.sync' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'syncthing'; Desc = 'Syncthing (P2P 文件同步 / P2P file sync)'; Global = $false }
                @{ Name = 'syncthingtray'; Desc = 'Syncthing Tray (系统托盘工具 / System tray utility)'; Global = $false }
                @{ Name = 'localsend'; Desc = 'LocalSend (局域网文件传输 / LAN file transfer)'; Global = $false }
                @{ Name = 'winscp'; Desc = 'WinSCP (SFTP/FTP 文件传输 / SFTP/FTP file transfer)'; Global = $false }
            )
        }
        'ess.remote' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'rustdesk'; Desc = 'RustDesk (远程桌面工具 / Remote desktop)'; Global = $false }
            )
        }
        'ess.download' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'qbittorrent-enhanced'; Desc = 'qBittorrent Enhanced (BT 下载 / BT download)'; Global = $false }
                @{ Name = 'rayburst'; Desc = 'Rayburst (全能下载管理器 / Full-featured download manager)'; Global = $false }
            )
        }
        'ess.multimedia' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'snowshot'; Desc = 'snowshot (截图工具 / Screenshot tool)'; Global = $false }
                @{ Name = 'screentogif'; Desc = 'ScreenToGif (屏幕录制 GIF 工具 / Screen recording GIF tool)'; Global = $false }
                @{ Name = 'imagemagick'; Desc = 'ImageMagick (图像处理工具 / Image processing tool)'; Global = $false }
                @{ Name = 'ffmpeg'; Desc = 'FFmpeg (多媒体处理工具 / Multimedia processing tool)'; Global = $false }
            )
        }
        'ess.readers' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'kavita'; Desc = 'Kavita (漫画/电子书服务器 / Comic/E-book server)'; Global = $false }
                @{ Name = 'sumatrapdf'; Desc = 'SumatraPDF (PDF 阅读器 / PDF reader)'; Global = $false }
            )
        }
        'ess.fonts' = @{
            Installer = 'scoop'
            Packages  = @(
                @{ Name = 'JetBrainsMono-NF-Mono'; Desc = 'JetBrains Mono Nerd Font'; Global = $false }
                @{ Name = 'SarasaGothic-SC'; Desc = 'Sarasa Gothic (更纱黑体)'; Global = $false }
            )
        }
        'ess.games' = @{
            Installer = 'winget'
            Packages  = @(
                @{ Id = 'Valve.Steam'; Desc = 'Steam (游戏平台 / Steam)'; Default = $false; InstallArgs = @('--exact', '--silent') }
                @{ Id = 'EpicGames.EpicGamesLauncher'; Desc = 'Epic Games Launcher'; Default = $false; InstallArgs = @('--exact', '--silent') }
                @{ Id = 'GOG.Galaxy'; Desc = 'GOG Galaxy'; Default = $false; InstallArgs = @('--exact', '--silent') }
            )
        }
    }
}
