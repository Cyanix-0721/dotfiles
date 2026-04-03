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

# 加载公共函数
. "$PSScriptRoot/00-common.ps1"

Write-Header "开发工具安装 / Development Tools Installation"

# 检查 Scoop
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Err "Scoop 未安装，请先运行系统基础环境配置脚本 / Scoop not installed, please run the system foundation setup script first"
    exit 1
}

# 编辑器和 IDE
Write-Header "编辑器 / Editors and IDEs"

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
                Write-Ok "$packageName 安装完成（全局） / $packageName installation completed (global)"
            }
            else {
                scoop install $packageName
                Write-Ok "$packageName 安装完成 / $packageName installation completed"
            }
        }
    }
    else {
        Write-Ok "$packageName 已安装 / $packageName is already installed"
    }
}

# Git 工具
Write-Header "Git 工具 / Git Tools"

$gitTools = @{
    "lazygit" = @{ Desc = "lazygit"; Global = $false }
    "delta"   = @{ Desc = "delta"; Global = $false }
    "gh"      = @{ Desc = "gh (GitHub CLI)"; Global = $false }
}

foreach ($package in $gitTools.GetEnumerator()) {
    $packageName = $package.Key
    $packageInfo = $package.Value

    if (-not (scoop list | Select-String -Pattern "^$packageName\s")) {
        $install = Read-Host "是否安装 $($packageInfo.Desc)？(Y/n) / Install $($packageInfo.Desc)? (Y/n)"
        if ($install -notmatch '^[Nn]$') {
            if ($packageInfo.Global) {
                scoop install $packageName --global
                Write-Ok "$packageName 安装完成（全局） / $packageName installation completed (global)"
            }
            else {
                scoop install $packageName
                Write-Ok "$packageName 安装完成 / $packageName installation completed"
            }
        }
    }
    else {
        Write-Ok "$packageName 已安装 / $packageName is already installed"
    }
}

# SVN 客户端
Write-Header "SVN 客户端 / SVN Clients"

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
                Write-Ok "$packageName 安装完成（全局） / $packageName installation completed (global)"
            }
            else {
                scoop install $packageName
                Write-Ok "$packageName 安装完成 / $packageName installation completed"
            }
        }
    }
    else {
        Write-Ok "$packageName 已安装 / $packageName is already installed"
    }
}


# 环境管理
Write-Header "环境管理 / Environment Management"

# 1. vfox 版本管理器 (必装 / Required)
Write-Step "vfox 版本管理器 / vfox Version Manager (Required)"
$versionManager = @{
    "vfox" = @{ Desc = "vfox (多语言版本管理器 / Multi-language version manager)"; Global = $false }
}

foreach ($package in $versionManager.GetEnumerator()) {
    $packageName = $package.Key
    $packageInfo = $package.Value

    if (-not (scoop list | Select-String -Pattern "^$packageName\s")) {
        $install = Read-Host "是否安装 $($packageInfo.Desc)？(Y/n) / Install $($packageInfo.Desc)? (Y/n)"
        if ($install -notmatch '^[Nn]$') {
            if ($packageInfo.Global) {
                scoop install $packageName --global
                Write-Ok "$packageName 安装完成（全局） / $packageName installation completed (global)"
            }
            else {
                scoop install $packageName
                Write-Ok "$packageName 安装完成 / $packageName installation completed"
            }
        }
    }
    else {
        Write-Ok "$packageName 已安装 / $packageName is already installed"
    }
}

# 2. Python 包管理器 (可选一个或都安装，默认 uv / Optional, can install one or both, default uv)
Write-Step "Python 包管理器 / Python Package Manager (Optional)"
Write-Note "可以选择安装 uv、miniconda3 或两者都装 / Can install uv, miniconda3, or both"

$pythonPackageManagers = @{
    "uv"         = @{
        Desc    = "uv (现代 Python 包管理器，推荐个人开发 / Modern Python package manager, recommended)"
        Global  = $false
        Default = $true
    }
    "miniconda3" = @{
        Desc    = "miniconda3 (适用于公司项目或科学计算 / For company projects or scientific computing)"
        Global  = $false
        Default = $false
    }
}

foreach ($package in $pythonPackageManagers.GetEnumerator()) {
    $packageName = $package.Key
    $packageInfo = $package.Value

    if (-not (scoop list | Select-String -Pattern "^$packageName\s")) {
        # uv 默认安装，miniconda 默认不安装
        if ($packageInfo.Default) {
            $install = Read-Host "是否安装 $($packageInfo.Desc)？(Y/n) / Install $($packageInfo.Desc)? (Y/n)"
        }
        else {
            $install = Read-Host "是否安装 $($packageInfo.Desc)？(y/N) / Install $($packageInfo.Desc)? (y/N)"
        }

        $shouldInstall = $false
        if ($packageInfo.Default -and $install -notmatch '^[Nn]$') { $shouldInstall = $true }
        if (-not $packageInfo.Default -and $install -match '^[Yy]$') { $shouldInstall = $true }

        if ($shouldInstall) {
            if ($packageInfo.Global) {
                scoop install $packageName --global
                Write-Ok "$packageName 安装完成（全局） / $packageName installation completed (global)"
            }
            else {
                scoop install $packageName
                Write-Ok "$packageName 安装完成 / $packageName installation completed"
            }

            # miniconda3 特殊配置
            if ($packageName -eq "miniconda3") {
                Write-Note "配置 Miniconda 不自动激活... / Configuring Miniconda to not auto-activate..."
                Write-Note "运行以下命令禁用自动激活 / Run the following command to disable auto-activation: conda config --set auto_activate false"
                Write-Note "需要使用时显式激活 / When needed, explicitly activate: conda activate <env_name>"
            }
        }
    }
    else {
        Write-Ok "$packageName 已安装 / $packageName is already installed"

        # miniconda3 特殊提示
        if ($packageName -eq "miniconda3") {
            Write-Note "请运行以下命令禁用自动激活 / Please run this command to disable auto-activation: conda config --set auto_activate false"
        }
    }
}

# .NET 运行时和 SDK
Write-Header ".NET 运行时和 SDK / .NET Runtime and SDK"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过 .NET 安装 / winget not installed, skipping .NET installation"
}
else {
    $dotnetVersions = @(5, 6, 7, 8, 9, 10)

    foreach ($version in $dotnetVersions) {
        $installDotNet = Read-Host "是否安装 .NET $version.0？(y/N) / Install .NET $version.0? (y/N)"
        if ($installDotNet -match '^[Yy]$') {
            Write-Step "安装 .NET $version.0 / Installing .NET $version.0"
            Write-Host "1. 仅运行时 / Runtime only (默认 / default)" -ForegroundColor Yellow
            Write-Host "2. 仅 SDK / SDK only" -ForegroundColor Yellow
            Write-Host "3. 运行时 + SDK / Runtime + SDK" -ForegroundColor Yellow

            $choice = Read-Host "请输入选项 (1/2/3，默认 1) / Enter option (1/2/3, default 1)"
            if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }

            $toInstall = @()
            switch ($choice) {
                "1" { $toInstall += "Microsoft.DotNet.Runtime.$version" }
                "2" { $toInstall += "Microsoft.DotNet.SDK.$version" }
                "3" { $toInstall += "Microsoft.DotNet.Runtime.$version"; $toInstall += "Microsoft.DotNet.SDK.$version" }
                default { Write-Warn "无效选项，跳过 .NET $version.0 安装 / Invalid option, skipping .NET $version.0 installation" }
            }

            foreach ($appId in $toInstall) {
                try {
                    $isInstalled = winget list --id $appId --exact -s winget 2>$null | Select-String $appId
                }
                catch { $isInstalled = $null }

                if (-not $isInstalled) {
                    Write-Step "通过 winget 安装 $appId / Installing $appId via winget"
                    winget install --id $appId --exact --silent --accept-source-agreements --accept-package-agreements
                    if ($LASTEXITCODE -eq 0) {
                        Write-Ok "$appId 安装完成 / $appId installation completed"
                    }
                    else {
                        Write-Err "$appId 安装失败 / $appId installation failed"
                    }
                }
                else {
                    Write-Ok "$appId 已安装 / $appId is already installed"
                }
            }
        }
    }
}

# API 开发工具
Write-Header "API 开发工具 / API Development Tools"

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
                Write-Ok "$packageName 安装完成（全局） / $packageName installation completed (global)"
            }
            else {
                scoop install $packageName
                Write-Ok "$packageName 安装完成 / $packageName installation completed"
            }
        }
    }
    else {
        Write-Ok "$packageName 已安装 / $packageName is already installed"
    }
}

# 其他开发工具
Write-Header "其他开发工具 / Other Development Tools"

$devTools = @{
    "jq"     = @{ Desc = "jq (JSON 处理器 / JSON processor)"; Global = $false }
    "pandoc" = @{ Desc = "Pandoc (文档转换器 / Document converter)"; Global = $true }
    "shfmt"  = @{ Desc = "shfmt (Shell 格式化工具 / Shell formatter)"; Global = $false }
    "adb"    = @{ Desc = "adb (Android Debug Bridge)"; Global = $false }
}

foreach ($package in $devTools.GetEnumerator()) {
    $packageName = $package.Key
    $packageInfo = $package.Value

    if (-not (scoop list | Select-String -Pattern "^$packageName\s")) {
        $install = Read-Host "是否安装 $($packageInfo.Desc)？(y/N) / Install $($packageInfo.Desc)? (y/N)"
        if ($install -match '^[Yy]$') {
            if ($packageInfo.Global) {
                scoop install $packageName --global
                Write-Ok "$packageName 安装完成（全局） / $packageName installation completed (global)"
            }
            else {
                scoop install $packageName
                Write-Ok "$packageName 安装完成 / $packageName installation completed"
            }
        }
    }
    else {
        Write-Ok "$packageName 已安装 / $packageName is already installed"
    }
}

# 容器与虚拟化 / Containers and Virtualization
Write-Header "容器与虚拟化 / Containers and Virtualization"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过 Docker Desktop 安装 / winget not installed, skipping Docker Desktop installation"
}
else {
    $wingApps = @{
        "Docker.DockerDesktop" = @{ Desc = "Docker Desktop"; InstallArgs = "--exact --silent" }
    }

    foreach ($entry in $wingApps.GetEnumerator()) {
        $appId = $entry.Key
        $appInfo = $entry.Value

        try {
            $isInstalled = winget list --id $appId --exact -s winget 2>$null | Select-String $appId
        }
        catch {
            $isInstalled = $null
        }

        if (-not $isInstalled) {
            $installDocker = Read-Host "是否安装 $($appInfo.Desc)？(Y/n) / Install $($appInfo.Desc)? (Y/n)"
            if ($installDocker -notmatch '^[Nn]$') {
                Write-Step "安装 $($appInfo.Desc) / Installing $($appInfo.Desc)"
                winget install --id $appId $($appInfo.InstallArgs) --accept-source-agreements --accept-package-agreements
                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "$appId 安装完成 / $appId installation completed"
                }
                else {
                    Write-Err "$appId 安装失败 / $appId installation failed"
                }
            }
        }
        else {
            Write-Ok "$appId 已安装 / $appId is already installed"
        }
    }
}

Write-Header "开发工具安装完成 / Development tools installation completed"
Write-Note "当前已安装的开发工具 / Currently installed development tools:"
scoop list
