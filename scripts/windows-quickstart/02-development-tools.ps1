#!/usr/bin/env pwsh

<#
.SYNOPSIS
    开发工具安装 / Development Tools Installation

.DESCRIPTION
    安装常用的开发工具和编程语言环境
    Install common development tools and programming language environments
#>

param(
    [switch]$AutoYes
)

$ErrorActionPreference = "Stop"

# 加载公共函数
. "$PSScriptRoot/00-common.ps1"

# 初始化自动确认模式
Initialize-AutoYes

Write-Header "开发工具安装 / Development Tools Installation"

# 检查 Scoop
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Err "Scoop 未安装，请先运行系统基础环境配置脚本 / Scoop not installed, please run the system foundation setup script first"
    throw "Scoop 未安装 / Scoop not installed"
}

# 编辑器和 IDE
Write-Header "编辑器 / Editors and IDEs"

$editors = @{
    "vscode" = @{ Desc = "Visual Studio Code"; Global = $false; Default = $true }
}

Install-ScoopPackages $editors

# Git 工具
Write-Header "Git 工具 / Git Tools"

$gitTools = @{
    "lazygit" = @{ Desc = "lazygit"; Global = $false; Default = $true }
    "delta"   = @{ Desc = "delta"; Global = $false; Default = $true }
    "gh"      = @{ Desc = "gh (GitHub CLI)"; Global = $false; Default = $true }
}

Install-ScoopPackages $gitTools

# Shell 脚本工具
Write-Header "Shell 脚本工具 / Shell Script Tools"

$shellTools = @{
    "shellcheck" = @{ Desc = "shellcheck (bash 静态检查 / bash static analysis)"; Global = $false; Default = $true }
    "shfmt"      = @{ Desc = "shfmt (bash 格式化 / bash formatter)"; Global = $false; Default = $true }
}

Install-ScoopPackages $shellTools

# SVN 客户端
Write-Header "SVN 客户端 / SVN Clients"

$svnTools = @{
    "sliksvn"     = @{ Desc = "SlikSVN (命令行 / Command-line)"; Global = $true }
    "tortoisesvn" = @{ Desc = "TortoiseSVN (图形界面 / GUI)"; Global = $false }
}

Install-ScoopPackages $svnTools


# 环境管理
Write-Header "环境管理 / Environment Management"

# 1. vfox 版本管理器 (必装 / Required)
Write-Step "vfox 版本管理器 / vfox Version Manager (Required)"
$versionManager = @{
    "vfox" = @{ Desc = "vfox (多语言版本管理器 / Multi-language version manager)"; Global = $false; Default = $true }
}

Install-ScoopPackages $versionManager

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
        Desc        = "miniconda3 (适用于公司项目或科学计算 / For company projects or scientific computing)"
        Global      = $false
        Default     = $false
        PostNote    = @(
            "配置 Miniconda 不自动激活... / Configuring Miniconda to not auto-activate..."
            "运行以下命令禁用自动激活 / Run to disable auto-activation: conda config --set auto_activate false"
            "需要使用时显式激活 / Activate explicitly: conda activate <env_name>"
        )
        AlreadyNote = @(
            "请运行以下命令禁用自动激活 / Run to disable auto-activation: conda config --set auto_activate false"
        )
    }
}

Install-ScoopPackages $pythonPackageManagers

# uv 工具 (copyparty, ruff / uv tools)
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Write-Step "uv 工具 / uv Tools (copyparty, ruff)"
    $installUvTools = Confirm-Install "安装 uv 工具 copyparty、ruff？(Y/n) / Install uv tools copyparty, ruff? (Y/n)"
    if ($installUvTools -notmatch '^[Nn]$') {
        Write-Step "安装 uv 工具 / Installing uv tools (copyparty, ruff)"
        uv tool install copyparty ruff
        Write-Ok "uv 工具安装完成 / uv tools installed"
    }
    else {
        Write-Note "跳过 uv 工具 / Skipping uv tools"
    }
}
else {
    Write-Note "uv 未安装，跳过 uv 工具 / uv not installed, skipping uv tools"
}

# .NET 运行时和 SDK
Write-Header ".NET 运行时和 SDK / .NET Runtime and SDK"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过 .NET 安装 / winget not installed, skipping .NET installation"
}
else {
    $dotnetVersions = @(5, 6, 7, 8, 9, 10)

    foreach ($version in $dotnetVersions) {
        $installDotNet = Confirm-Install "是否安装 .NET $version.0？(y/N) / Install .NET $version.0? (y/N)"
        if ($installDotNet -notmatch '^[Yy]$') { continue }

        Write-Step "安装 .NET $version.0 / Installing .NET $version.0"
        Write-Host "1. 仅 SDK (包含运行时) / SDK only (includes runtime) (默认 / default)" -ForegroundColor Yellow
        Write-Host "2. 仅运行时 / Runtime only" -ForegroundColor Yellow

        if ($AutoYes) {
            $choice = "1"
        }
        else {
            $choice = Read-Host "请输入选项 (1/2，默认 1) / Enter option (1/2, default 1)"
            if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }
        }

        $toInstall = @()
        switch ($choice) {
            "1" { $toInstall += "Microsoft.DotNet.SDK.$version" }
            "2" { $toInstall += "Microsoft.DotNet.Runtime.$version" }
            default { Write-Warn "无效选项，跳过 .NET $version.0 安装 / Invalid option, skipping .NET $version.0 installation" }
        }

        foreach ($appId in $toInstall) {
            try {
                $isInstalled = winget list --id $appId --exact -s winget 2>$null | Select-String -SimpleMatch $appId
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

# API 开发工具
Write-Header "API 开发工具 / API Development Tools"

$apiTools = @{
    "postman"    = @{ Desc = "Postman"; Global = $false }
    "hoppscotch" = @{ Desc = "Hoppscotch"; Global = $false }
}

Install-ScoopPackages $apiTools

# 其他开发工具
Write-Header "其他开发工具 / Other Development Tools"

$devTools = @{
    "jq"     = @{ Desc = "jq (JSON 处理器 / JSON processor)"; Global = $false }
    "pandoc" = @{ Desc = "Pandoc (文档转换器 / Document converter)"; Global = $true }
    "adb"    = @{ Desc = "adb (Android Debug Bridge)"; Global = $false }
}

Install-ScoopPackages $devTools

# 容器与虚拟化 / Containers and Virtualization
Write-Header "容器与虚拟化 / Containers and Virtualization"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过 Docker Desktop 安装 / winget not installed, skipping Docker Desktop installation"
}
else {
    $wingApps = @{
        "Docker.DockerDesktop" = @{ Desc = "Docker Desktop"; InstallArgs = @("--exact", "--silent"); Default = $true }
    }
    Install-WingetApps $wingApps
}

Write-Header "开发工具安装完成 / Development tools installation completed"
Write-Note "当前已安装的开发工具 / Currently installed development tools:"
scoop list
