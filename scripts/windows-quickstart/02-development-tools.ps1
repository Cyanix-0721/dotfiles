#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    开发工具安装 / Development Tools Installation

.DESCRIPTION
    安装常用的开发工具和编程语言环境
    Install common development tools and programming language environments
#>

$ErrorActionPreference = "Stop"

Write-Host "=== 开发工具安装 / Development Tools Installation ===" -ForegroundColor Cyan

# 检查 Scoop
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Error "Scoop 未安装，请先运行系统基础环境配置脚本 / Scoop not installed, please run the system foundation setup script first"
    exit 1
}

# 编辑器和 IDE
Write-Host "`n=== 编辑器和 IDE / Editors and IDEs ===" -ForegroundColor Yellow

$editors = @{
    "vscode" = @{ Desc = "Visual Studio Code"; Global = $false }
}

foreach ($package in $editors.GetEnumerator()) {
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

# Git 工具
Write-Host "`n=== Git 工具 / Git Tools ===" -ForegroundColor Yellow

$gitTools = @{
    "lazygit" = @{ Desc = "lazygit"; Global = $true }
    "delta"   = @{ Desc = "delta"; Global = $true }
}

foreach ($package in $gitTools.GetEnumerator()) {
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

# SVN 客户端
Write-Host "`n=== SVN 客户端 / SVN Clients ===" -ForegroundColor Yellow

$svnTools = @{
    "sliksvn"     = @{ Desc = "SlikSVN (命令行 / Command-line)"; Global = $true }
    "tortoisesvn" = @{ Desc = "TortoiseSVN (图形界面 / GUI)"; Global = $false }
}

foreach ($package in $svnTools.GetEnumerator()) {
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


# 版本管理工具
Write-Host "`n=== 版本管理工具 / Version Managers ===" -ForegroundColor Yellow

$versionManagers = @{
    "vfox" = @{ Desc = "vfox (多语言版本管理器 / Multi-language version manager)"; Global = $true }
    "uv"   = @{ Desc = "uv (Python 包管理器 / Python package manager)"; Global = $true }
}

foreach ($package in $versionManagers.GetEnumerator()) {
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

# Node.js 包管理器
Write-Host "`n=== Node.js 包管理器 / Node.js Package Managers ===" -ForegroundColor Yellow

$nodePackageManagers = @{
    "pnpm" = @{ Desc = "pnpm"; Global = $true }
}

foreach ($package in $nodePackageManagers.GetEnumerator()) {
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

# API 开发工具
Write-Host "`n=== API 开发工具 / API Development Tools ===" -ForegroundColor Yellow

$apiTools = @{
    "postman"    = @{ Desc = "Postman"; Global = $false }
    "hoppscotch" = @{ Desc = "Hoppscotch"; Global = $false }
}

foreach ($package in $apiTools.GetEnumerator()) {
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

# 其他开发工具
Write-Host "`n=== 其他开发工具 / Other Development Tools ===" -ForegroundColor Yellow

$devTools = @{
    "jq"     = @{ Desc = "jq (JSON 处理器 / JSON processor)"; Global = $false }
    "pandoc" = @{ Desc = "Pandoc (文档转换器 / Document converter)"; Global = $true }
    "shfmt"  = @{ Desc = "shfmt (Shell 格式化工具 / Shell formatter)"; Global = $true }
}

foreach ($entry in $devTools.GetEnumerator()) {
    $toolName = $entry.Key
    $toolInfo = $entry.Value
    
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

Write-Host "`n✓ 开发工具安装完成 / Development tools installation completed" -ForegroundColor Green
Write-Host "`n当前已安装的开发工具 / Currently installed development tools:" -ForegroundColor Cyan
scoop list
