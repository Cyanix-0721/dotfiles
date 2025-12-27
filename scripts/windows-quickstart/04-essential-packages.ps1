#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    必备软件包安装 / Essential Applications Installation

.DESCRIPTION
    安装日常使用的应用程序
    Install daily use applications
#>

$ErrorActionPreference = "Stop"

Write-Host "=== 必备软件包安装 / Essential Applications Installation ===" -ForegroundColor Cyan

# 检查 Scoop
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Error "Scoop 未安装，请先运行系统基础环境配置脚本 / Scoop not installed, please run the system foundation setup script first"
    exit 1
}

# 浏览器
Write-Host "`n=== 浏览器 / Web Browsers ===" -ForegroundColor Yellow

$browsers = @{
    "ungoogled-chromium" = @{ Desc = "Ungoogled Chromium (隐私增强版 Chrome / Privacy-enhanced Chrome)"; Global = $false }
}

foreach ($package in $browsers.GetEnumerator()) {
    $packageName = $package.Key
    $packageInfo = $package.Value
    
    if (-not (scoop list | Select-String -Pattern "^$packageName\s")) {
        $install = Read-Host "是否安装 $($packageInfo.Desc)？(y/N) / Install $($packageInfo.Desc)? (y/N)"
        if ($install -match '^[Yy]$') {
            if ($packageInfo.Global) {
                scoop install $packageName --global
                Write-Host "✓ $packageName 安装完成（全局） / $packageName installation completed (global)" -ForegroundColor Green
            }
            else {
                scoop install $packageName
                Write-Host "✓ $packageName 安装完成 / $packageName installation completed" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "✓ $packageName 已安装 / $packageName is already installed" -ForegroundColor Green
    }
}

# 办公软件
Write-Host "`n=== 办公软件 / Office Applications ===" -ForegroundColor Yellow

$officeApps = @{
    "obsidian" = @{ Desc = "Obsidian (笔记软件 / Note-taking app)"; Global = $false }
    "draw.io"  = @{ Desc = "Draw.io (流程图绘制 / Diagram drawing)"; Global = $false }
}

foreach ($app in $officeApps.GetEnumerator()) {
    $appName = $app.Key
    $appInfo = $app.Value
    
    if (-not (scoop list | Select-String -Pattern "^$appName\s")) {
        $install = Read-Host "是否安装 $($appInfo.Desc)？(y/N) / Install $($appInfo.Desc)? (y/N)"
        if ($install -match '^[Yy]$') {
            if ($appInfo.Global) {
                scoop install extras/$appName --global
                Write-Host "✓ $appName 安装完成（全局） / $appName installation completed (global)" -ForegroundColor Green
            }
            else {
                scoop install extras/$appName
                Write-Host "✓ $appName 安装完成 / $appName installation completed" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "✓ $appName 已安装 / $appName is already installed" -ForegroundColor Green
    }
}

# 密码管理器
Write-Host "`n=== 密码管理器 / Password Managers ===" -ForegroundColor Yellow

$passwordManagers = @{
    "keepassxc" = @{ Desc = "KeePassXC"; Global = $false }
}

foreach ($package in $passwordManagers.GetEnumerator()) {
    $packageName = $package.Key
    $packageInfo = $package.Value
    
    if (-not (scoop list | Select-String -Pattern "^$packageName\s")) {
        $install = Read-Host "是否安装 $($packageInfo.Desc)？(Y/n) / Install $($packageInfo.Desc)? (Y/n)"
        if ($install -notmatch '^[Nn]$') {
            if ($packageInfo.Global) {
                scoop install $packageName --global
                Write-Host "✓ $packageName 安装完成（全局） / $packageName installation completed (global)" -ForegroundColor Green
            }
            else {
                scoop install $packageName
                Write-Host "✓ $packageName 安装完成 / $packageName installation completed" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "✓ $packageName 已安装 / $packageName is already installed" -ForegroundColor Green
    }
}

# 邮件客户端
Write-Host "`n=== 邮件客户端 / Email Clients ===" -ForegroundColor Yellow

$emailClients = @{
    "thunderbird" = @{ Desc = "Thunderbird"; Global = $false }
}

foreach ($package in $emailClients.GetEnumerator()) {
    $packageName = $package.Key
    $packageInfo = $package.Value
    
    if (-not (scoop list | Select-String -Pattern "^$packageName\s")) {
        $install = Read-Host "是否安装 $($packageInfo.Desc)？(Y/n) / Install $($packageInfo.Desc)? (Y/n)"
        if ($install -notmatch '^[Nn]$') {
            if ($packageInfo.Global) {
                scoop install $packageName --global
                Write-Host "✓ $packageName 安装完成（全局） / $packageName installation completed (global)" -ForegroundColor Green
            }
            else {
                scoop install $packageName
                Write-Host "✓ $packageName 安装完成 / $packageName installation completed" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "✓ $packageName 已安装 / $packageName is already installed" -ForegroundColor Green
    }
}

# 通讯软件
Write-Host "`n=== 通讯软件 / Communication Apps ===" -ForegroundColor Yellow

$commApps = @{
    "vesktop" = @{ Desc = "Vesktop (Discord 客户端 / Discord client)"; Global = $false }
    "ayugram" = @{ Desc = "AyuGram (Telegram 客户端 / Telegram client)"; Global = $false }
}

foreach ($package in $commApps.GetEnumerator()) {
    $packageName = $package.Key
    $packageInfo = $package.Value
    
    if (-not (scoop list | Select-String -Pattern "^$packageName\s")) {
        $install = Read-Host "是否安装 $($packageInfo.Desc)？(y/N) / Install $($packageInfo.Desc)? (y/N)"
        if ($install -match '^[Yy]$') {
            if ($packageInfo.Global) {
                scoop install $packageName --global
                Write-Host "✓ $packageName 安装完成（全局） / $packageName installation completed (global)" -ForegroundColor Green
            }
            else {
                scoop install $packageName
                Write-Host "✓ $packageName 安装完成 / $packageName installation completed" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "✓ $packageName 已安装 / $packageName is already installed" -ForegroundColor Green
    }
}

# 文件同步
Write-Host "`n=== 文件同步 / File Synchronization ===" -ForegroundColor Yellow

$syncApps = @{
    "syncthing"     = @{ Desc = "Syncthing (P2P 文件同步 / P2P file sync)"; Global = $false }
    "syncthingtray" = @{ Desc = "Syncthing Tray (系统托盘工具 / System tray utility)"; Global = $false }
    "localsend"     = @{ Desc = "LocalSend (局域网文件传输 / LAN file transfer)"; Global = $false }
    "winscp"        = @{ Desc = "WinSCP (SFTP/FTP 文件传输 / SFTP/FTP file transfer)"; Global = $false }
}

foreach ($package in $syncApps.GetEnumerator()) {
    $packageName = $package.Key
    $packageInfo = $package.Value
    
    if (-not (scoop list | Select-String -Pattern "^$packageName\s")) {
        $install = Read-Host "是否安装 $($packageInfo.Desc)？(Y/n) / Install $($packageInfo.Desc)? (Y/n)"
        if ($install -notmatch '^[Nn]$') {
            if ($packageInfo.Global) {
                scoop install $packageName --global
                Write-Host "✓ $packageName 安装完成（全局） / $packageName installation completed (global)" -ForegroundColor Green
            }
            else {
                scoop install $packageName
                Write-Host "✓ $packageName 安装完成 / $packageName installation completed" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "✓ $packageName 已安装 / $packageName is already installed" -ForegroundColor Green
    }
}

# 远程控制
Write-Host "`n=== 远程控制 / Remote Control ===" -ForegroundColor Yellow

$remoteApps = @{
    "rustdesk" = @{ Desc = "RustDesk (远程桌面工具 / Remote desktop)"; Global = $false }
}

foreach ($package in $remoteApps.GetEnumerator()) {
    $packageName = $package.Key
    $packageInfo = $package.Value
    
    if (-not (scoop list | Select-String -Pattern "^$packageName\s")) {
        $install = Read-Host "是否安装 $($packageInfo.Desc)？(Y/n) / Install $($packageInfo.Desc)? (Y/n)"
        if ($install -notmatch '^[Nn]$') {
            if ($packageInfo.Global) {
                scoop install $packageName --global
                Write-Host "✓ $packageName 安装完成（全局） / $packageName installation completed (global)" -ForegroundColor Green
            }
            else {
                scoop install $packageName
                Write-Host "✓ $packageName 安装完成 / $packageName installation completed" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "✓ $packageName 已安装 / $packageName is already installed" -ForegroundColor Green
    }
}

# 下载工具
Write-Host "`n=== 下载工具 / Download Tools ===" -ForegroundColor Yellow

$downloadApps = @{
    "qbittorrent-enhanced" = @{ Desc = "qBittorrent Enhanced (BT 下载 / BT download)"; Global = $false }
    "ariang-native"        = @{ Desc = "AriaNg Native (Aria2 图形界面 / Aria2 GUI)"; Global = $false }
}

foreach ($package in $downloadApps.GetEnumerator()) {
    $packageName = $package.Key
    $packageInfo = $package.Value
    
    if (-not (scoop list | Select-String -Pattern "^$packageName\s")) {
        $install = Read-Host "是否安装 $($packageInfo.Desc)？(y/N) / Install $($packageInfo.Desc)? (y/N)"
        if ($install -match '^[Yy]$') {
            if ($packageInfo.Global) {
                scoop install $packageName --global
                Write-Host "✓ $packageName 安装完成（全局） / $packageName installation completed (global)" -ForegroundColor Green
            }
            else {
                scoop install $packageName
                Write-Host "✓ $packageName 安装完成 / $packageName installation completed" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "✓ $packageName 已安装 / $packageName is already installed" -ForegroundColor Green
    }
}

# 多媒体
Write-Host "`n=== 多媒体工具 / Multimedia Tools ===" -ForegroundColor Yellow

$multimediaTools = @{
    "snipaste"    = @{ Desc = "Snipaste (截图工具 / Screenshot tool)"; Global = $false }
    "imagemagick" = @{ Desc = "ImageMagick (图像处理工具 / Image processing tool)"; Global = $false }
}

foreach ($package in $multimediaTools.GetEnumerator()) {
    $packageName = $package.Key
    $packageInfo = $package.Value
    
    if (-not (scoop list | Select-String -Pattern "^$packageName\s")) {
        $install = Read-Host "是否安装 $($packageInfo.Desc)？(y/N) / Install $($packageInfo.Desc)? (y/N)"
        if ($install -match '^[Yy]$') {
            if ($packageInfo.Global) {
                scoop install $packageName --global
                Write-Host "✓ $packageName 安装完成（全局） / $packageName installation completed (global)" -ForegroundColor Green
            }
            else {
                scoop install $packageName
                Write-Host "✓ $packageName 安装完成 / $packageName installation completed" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "✓ $packageName 已安装 / $packageName is already installed" -ForegroundColor Green
    }
}

# 阅读器
Write-Host "`n=== 阅读器 / Readers ===" -ForegroundColor Yellow

$readerApps = @{
    "kavita" = @{ Desc = "Kavita (漫画/电子书服务器 / Comic/E-book server)"; Global = $false }
}

foreach ($package in $readerApps.GetEnumerator()) {
    $packageName = $package.Key
    $packageInfo = $package.Value
    
    if (-not (scoop list | Select-String -Pattern "^$packageName\s")) {
        $install = Read-Host "是否安装 $($packageInfo.Desc)？(y/N) / Install $($packageInfo.Desc)? (y/N)"
        if ($install -match '^[Yy]$') {
            if ($packageInfo.Global) {
                scoop install $packageName --global
                Write-Host "✓ $packageName 安装完成（全局） / $packageName installation completed (global)" -ForegroundColor Green
            }
            else {
                scoop install $packageName
                Write-Host "✓ $packageName 安装完成 / $packageName installation completed" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "✓ $packageName 已安装 / $packageName is already installed" -ForegroundColor Green
    }
}

# 字体
Write-Host "`n=== 字体 / Fonts ===" -ForegroundColor Yellow

$fonts = @{
    "JetBrainsMono-NF-Mono" = @{ Desc = "JetBrains Mono Nerd Font"; Global = $false }
    "SarasaGothic-SC"       = @{ Desc = "Sarasa Gothic (更纱黑体)"; Global = $false }
}

foreach ($package in $fonts.GetEnumerator()) {
    $packageName = $package.Key
    $packageInfo = $package.Value
    
    if (-not (scoop list | Select-String -Pattern "^$packageName\s")) {
        $install = Read-Host "是否安装 $($packageInfo.Desc)？(Y/n) / Install $($packageInfo.Desc)? (Y/n)"
        if ($install -notmatch '^[Nn]$') {
            if ($packageInfo.Global) {
                scoop install $packageName --global
                Write-Host "✓ $packageName 安装完成（全局） / $packageName installation completed (global)" -ForegroundColor Green
            }
            else {
                scoop install $packageName
                Write-Host "✓ $packageName 安装完成 / $packageName installation completed" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "✓ $packageName 已安装 / $packageName is already installed" -ForegroundColor Green
    }
}

# 游戏平台
Write-Host "`n=== 游戏平台 / Game Platforms ===" -ForegroundColor Yellow

$null = winget list --id Valve.Steam --exact 2>$null
if ($LASTEXITCODE -ne 0) {
    $installSteam = Read-Host "是否安装 Steam？(Y/n) / Install Steam? (Y/n)"
    if ($installSteam -notmatch '^[Nn]$') {
        Write-Host "安装 Steam… / Installing Steam…" -ForegroundColor Yellow
        winget install --id Valve.Steam --exact --silent --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Steam 安装完成 / Steam installation completed" -ForegroundColor Green
        }
        else {
            Write-Host "✗ Steam 安装失败 / Steam installation failed" -ForegroundColor Red
        }
    }
}
else {
    Write-Host "✓ Steam 已安装 / Steam is already installed" -ForegroundColor Green
}

# Epic Games Launcher
$null = winget list --id EpicGames.EpicGamesLauncher --exact 2>$null
if ($LASTEXITCODE -ne 0) {
    $installEpic = Read-Host "是否安装 Epic Games Launcher？(Y/n) / Install Epic Games Launcher? (Y/n)"
    if ($installEpic -notmatch '^[Nn]$') {
        Write-Host "安装 Epic Games Launcher… / Installing Epic Games Launcher…" -ForegroundColor Yellow
        winget install --id EpicGames.EpicGamesLauncher --exact --silent --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Epic Games Launcher 安装完成 / Epic Games Launcher installation completed" -ForegroundColor Green
        }
        else {
            Write-Host "✗ Epic Games Launcher 安装失败 / Epic Games Launcher installation failed" -ForegroundColor Red
        }
    }
}
else {
    Write-Host "✓ Epic Games Launcher 已安装 / Epic Games Launcher is already installed" -ForegroundColor Green
}

# GOG Galaxy
$null = winget list --id GOG.Galaxy --exact 2>$null
if ($LASTEXITCODE -ne 0) {
    $installGOG = Read-Host "是否安装 GOG Galaxy？(Y/n) / Install GOG Galaxy? (Y/n)"
    if ($installGOG -notmatch '^[Nn]$') {
        Write-Host "安装 GOG Galaxy… / Installing GOG Galaxy…" -ForegroundColor Yellow
        winget install --id GOG.Galaxy --exact --silent --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ GOG Galaxy 安装完成 / GOG Galaxy installation completed" -ForegroundColor Green
        }
        else {
            Write-Host "✗ GOG Galaxy 安装失败 / GOG Galaxy installation failed" -ForegroundColor Red
        }
    }
}
else {
    Write-Host "✓ GOG Galaxy 已安装 / GOG Galaxy is already installed" -ForegroundColor Green
}

Write-Host "`n✓ 必备软件包安装完成 / Essential applications installation completed" -ForegroundColor Green
Write-Host "`n当前已安装的所有应用 / All currently installed applications:" -ForegroundColor Cyan
scoop list
