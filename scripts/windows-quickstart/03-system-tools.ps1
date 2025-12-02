#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    系统工具安装 / System Tools Installation

.DESCRIPTION
    安装系统增强工具、实用程序和命令行工具
    Install system enhancement tools, utilities and command-line tools
#>

$ErrorActionPreference = "Stop"

Write-Host "=== 系统工具安装 / System Tools Installation ===" -ForegroundColor Cyan

# 检查 Scoop
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Error "Scoop 未安装，请先运行系统基础环境配置脚本 / Scoop not installed, please run the system foundation setup script first"
    exit 1
}

# 命令行增强工具
Write-Host "`n=== 命令行增强工具 / Command Line Enhancement Tools ===" -ForegroundColor Yellow

$cliTools = @{
    "starship" = @{ Desc = "Starship (跨平台命令行提示符 / Cross-platform shell prompt)"; Global = $true }
    "zoxide"   = @{ Desc = "zoxide (智能目录跳转 / Smarter cd command)"; Global = $false }
    "fzf"      = @{ Desc = "fzf (模糊查找器 / Fuzzy finder)"; Global = $false }
    "ripgrep"  = @{ Desc = "ripgrep (快速搜索工具 / Fast search tool)"; Global = $false }
    "fd"       = @{ Desc = "fd (快速文件查找 / Fast file finder)"; Global = $false }
    "bat"      = @{ Desc = "bat (cat 增强版 / cat with syntax highlighting)"; Global = $false }
    "eza"      = @{ Desc = "eza (ls 增强版 / Modern ls replacement)"; Global = $false }
}

foreach ($package in $cliTools.GetEnumerator()) {
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

# 系统信息和监控工具
Write-Host "`n=== 系统信息和监控工具 / System Info and Monitoring Tools ===" -ForegroundColor Yellow

$monitorTools = @{
    "fastfetch" = @{ Desc = "fastfetch (系统信息显示 / System information display)"; Global = $true }
}

foreach ($package in $monitorTools.GetEnumerator()) {
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

# 文件管理器
Write-Host "`n=== 文件管理器 / File Managers ===" -ForegroundColor Yellow

$fileManagers = @{
    "yazi" = @{ Desc = "Yazi (终端文件管理器 / Terminal file manager)"; Global = $false }
}

foreach ($package in $fileManagers.GetEnumerator()) {
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
            
            # Yazi 会自动触发依赖安装
            if ($packageName -eq "yazi") {
                Write-Host "提示：Yazi 会自动安装以下依赖：imagemagick, poppler, resvg" -ForegroundColor Cyan
            }
        }
    }
    else {
        Write-Host "✓ $packageName 已安装 / $packageName is already installed" -ForegroundColor Green
    }
}

# 压缩工具
Write-Host "`n=== 压缩工具 / Compression Tools ===" -ForegroundColor Yellow

$compressionTools = @{
    "7zip"    = @{ Desc = "7zip (压缩/解压工具 / Archive utility)"; Global = $true }
    "innounp" = @{ Desc = "innounp (Inno Setup 解包工具 / Inno Setup unpacker)"; Global = $true }
}

foreach ($entry in $compressionTools.GetEnumerator()) {
    $toolName = $entry.Key
    $toolInfo = $entry.Value
    
    if (-not (scoop list | Select-String -Pattern "^$toolName\s")) {
        $install = Read-Host "是否安装 $($toolInfo.Desc)？(Y/n) / Install $($toolInfo.Desc)? (Y/n)"
        if ($install -notmatch '^[Nn]$') {
            if ($toolInfo.Global) {
                scoop install $toolName --global
                Write-Host "✓ $toolName 安装完成（全局） / $toolName installation completed (global)" -ForegroundColor Green
            }
            else {
                scoop install $toolName
                Write-Host "✓ $toolName 安装完成 / $toolName installation completed" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "✓ $toolName 已安装 / $toolName is already installed" -ForegroundColor Green
    }
}

# Windows 增强工具
Write-Host "`n=== Windows 增强工具 / Windows Enhancement Tools ===" -ForegroundColor Yellow

$winTools = @{
    "powertoys"  = @{ Desc = "PowerToys (微软官方工具集 / Microsoft official utilities)"; Global = $true }
    "everything" = @{ Desc = "Everything (快速文件搜索 / Fast file search)"; Global = $true }
    "listary"    = @{ Desc = "Listary (文件搜索和启动器 / File search and launcher)"; Global = $true }
    "krokiet"    = @{ Desc = "Krokiet (图片查重工具 / picture duplicate finder)"; Global = $false }
    "autoruns"   = @{ Desc = "Autoruns (启动项管理工具 / Startup manager)"; Global = $true }
    "ventoy"     = @{ Desc = "Ventoy (多合一启动盘制作工具 / Multi-boot USB creator)"; Global = $true }
    "rufus"      = @{ Desc = "Rufus (USB 启动盘制作工具 / USB bootable creator)"; Global = $true }
    "wiztree"    = @{ Desc = "WizTree (磁盘空间分析工具 / Disk space analyzer)"; Global = $false }
    "spacesniffer" = @{ Desc = "SpaceSniffer (磁盘空间可视化工具 / Disk space visualizer)"; Global = $false }
}

foreach ($package in $winTools.GetEnumerator()) {
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

# 终端工具
Write-Host "`n=== 终端增强 / Terminal Enhancement ===" -ForegroundColor Yellow

$termTools = @{
    "dark" = @{ Desc = "Dark (WiX 反编译器 / WiX Toolset decompiler)"; Global = $true }
}

foreach ($tool in $termTools.GetEnumerator()) {
    $toolName = $tool.Key
    $toolInfo = $tool.Value
    
    if (-not (scoop list | Select-String -Pattern "^$toolName\s")) {
        $install = Read-Host "是否安装 $($toolInfo.Desc)？(y/N) / Install $($toolInfo.Desc)? (y/N)"
        if ($install -match '^[Yy]$') {
            if ($toolInfo.Global) {
                scoop install $toolName --global
                Write-Host "✓ $toolName 安装完成（全局） / $toolName installation completed (global)" -ForegroundColor Green
            }
            else {
                scoop install $toolName
                Write-Host "✓ $toolName 安装完成 / $toolName installation completed" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "✓ $toolName 已安装 / $toolName is already installed" -ForegroundColor Green
    }
}

# 网络工具
Write-Host "`n=== 网络工具 / Network Tools ===" -ForegroundColor Yellow

$networkTools = @{
    "scrcpy" = @{ Desc = "scrcpy (Android 投屏工具 / Android screen mirroring)"; Global = $true }
    "mkcert" = @{ Desc = "mkcert (本地 HTTPS 证书 / Local HTTPS certificates)"; Global = $true }
}

foreach ($package in $networkTools.GetEnumerator()) {
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

Write-Host "`n✓ 系统工具安装完成 / System tools installation completed" -ForegroundColor Green
Write-Host "`n全局安装的应用 / Globally installed apps:" -ForegroundColor Cyan
scoop list | Select-String "Global"
