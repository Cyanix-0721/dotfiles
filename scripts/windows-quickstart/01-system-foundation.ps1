#!/usr/bin/env pwsh

<#
.SYNOPSIS
    系统基础环境配置 / System Foundation Setup

.DESCRIPTION
    安装和配置 Scoop 包管理器及基础开发工具
    Install and configure Scoop package manager and basic development tools
#>

param(
    [switch]$AutoYes,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# 加载公共函数
. "$PSScriptRoot/00-common.ps1"
Set-DryRun -DryRun:$DryRun | Out-Null

# 初始化自动确认模式
Initialize-AutoYes -AutoYes:$AutoYes

Write-Header "系统基础环境配置 / System Foundation Setup"

# 更新 winget 源
Write-Step "更新 winget 源 / Updating winget sources"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过更新 / winget not installed, skipping source update"

    $openChoice = Read-Choice -Prompt "是否打开安装页面以安装 winget？1) Microsoft Store（推荐） 2) GitHub Releases（下载）；输入 1/2，回车跳过 / Open install page? 1) MS Store (recommended) 2) GitHub Releases (download); enter to skip" -Default ""
    switch ($openChoice) {
        '1' {
            try {
                Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
                Write-Ok "已打开 Microsoft Store 页面 / Opened Microsoft Store"
            }
            catch {
                Write-Err "无法打开 Microsoft Store 页面，请手动访问：ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
            }
        }
        '2' {
            try {
                Start-Process "https://github.com/microsoft/winget-cli/releases"
                Write-Ok "已打开 GitHub Releases 页面 / Opened GitHub Releases"
            }
            catch {
                Write-Err "无法打开 GitHub Releases 页面，请手动访问：https://github.com/microsoft/winget-cli/releases"
            }
        }
        default {
            Write-Note "跳过 winget 安装页面 / Skipping winget install page"
        }
    }
}
else {
    try {
        winget source update
    }
    catch {
        Write-Warn "更新 winget 源失败（非致命），继续执行后续步骤 / Updating winget sources failed (non-fatal), continuing"
    }
}

# 确保 PowerShell 7 已安装（可选，推荐；脚本本身兼容 PowerShell 5.1）
# Ensure PowerShell 7 is installed (optional, recommended; scripts stay 5.1-compatible)
Write-Step "检查 PowerShell 7 / Checking PowerShell 7"
if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    Write-Ok "PowerShell 7 已安装 / PowerShell 7 is already installed"
}
else {
    $installPwsh = Confirm-Install "未检测到 PowerShell 7，是否用 winget 安装？(Y/n) / PowerShell 7 not found, install via winget? (Y/n)"
    if ($installPwsh -notmatch '^[Nn]$') {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Warn "winget 未安装，跳过 PowerShell 7 安装 / winget not installed, skipping PowerShell 7 installation"
        }
        else {
            try {
                winget install --id Microsoft.PowerShell --exact --silent --accept-package-agreements --accept-source-agreements
                Write-Ok "PowerShell 7 安装完成，请重新打开终端以使用 pwsh / PowerShell 7 installed; reopen terminal to use pwsh"
            }
            catch {
                Write-Warn "PowerShell 7 安装失败（非致命）/ Installing PowerShell 7 failed (non-fatal): $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Note "跳过 PowerShell 7 安装 / Skipping PowerShell 7 installation"
    }
}

# 检查并安装 Scoop
Write-Step "检查 Scoop 安装状态 / Checking Scoop installation"
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Note "Scoop 未安装，开始安装… / Scoop not installed, starting installation…"

    # 设置执行策略
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

    # 安装 Scoop
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

    Write-Ok "Scoop 安装完成 / Scoop installation completed"
}
else {
    Write-Ok "Scoop 已安装 / Scoop is already installed"
}

# 更新 Scoop
Write-Step "更新 Scoop / Updating Scoop"
scoop update

# 清理 Scoop 旧版本（可选，默认否；仅回车=不清）
Write-Step "清理 Scoop 旧版本 / Clean up old Scoop versions"
$cleanupOld = Confirm-Install "是否自动清除 Scoop 旧版本？(y/N) / Automatically remove old Scoop versions? (y/N)"
if ($cleanupOld -match '^[Yy]$') {
    scoop cleanup --all
    Write-Ok "Scoop 旧版本清理完成 / Old Scoop versions cleaned up"
}
else {
    Write-Note "跳过旧版本清理 / Skipping old version cleanup"
}

# 安装 Git（Scoop 依赖）
Write-Step "安装 Git / Installing Git"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    scoop install git
    Write-Ok "Git 安装完成 / Git installation completed"
}
else {
    Write-Ok "Git 已安装 / Git is already installed"
}

# 安装 Aria2（加速下载）
Write-Step "配置 Aria2 下载加速 / Configuring Aria2 for faster downloads"
if (-not (Test-ScoopInstalled "aria2")) {
    scoop install aria2
    scoop config aria2-enabled true
    scoop config aria2-warning-enabled false
    Write-Ok "Aria2 配置完成 / Aria2 configuration completed"
}
else {
    Write-Ok "Aria2 已安装 / Aria2 is already installed"
}

# 添加 Scoop 常用 buckets
Write-Step "添加 Scoop buckets / Adding Scoop buckets"

$buckets = @("extras", "versions", "nerd-fonts", "sysinternals", "nirsoft")

$bucketList = scoop bucket list

foreach ($bucketName in $buckets) {
    if ($bucketList -match $bucketName) {
        Write-Ok "Bucket '$bucketName' 已添加 / Bucket '$bucketName' already added"
    }
    else {
        Write-Step "添加 bucket: $bucketName / Adding bucket: $bucketName"
        scoop bucket add $bucketName
        Write-Ok "Bucket '$bucketName' 添加成功 / Bucket '$bucketName' added successfully"
    }
}

# 安装 gsudo（类似 Linux 的 sudo；必装）
Write-Step "安装 gsudo / Installing gsudo"
if (-not (Get-Command gsudo -ErrorAction SilentlyContinue)) {
    scoop install gsudo
    Write-Ok "gsudo 安装完成 / gsudo installation completed"
}
else {
    Write-Ok "gsudo 已安装 / gsudo is already installed"
}

# PowerShell 组件（pwsh 装好后一次性可选安装；默认否）
# PowerShell components (one-time optional install after pwsh; default no)
Write-Header "PowerShell 组件 / PowerShell Components"
$installPsComponents = Confirm-Install "是否安装常用 PowerShell 组件（PSScriptAnalyzer / PSReadLine / PSWindowsUpdate / ImportExcel / NTFSSecurity）？(y/N) / Install PowerShell components? (y/N)"
if ($installPsComponents -match '^[Yy]$') {
    # PS 模块（缺则装；TLS1.2 供 PowerShell 5.1）
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $psModules = @("PSScriptAnalyzer", "PSReadLine", "PSWindowsUpdate", "ImportExcel", "NTFSSecurity")
    foreach ($moduleName in $psModules) {
        if (Get-Module -ListAvailable -Name $moduleName) {
            Write-Ok "$moduleName 已安装 / $moduleName already installed"
        }
        else {
            try {
                Install-Module -Name $moduleName -Scope CurrentUser -Force -ErrorAction Stop
                Write-Ok "$moduleName 安装完成 / $moduleName installation completed"
            }
            catch {
                Write-Warn "$moduleName 安装失败（非致命）/ Installing $moduleName failed: $($_.Exception.Message)"
            }
        }
    }
}
else {
    Write-Note "跳过 PowerShell 组件安装 / Skipping PowerShell components installation"
}

# 安装 Visual C++ 运行库
Write-Header "Visual C++ 运行库 / Visual C++ Redistributables"

$installVCRedist = Confirm-Install "是否安装 Visual C++ 2005-2022 运行库？(Y/n) / Install Visual C++ 2005-2022 Redistributables? (Y/n)"
if ($installVCRedist -notmatch '^[Nn]$') {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warn "winget 未安装，跳过 Visual C++ 运行库安装 / winget not installed, skipping Visual C++ installation"
    }
    else {
        Write-Step "正在安装 Visual C++ 运行库... / Installing Visual C++ Redistributables..."
        Install-WingetApps (Get-PackageSection 'foundation.vcredist').Packages -Force

        Write-Ok "Visual C++ 运行库安装完成 / Visual C++ Redistributables installation completed"
    }
}

# 安装 Microsoft Edge WebView2 运行时
Write-Header "Microsoft Edge WebView2 运行时 / WebView2 Runtime"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过 WebView2 安装 / winget not installed, skipping WebView2 installation"
}
else {
    Install-WingetApps (Get-PackageSection 'foundation.webview2').Packages -Force
}

# 安装 Chezmoi 配置管理工具
Write-Header "Chezmoi 配置管理工具 / Chezmoi Configuration Management Tool"
if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    $installChezmoi = Confirm-Install "是否安装 Chezmoi？(Y/n) / Install Chezmoi? (Y/n)"
    if ($installChezmoi -notmatch '^[Nn]$') {
        scoop install chezmoi
        Write-Ok "Chezmoi 安装完成 / Chezmoi installation completed"

        $initChezmoi = Confirm-Install "是否初始化 dotfiles 配置？(Y/n) / Initialize dotfiles configuration? (Y/n)"
        if ($initChezmoi -notmatch '^[Nn]$') {
            chezmoi init https://github.com/Cyanix-0721/dotfiles.git --apply
            Write-Ok "dotfiles 配置初始化完成 / dotfiles configuration initialized"
        }
    }
}
else {
    Write-Ok "Chezmoi 已安装 / Chezmoi is already installed"
}

Write-Header "系统基础环境配置完成 / System foundation setup completed"
Write-Note "当前已安装的应用列表 / Currently installed applications:"
scoop list

Write-FailureSummary
if ((Get-FailureCount) -gt 0) { exit 1 }
