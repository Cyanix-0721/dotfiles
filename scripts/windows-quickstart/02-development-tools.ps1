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
    "vscode" = @{ Desc = "Visual Studio Code"; Global = $false }
}

Install-ScoopPackages $editors

# Git 工具
Write-Header "Git 工具 / Git Tools"

$gitTools = @{
    "lazygit" = @{ Desc = "lazygit"; Global = $false }
    "delta"   = @{ Desc = "delta"; Global = $false }
    "gh"      = @{ Desc = "gh (GitHub CLI)"; Global = $false }
}

Install-ScoopPackages $gitTools

# Shell 脚本工具
Write-Header "Shell 脚本工具 / Shell Script Tools"

$shellTools = @{
    "shellcheck" = @{ Desc = "shellcheck (bash 静态检查 / bash static analysis)"; Global = $false }
    "shfmt"      = @{ Desc = "shfmt (bash 格式化 / bash formatter)"; Global = $false }
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

# 1. 版本管理器 (必装 / Required)
Write-Step "版本管理器 / Version Manager (Required)"
$versionManager = @{
    "vfox" = @{ Desc = "vfox (多语言版本管理器 / Multi-language version manager)"; Global = $false }
    "fnm"  = @{ Desc = "fnm (Node.js 版本管理器 / Node.js version manager)"; Global = $false }
}

Install-ScoopPackages $versionManager

# 1.5 Node.js LTS（可选，默认否；AutoYes 时安装最新 LTS 并设为全局默认）
# Node.js LTS (optional, default no; AutoYes installs latest LTS and sets it as the global default)
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    Write-Step "Node.js LTS / Node.js LTS (optional)"
    $installLts = Confirm-Install "是否安装最新 LTS Node.js？(y/N) / Install latest LTS Node.js? (y/N)"
    if ($installLts -match '^[Yy]$') {
        Write-Step "通过 fnm 安装最新 LTS Node.js / Installing latest LTS Node.js via fnm"
        fnm install --lts
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "最新 LTS Node.js 安装完成 / Latest LTS Node.js installed"
            # 默认非全局；是否设为全局默认同样可选（AutoYes 时自动设为全局默认）
            # Global default is off by default; setting it is also optional (AutoYes sets it automatically)
            $setGlobal = Confirm-Install "是否将最新 LTS 设为全局默认？(y/N) / Set latest LTS as global default? (y/N)"
            if ($setGlobal -match '^[Yy]$') {
                $ltsLine = fnm list 2>$null | Where-Object { $_ -match 'lts-latest' } | Select-Object -First 1
                $ltsVersion = [regex]::Match($ltsLine, 'v?\d+\.\d+\.\d+').Value
                if ($ltsVersion) {
                    fnm default $ltsVersion
                    fnm use $ltsVersion | Out-Null
                    Write-Ok "已将 Node.js $ltsVersion 设为全局默认 / Node.js $ltsVersion set as global default"
                }
                else {
                    Write-Warn "未能识别 LTS 版本，跳过设为全局默认 / Could not identify LTS version, skipping global default"
                }
            }
        }
        else {
            Write-Err "最新 LTS Node.js 安装失败 / Latest LTS Node.js installation failed"
        }
    }
    else {
        Write-Note "跳过 Node.js LTS 安装 / Skipping Node.js LTS installation"
    }
}
else {
    Write-Warn "fnm 不可用，跳过 Node.js LTS 安装 / fnm unavailable, skipping Node.js LTS installation"
}

# 2. Node 包管理器（pnpm，独立二进制；运行 JS 项目仍需 Node）
# Node package manager (pnpm, standalone binary; running JS projects still needs Node)
Write-Step "Node 包管理器 / Node Package Manager (pnpm)"
$nodePackageManagers = @{
    "pnpm" = @{
        Desc     = "pnpm (Node 包管理器 / Node package manager)"
        Global   = $false
        PostNote = @(
            "pnpm 为独立二进制，运行自身无需 Node / pnpm is a standalone binary, no Node needed to run itself"
            "运行 JS 项目仍需 Node：请先执行 fnm install --lts / Running JS projects still needs Node: run 'fnm install --lts' first"
        )
    }
}
Install-ScoopPackages $nodePackageManagers

# 3. Python 包管理器 (可选一个或都安装，默认 uv / Optional, can install one or both, default uv)
Write-Step "Python 包管理器 / Python Package Manager (Optional)"
Write-Note "可以选择安装 uv、miniconda3 或两者都装 / Can install uv, miniconda3, or both"

$pythonPackageManagers = @{
    "uv"         = @{
        Desc   = "uv (现代 Python 包管理器，推荐个人开发 / Modern Python package manager, recommended)"
        Global = $false
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

# 数据库工具
Write-Header "数据库工具 / Database Tools"

$dbTools = @{
    "dbeaver" = @{ Desc = "DBeaver (数据库管理工具 / Database management tool)"; Global = $false }
}

Install-ScoopPackages $dbTools

# 其他开发工具
Write-Header "其他开发工具 / Other Development Tools"

$devTools = @{
    "jq"     = @{ Desc = "jq (JSON 处理器 / JSON processor)"; Global = $false }
    "pandoc" = @{ Desc = "Pandoc (文档转换器 / Document converter)"; Global = $true }
    "adb"    = @{ Desc = "adb (Android Debug Bridge)"; Global = $false }
}

Install-ScoopPackages $devTools

# AI 开发工具
Write-Header "AI 开发工具 / AI Development Tools"

$aiTools = @{
    "ollama"    = @{
        Desc     = "ollama (本地大模型运行器 / Local LLM runner)"
        Global   = $false
        PostNote = @(
            "启动服务 / Start the server: ollama serve"
            "下载模型示例 / Pull a model e.g.: ollama pull qwen3:8b"
        )
    }
    "cc-switch" = @{
        Desc     = "cc-switch (Claude Code / Codex / Gemini CLI 配置切换器 / Config switcher for AI coding CLIs)"
        Global   = $false
        PostNote = @(
            "WSL 中使用时：设置 → 配置目录覆盖 → 指向 WSL 配置目录 / For WSL: Settings → config directory override → point to the WSL config dir"
        )
    }
}

Install-ScoopPackages $aiTools

# WSL2 + Debian
Write-Header "WSL2 / Debian 安装 / WSL2 / Debian setup"

$installWsl = Confirm-Install "是否安装 WSL2、Debian 发行版并配置默认开发环境？(Y/n) / Install WSL2, Debian distro and configure the default dev environment? (Y/n)"
if ($installWsl -notmatch '^[Nn]$') {
    Write-Step "检查并安装 WSL2 / Checking and installing WSL2"

    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        Write-Warn "当前系统未检测到 wsl.exe，尝试通过 winget 安装 WSL / wsl.exe not found, attempting to install WSL via winget"
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id Microsoft.WSL --exact --silent --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -ne 0) {
                Write-Err "WSL 安装失败 / WSL installation failed"
            }
        }
        else {
            Write-Err "winget 不可用，无法自动安装 WSL / winget unavailable, cannot auto-install WSL"
        }
    }

    if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
        Write-Step "启用 Windows 的 WSL 相关功能 / Enabling Windows features required for WSL"
        $wslFeatures = @(
            "Microsoft-Windows-Subsystem-Linux",
            "VirtualMachinePlatform",
            "Microsoft-Hyper-V-All"
        )
        foreach ($feature in $wslFeatures) {
            try {
                dism.exe /online /enable-feature /featurename:$feature /all /norestart | Out-Null
            }
            catch {
                Write-Warn "启用 Windows 功能 $feature 失败，后续继续尝试 / Enabling Windows feature $feature failed; continuing"
            }
        }

        Write-Step "设置 WSL 默认版本为 2 / Setting WSL default version to 2"
        wsl.exe --set-default-version 2 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "设置 WSL 2 版本失败，后续仍尝试安装发行版 / Failed to set WSL 2 version, will still try installing the distro"
        }

        $distroList = @(wsl.exe --list --quiet 2>$null)
        if ($distroList -notcontains "Debian") {
            Write-Step "安装 Debian 发行版 / Installing Debian distro"
            wsl.exe --install -d Debian
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "Debian 安装命令返回非零状态，可能需要重启系统后再继续 / Debian install returned a non-zero status; a reboot may be required"
            }
        }

        wsl.exe --set-default Debian 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "设置 Debian 为默认发行版失败 / Failed to set Debian as the default distro"
        }

        $useRoot = $false
        if ($Script:AutoYes) {
            $useRoot = $false
        }
        else {
            $useRootChoice = Read-Host "是否直接使用 root 账户？(y/N) / Use root account directly? (y/N)"
            $useRoot = ($useRootChoice -match '^[Yy]$')
        }

        if ($useRoot) {
            $defaultUser = "root"
            $defaultPassword = $null
            Write-Note "将直接使用 root 账户完成 Debian 初始化 / Will initialize Debian directly with the root account"
        }
        else {
            $defaultUser = if ($Script:AutoYes) { "slayer" } else { Read-Host "请输入 Debian 默认用户名 (默认 slayer) / Enter Debian default username (default: slayer)" }
            if ([string]::IsNullOrWhiteSpace($defaultUser)) { $defaultUser = "slayer" }

            $defaultPassword = if ($Script:AutoYes) { "114514" } else { Read-Host "请输入 Debian 默认密码 (默认 114514) / Enter Debian default password (default: 114514)" }
            if ([string]::IsNullOrWhiteSpace($defaultPassword)) { $defaultPassword = "114514" }
        }

        $wslSetupScript = @"
set -e
export DEBIAN_FRONTEND=noninteractive
if [ '$useRoot' = 'True' ]; then
    echo 'Using root account directly'
else
    if ! command -v sudo >/dev/null 2>&1; then
        apt-get update
        apt-get install -y sudo
    fi
    if id -u $defaultUser >/dev/null 2>&1; then
        echo "user exists"
    else
        useradd -m -s /bin/bash -G sudo $defaultUser
    fi
    printf '%s:%s
' '$defaultUser' '$defaultPassword' | chpasswd
    usermod -aG sudo $defaultUser
fi
apt-get update
apt-get full-upgrade -y
apt-get install -y git curl ca-certificates gnupg lsb-release
"@

        Write-Step "在 Debian 中初始化用户、完成系统更新并安装 Git / Initializing Debian user, applying system updates, and installing Git"
        wsl.exe -d Debian --user root -- sh -lc $wslSetupScript
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "WSL2 / Debian 配置完成 / WSL2 / Debian setup completed"
        }
        else {
            Write-Warn "WSL2 / Debian 配置命令返回非零状态，可能需要手动重试 / WSL2 / Debian setup returned a non-zero status; manual retry may be needed"
        }
    }
    else {
        Write-Warn "当前环境无法调用 wsl.exe，跳过 WSL 配置 / Unable to invoke wsl.exe in this environment, skipping WSL setup"
    }
}
else {
    Write-Note "跳过 WSL2 / Debian 安装 / Skipping WSL2 / Debian installation"
}

Write-Header "开发工具安装完成 / Development tools installation completed"
Write-Note "当前已安装的开发工具 / Currently installed development tools:"
scoop list
