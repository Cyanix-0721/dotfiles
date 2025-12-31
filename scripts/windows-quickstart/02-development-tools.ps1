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
    "lazygit" = @{ Desc = "lazygit"; Global = $false }
    "delta"   = @{ Desc = "delta"; Global = $false }
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

# Python 环境
Write-Host "`n=== Python 环境 / Python Environment ===" -ForegroundColor Yellow

$pythonTools = @{
    "miniconda3" = @{ Desc = "Miniconda3 (Python 发行版和包管理器 / Python distribution and package manager)"; Global = $false }
}

foreach ($package in $pythonTools.GetEnumerator()) {
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

# .NET 运行时和 SDK
Write-Host "`n=== .NET 运行时和 SDK / .NET Runtime and SDK ===" -ForegroundColor Yellow

$dotnetVersions = @(5, 6, 7, 8, 9, 10)

foreach ($version in $dotnetVersions) {
    $installDotNet = Read-Host "是否安装 .NET $version.0？(y/N) / Install .NET $version.0? (y/N)"
    if ($installDotNet -match '^[Yy]$') {
        Write-Host "请选择安装类型 / Please select installation type:" -ForegroundColor Cyan
        Write-Host "1. 仅运行时 / Runtime only (默认 / default)" -ForegroundColor Yellow
        Write-Host "2. 仅 SDK / SDK only" -ForegroundColor Yellow
        Write-Host "3. 运行时 + SDK / Runtime + SDK" -ForegroundColor Yellow
        
        $choice = Read-Host "请输入选项 (1/2/3，默认 1) / Enter option (1/2/3, default 1)"
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $choice = "1"
        }
        
        switch ($choice) {
            "1" {
                # 仅安装运行时
                $null = winget list --id "Microsoft.DotNet.Runtime.$version" --exact 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "安装 .NET $version.0 运行时... / Installing .NET $version.0 Runtime..." -ForegroundColor Yellow
                    winget install --id "Microsoft.DotNet.Runtime.$version" --exact --silent
                    Write-Host "✓ .NET $version.0 运行时安装完成 / .NET $version.0 Runtime installation completed" -ForegroundColor Green
                }
                else {
                    Write-Host "✓ .NET $version.0 运行时已安装 / .NET $version.0 Runtime is already installed" -ForegroundColor Green
                }
            }
            "2" {
                # 仅安装 SDK
                $null = winget list --id "Microsoft.DotNet.SDK.$version" --exact 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "安装 .NET $version.0 SDK... / Installing .NET $version.0 SDK..." -ForegroundColor Yellow
                    winget install --id "Microsoft.DotNet.SDK.$version" --exact --silent
                    Write-Host "✓ .NET $version.0 SDK 安装完成 / .NET $version.0 SDK installation completed" -ForegroundColor Green
                }
                else {
                    Write-Host "✓ .NET $version.0 SDK 已安装 / .NET $version.0 SDK is already installed" -ForegroundColor Green
                }
            }
            "3" {
                # 安装运行时和 SDK
                $null = winget list --id "Microsoft.DotNet.Runtime.$version" --exact 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "安装 .NET $version.0 运行时... / Installing .NET $version.0 Runtime..." -ForegroundColor Yellow
                    winget install --id "Microsoft.DotNet.Runtime.$version" --exact --silent
                    Write-Host "✓ .NET $version.0 运行时安装完成 / .NET $version.0 Runtime installation completed" -ForegroundColor Green
                }
                else {
                    Write-Host "✓ .NET $version.0 运行时已安装 / .NET $version.0 Runtime is already installed" -ForegroundColor Green
                }
                
                $null = winget list --id "Microsoft.DotNet.SDK.$version" --exact 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "安装 .NET $version.0 SDK... / Installing .NET $version.0 SDK..." -ForegroundColor Yellow
                    winget install --id "Microsoft.DotNet.SDK.$version" --exact --silent
                    Write-Host "✓ .NET $version.0 SDK 安装完成 / .NET $version.0 SDK installation completed" -ForegroundColor Green
                }
                else {
                    Write-Host "✓ .NET $version.0 SDK 已安装 / .NET $version.0 SDK is already installed" -ForegroundColor Green
                }
            }
            default {
                Write-Host "无效选项，跳过 .NET $version.0 安装 / Invalid option, skipping .NET $version.0 installation" -ForegroundColor Red
            }
        }
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
    "shfmt"  = @{ Desc = "shfmt (Shell 格式化工具 / Shell formatter)"; Global = $false }
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

# 容器与虚拟化 / Containers and Virtualization
Write-Host "`n=== 容器与虚拟化 / Containers and Virtualization ===" -ForegroundColor Yellow

$null = winget list --id Docker.DockerDesktop --exact 2>$null
if ($LASTEXITCODE -ne 0) {
    $installDocker = Read-Host "是否安装 Docker Desktop？(Y/n) / Install Docker Desktop? (Y/n)"
    if ($installDocker -notmatch '^[Nn]$') {
        Write-Host "安装 Docker Desktop… / Installing Docker Desktop…" -ForegroundColor Yellow
        winget install --id Docker.DockerDesktop --exact --silent --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Docker Desktop 安装完成 / Docker Desktop installation completed" -ForegroundColor Green
        }
        else {
            Write-Host "✗ Docker Desktop 安装失败 / Docker Desktop installation failed" -ForegroundColor Red
        }
    }
}
else {
    Write-Host "✓ Docker Desktop 已安装 / Docker Desktop is already installed" -ForegroundColor Green
}

Write-Host "`n✓ 开发工具安装完成 / Development tools installation completed" -ForegroundColor Green
Write-Host "`n当前已安装的开发工具 / Currently installed development tools:" -ForegroundColor Cyan
scoop list
