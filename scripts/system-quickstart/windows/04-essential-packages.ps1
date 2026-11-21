#!/usr/bin/env pwsh

<#
.SYNOPSIS
    必备软件包安装 / Essential Applications Installation

.DESCRIPTION
    安装日常使用的应用程序
    Install daily use applications
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
        Write-Note "  [1] zen-browser + helium（默认 / default）"
        for ($i = 0; $i -lt $browserOptions.Count; $i++) {
            $state = if ($installedBrowsers -contains $browserOptions[$i].Name) { "（已安装 / installed）" } else { "" }
            Write-Note "  [$($i + 2)] $($browserOptions[$i].Desc) $state"
        }
        Write-Note "  [$($browserOptions.Count + 2)] 全部安装 / Install all"

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

Install-ScoopPackages (Get-PackageSection 'ess.productivity').Packages

# 密码管理器
Write-Header "密码管理器 / Password Managers"

Install-ScoopPackages (Get-PackageSection 'ess.password').Packages

# 邮件客户端
Write-Header "邮件客户端 / Email Clients"

Install-ScoopPackages (Get-PackageSection 'ess.email').Packages

# 通讯软件
Write-Header "通讯软件 / Communication Apps"

Install-ScoopPackages (Get-PackageSection 'ess.comm').Packages

# 文件同步
Write-Header "文件同步 / File Synchronization"

Install-ScoopPackages (Get-PackageSection 'ess.sync').Packages

# 远程控制
Write-Header "远程控制 / Remote Control"

Install-ScoopPackages (Get-PackageSection 'ess.remote').Packages

# 下载工具
Write-Header "下载工具 / Download Tools"

Install-ScoopPackages (Get-PackageSection 'ess.download').Packages

# 多媒体
Write-Header "多媒体工具 / Multimedia Tools"

Install-ScoopPackages (Get-PackageSection 'ess.multimedia').Packages

# 阅读器
Write-Header "阅读器 / Readers"

Install-ScoopPackages (Get-PackageSection 'ess.readers').Packages

# 字体
Write-Header "字体 / Fonts"

Install-ScoopPackages (Get-PackageSection 'ess.fonts').Packages

# 游戏平台
Write-Header "游戏平台 / Game Platforms"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过游戏平台安装 / winget not installed, skipping game platforms installation"
}
else {
    Install-WingetApps (Get-PackageSection 'ess.games').Packages -Force
}

Write-Header "必备软件包安装完成 / Essential applications installation completed"
Write-Note "当前已安装的所有应用 / All currently installed applications:"
scoop list

Write-FailureSummary
if ((Get-FailureCount) -gt 0) { exit 1 }
