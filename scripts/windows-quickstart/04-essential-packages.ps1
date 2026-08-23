#!/usr/bin/env pwsh

<#
.SYNOPSIS
    必备软件包安装 / Essential Applications Installation

.DESCRIPTION
    安装日常使用的应用程序
    Install daily use applications
#>

param(
    [switch]$AutoYes
)

$ErrorActionPreference = "Stop"

# 加载公共函数
. "$PSScriptRoot/00-common.ps1"

# 初始化自动确认模式
Initialize-AutoYes

Write-Header "必备软件包安装 / Essential Applications Installation"

# 检查 Scoop
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Err "Scoop 未安装，请先运行系统基础环境配置脚本 / Scoop not installed, please run the system foundation setup script first"
    throw "Scoop 未安装 / Scoop not installed"
}

# 浏览器
Write-Header "浏览器 / Web Browsers"

$browserOptions = @(
    @{ Name = "zen-browser"; Desc = "Zen Browser (Firefox 引擎浏览器 / Firefox-based browser)" }
    @{ Name = "helium"; Desc = "Helium（Chromium 稳定版 / Stable）" }
    @{ Name = "helium-pre"; Desc = "Helium Pre（Chromium 预发布版 / Pre-release）" }
    @{ Name = "ungoogled-chromium"; Desc = "Ungoogled Chromium (隐私增强版 Chrome / Privacy-enhanced Chrome)" }
)

# 检测已安装的浏览器（使用缓存的 scoop list）
$installedBrowsers = @()
foreach ($opt in $browserOptions) {
    if (Test-ScoopInstalled $opt.Name) {
        $installedBrowsers += $opt.Name
    }
}

if ($installedBrowsers.Count -eq $browserOptions.Count) {
    Write-Ok "所有浏览器已安装 / All browsers already installed"
}
else {
    $install = Confirm-Install "是否安装浏览器？(Y/n) / Install browsers? (Y/n)"
    if ($install -notmatch '^[Nn]$') {
        Write-Note "请选择要安装的浏览器（默认 1）/ Select browsers to install (default 1):"
        Write-Host "  [1] zen-browser + helium（默认 / default）"
        for ($i = 0; $i -lt $browserOptions.Count; $i++) {
            $state = if ($installedBrowsers -contains $browserOptions[$i].Name) { "（已安装 / installed）" } else { "" }
            Write-Host "  [$($i + 2)] $($browserOptions[$i].Desc) $state"
        }
        Write-Host "  [$($browserOptions.Count + 2)] 全部安装 / Install all"

        $choice = Read-Host "请输入编号（默认 1）/ Enter a number (default 1)"
        if ($choice -match '^\d+$') { $selection = [int]$choice } else { $selection = 1 }

        if ($selection -eq 1) {
            # 默认：同时安装 zen-browser + helium（跳过已安装）
            foreach ($name in @("zen-browser", "helium")) {
                if (Test-ScoopInstalled $name) {
                    Write-Ok "$name 已安装 / $name is already installed"
                }
                else {
                    scoop install $name
                    Write-Ok "$name 安装完成 / $name installation completed"
                }
            }
        }
        elseif ($selection -ge 2 -and $selection -le ($browserOptions.Count + 1)) {
            $target = $browserOptions[$selection - 2]
            if (Test-ScoopInstalled $target.Name) {
                Write-Ok "$($target.Name) 已安装 / $($target.Name) is already installed"
            }
            else {
                scoop install $target.Name
                Write-Ok "$($target.Name) 安装完成 / $($target.Name) installation completed"
            }
        }
        elseif ($selection -eq ($browserOptions.Count + 2)) {
            foreach ($opt in $browserOptions) {
                if ($installedBrowsers -notcontains $opt.Name) {
                    scoop install $opt.Name
                    Write-Ok "$($opt.Name) 安装完成 / $($opt.Name) installation completed"
                }
            }
        }
        else {
            Write-Warn "无效输入，默认安装 zen-browser + helium / Invalid input, installing zen-browser + helium by default"
            foreach ($name in @("zen-browser", "helium")) {
                if (Test-ScoopInstalled $name) {
                    Write-Ok "$name 已安装 / $name is already installed"
                }
                else {
                    scoop install $name
                    Write-Ok "$name 安装完成 / $name installation completed"
                }
            }
        }
        Reset-ScoopCache
    }
}

# 效率工具
Write-Header "效率工具 / Productivity Tools"

$productivityApps = @{
    "obsidian"       = @{ Desc = "Obsidian (笔记软件 / Note-taking app)"; Global = $false }
    "draw.io"        = @{ Desc = "Draw.io (流程图绘制 / Diagram drawing)"; Global = $false }
    "stranslate"     = @{ Desc = "Stranslate (翻译工具 / Translation tool)"; Global = $false }
    "umi-ocr"        = @{ Desc = "Umi OCR (OCR 工具 / OCR tool)"; Global = $false }
    "quickclipboard" = @{ Desc = "QuickClipboard (剪贴板管理工具 / Clipboard manager)"; Global = $false }
    "zeal"           = @{ Desc = "Zeal (离线 API 文档浏览器 / Offline API documentation browser)"; Global = $false }
}

Install-ScoopPackages $productivityApps

# 密码管理器
Write-Header "密码管理器 / Password Managers"

$passwordManagers = @{
    "keepassxc" = @{ Desc = "KeePassXC"; Global = $false; Default = $true }
}

Install-ScoopPackages $passwordManagers

# 邮件客户端
Write-Header "邮件客户端 / Email Clients"

$emailClients = @{
    "thunderbird" = @{ Desc = "Thunderbird"; Global = $false; Default = $true }
}

Install-ScoopPackages $emailClients

# 通讯软件
Write-Header "通讯软件 / Communication Apps"

$commApps = @{
    "vesktop" = @{ Desc = "Vesktop (Discord 客户端 / Discord client)"; Global = $false }
    "telegram" = @{ Desc = "Telegram (Telegram 客户端 / Telegram client)"; Global = $false }
}

Install-ScoopPackages $commApps

# 文件同步
Write-Header "文件同步 / File Synchronization"

$syncApps = @{
    "syncthing"     = @{ Desc = "Syncthing (P2P 文件同步 / P2P file sync)"; Global = $false; Default = $true }
    "syncthingtray" = @{ Desc = "Syncthing Tray (系统托盘工具 / System tray utility)"; Global = $false; Default = $true }
    "localsend"     = @{ Desc = "LocalSend (局域网文件传输 / LAN file transfer)"; Global = $false; Default = $true }
    "winscp"        = @{ Desc = "WinSCP (SFTP/FTP 文件传输 / SFTP/FTP file transfer)"; Global = $false; Default = $true }
}

Install-ScoopPackages $syncApps

# 远程控制
Write-Header "远程控制 / Remote Control"

$remoteApps = @{
    "rustdesk" = @{ Desc = "RustDesk (远程桌面工具 / Remote desktop)"; Global = $false; Default = $true }
}

Install-ScoopPackages $remoteApps

# 下载工具
Write-Header "下载工具 / Download Tools"

$downloadApps = @{
    "qbittorrent-enhanced" = @{ Desc = "qBittorrent Enhanced (BT 下载 / BT download)"; Global = $false }
    "motrix-next"         = @{ Desc = "Motrix Next (全能下载管理器 / Full-featured download manager)"; Global = $false }
}

Install-ScoopPackages $downloadApps

# 多媒体
Write-Header "多媒体工具 / Multimedia Tools"

$multimediaTools = @{
    "snipaste"    = @{ Desc = "Snipaste (截图工具 / Screenshot tool)"; Global = $false }
    "screentogif" = @{ Desc = "ScreenToGif (屏幕录制 GIF 工具 / Screen recording GIF tool)"; Global = $false }
    "imagemagick" = @{ Desc = "ImageMagick (图像处理工具 / Image processing tool)"; Global = $false }
    "ffmpeg"      = @{ Desc = "FFmpeg (多媒体处理工具 / Multimedia processing tool)"; Global = $false }
}

Install-ScoopPackages $multimediaTools

# 阅读器
Write-Header "阅读器 / Readers"

$readerApps = @{
    "kavita"     = @{ Desc = "Kavita (漫画/电子书服务器 / Comic/E-book server)"; Global = $false }
    "sumatrapdf" = @{ Desc = "SumatraPDF (PDF 阅读器 / PDF reader)"; Global = $false }
}

Install-ScoopPackages $readerApps

# 字体
Write-Header "字体 / Fonts"

$fonts = @{
    "JetBrainsMono-NF-Mono" = @{ Desc = "JetBrains Mono Nerd Font"; Global = $false; Default = $true }
    "SarasaGothic-SC"       = @{ Desc = "Sarasa Gothic (更纱黑体)"; Global = $false; Default = $true }
}

Install-ScoopPackages $fonts

# 游戏平台
Write-Header "游戏平台 / Game Platforms"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过游戏平台安装 / winget not installed, skipping game platforms installation"
}
else {
    $wingApps = @{ 
        "Valve.Steam"                 = @{ Desc = "Steam (游戏平台 / Steam)"; InstallArgs = @("--exact", "--silent") }
        "EpicGames.EpicGamesLauncher" = @{ Desc = "Epic Games Launcher"; InstallArgs = @("--exact", "--silent") }
        "GOG.Galaxy"                  = @{ Desc = "GOG Galaxy"; InstallArgs = @("--exact", "--silent") }
    }
    Install-WingetApps $wingApps -Force
}

Write-Header "必备软件包安装完成 / Essential applications installation completed"
Write-Note "当前已安装的所有应用 / All currently installed applications:"
scoop list
