#!/usr/bin/env pwsh

<#
.SYNOPSIS
    系统工具安装 / System Tools Installation

.DESCRIPTION
    安装系统增强工具、实用程序和命令行工具
    Install system enhancement tools, utilities and command-line tools
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

Write-Header "系统工具安装 / System Tools Installation"

# 检查 Scoop
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Err "Scoop 未安装，请先运行系统基础环境配置脚本 / Scoop not installed, please run the system foundation setup script first"
    throw "Scoop 未安装 / Scoop not installed"
}

# Sysinternals 工具集
Write-Header "Sysinternals 工具集 / Sysinternals Suite"

Install-ScoopPackages (Get-PackageSection 'sys.sysinternals')

# 系统信息和监控工具
Write-Header "系统信息和监控工具 / System Info and Monitoring Tools"

Install-ScoopPackages (Get-PackageSection 'sys.monitor')

# 文件管理器
Write-Header "文件管理器 / File Managers"

Install-ScoopPackages (Get-PackageSection 'sys.fileMgr')

# 压缩工具
Write-Header "压缩工具 / Compression Tools"

Install-ScoopPackages (Get-PackageSection 'sys.compression')

# Windows 增强工具
Write-Header "Windows 增强工具 / Windows Enhancement Tools"

Install-ScoopPackages (Get-PackageSection 'sys.winTools')

# Win顺 / WinShun（文件搜索和启动器，替代 Flow Launcher / File search launcher, replaces Flow Launcher）
Write-Header "Win顺 / WinShun (文件搜索和启动器 / File search and launcher)"

if (Test-ScoopInstalled "winshun") {
    Write-Ok "winshun 已安装 / winshun is already installed"
}
else {
    $installWinShun = Confirm-Install "是否安装 Win顺 WinShun（替代 Flow Launcher）？(y/N) / Install WinShun (replaces Flow Launcher)? (y/N)"
    if ($installWinShun -match '^[Yy]$') {
        $bucketList = scoop bucket list
        if ($bucketList -match 'winshun') {
            Write-Ok "Bucket 'winshun' 已添加 / Bucket 'winshun' already added"
        }
        else {
            Write-Step "添加 bucket: winshun / Adding bucket: winshun"
            scoop bucket add winshun https://github.com/LingCore/WinShun
            Write-Ok "Bucket 'winshun' 添加成功 / Bucket 'winshun' added successfully"
        }

        scoop install winshun
        Reset-ScoopCache
        Write-Ok "winshun 安装完成 / winshun installation completed"
        Write-Note "索引服务不随 Scoop 安装：默认仅索引手动添加的文件夹 / Index service is not installed by Scoop: only folders you pick are indexed"
        Write-Note "整盘索引：设置 → 搜索范围 → 磁盘 → 索引方式（需管理员权限）/ Whole-disk index: Settings → Search scope → Disks → Index method (admin required)"
    }
}

# OpenHashTab (文件哈希右键扩展)
Write-Header "OpenHashTab (文件哈希右键扩展) / OpenHashTab (File Hash Context Menu)"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过 OpenHashTab 安装 / winget not installed, skipping OpenHashTab installation"
}
else {
    Install-WingetApps (Get-PackageSection 'sys.openHashTab') -Force
}

# 终端与命令行工具
Write-Header "终端与命令行工具 / Terminal & CLI Tools"

Install-ScoopPackages (Get-PackageSection 'sys.term')

# 网络工具
Write-Header "网络工具 / Network Tools"

Install-ScoopPackages (Get-PackageSection 'sys.network')

# OpenSSH Preview（比 Windows 内置版本更新 / Newer than the built-in OpenSSH）
Write-Header "OpenSSH Preview"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过 OpenSSH Preview 安装 / winget not installed, skipping OpenSSH Preview installation"
}
else {
    Install-WingetApps (Get-PackageSection 'sys.openSsh') -Force

    # winget 已安装后再次执行走 MSI 修复(repair)路径：组件标记键
    # HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\ssh-agent.exe
    # 已存在时 ServiceInstall 动作会被跳过，ssh-agent 服务不会重建（7045 事件也不会出现）
    # Re-running after install triggers MSI repair, which skips ServiceInstall when the component
    # flag key above already exists — the ssh-agent service is then missing and must be created manually
    $sshAgentExe = "$env:ProgramFiles\OpenSSH\ssh-agent.exe"
    $sshAgentSvc = Get-Service ssh-agent -ErrorAction SilentlyContinue

    if (-not $sshAgentSvc) {
        Write-Warn "未检测到 ssh-agent 服务 / ssh-agent service not found"
        Write-Note "MSI 修复不会重建服务（组件标记键已存在）/ MSI repair does not recreate the service"
        Write-Note "手动创建 / Create manually (管理员 / elevated):"
        Write-Note "  New-Service -Name ssh-agent -BinaryPathName '$sshAgentExe' ``"
        Write-Note "    -DisplayName 'OpenSSH Authentication Agent' -StartupType Automatic"
        Write-Note "  Start-Service ssh-agent"

        $createSvc = Confirm-Install "是否现在创建 ssh-agent 服务？(Y/n) / Create the ssh-agent service now? (Y/n)"
        if ($createSvc -notmatch '^[Nn]$') {
            if (-not (Test-Path $sshAgentExe)) {
                Write-Err "未找到 $sshAgentExe / not found"
            }
            elseif (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                Write-Warn "需要管理员权限，请以管理员身份运行本脚本 / Administrator privileges required"
            }
            else {
                try {
                    New-Service -Name ssh-agent -BinaryPathName "`"$sshAgentExe`"" `
                        -DisplayName "OpenSSH Authentication Agent" -StartupType Automatic | Out-Null
                    Start-Service ssh-agent
                    Write-Ok "ssh-agent 服务已创建并启动 / ssh-agent service created and started"
                }
                catch {
                    Write-Err "ssh-agent 服务创建失败 / failed to create ssh-agent service: $($_.Exception.Message)"
                }
            }
        }
    }
    elseif ($sshAgentSvc.Status -ne "Running") {
        Write-Step "启动 ssh-agent 服务 / Starting ssh-agent service"
        Start-Service ssh-agent
        Write-Ok "ssh-agent 服务已启动 / ssh-agent service started"
    }
    else {
        Write-Ok "ssh-agent 服务运行中 / ssh-agent service is running"
    }

    Write-Note "KeePassXC 需在 Settings → SSH Agent 勾选 Enable SSH agent integration 并选择 Use OpenSSH"
    Write-Note "KeePassXC: enable SSH agent integration and choose Use OpenSSH"
}

Write-Header "系统工具安装完成 / System tools installation completed"
$globalRoot = if ($env:SCOOP_GLOBAL) { $env:SCOOP_GLOBAL } else { "C:\ProgramData\scoop" }
$globalAppsDir = Join-Path $globalRoot "apps"
Write-Note "全局安装的应用 / Globally installed apps:"
if (Test-Path $globalAppsDir) {
    Get-ChildItem $globalAppsDir -Directory | Select-Object -ExpandProperty Name
}
else {
    Write-Note "未检测到全局应用目录 / No global apps directory found"
}

Write-FailureSummary
if ((Get-FailureCount) -gt 0) { exit 1 }
