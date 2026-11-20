#!/usr/bin/env pwsh

<#
.SYNOPSIS
    系统工具安装 / System Tools Installation

.DESCRIPTION
    安装系统增强工具、实用程序和命令行工具
    Install system enhancement tools, utilities and command-line tools
#>

param(
    [switch]$AutoYes
)

$ErrorActionPreference = "Stop"

# 加载公共函数
. "$PSScriptRoot/00-common.ps1"

# 初始化自动确认模式
Initialize-AutoYes

Write-Header "系统工具安装 / System Tools Installation"

# 检查 Scoop
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Err "Scoop 未安装，请先运行系统基础环境配置脚本 / Scoop not installed, please run the system foundation setup script first"
    throw "Scoop 未安装 / Scoop not installed"
}

# Sysinternals 工具集
Write-Header "Sysinternals 工具集 / Sysinternals Suite"

$sysinternalsTools = @{
    "sysmon"           = @{ Desc = "Sysmon (系统监视器 / System Monitor)"; Global = $true }
    "handle"           = @{ Desc = "Handle (句柄查看工具 / View open handles)"; Global = $false }
    "autoruns"         = @{ Desc = "Autoruns (启动项管理工具 / Startup manager)"; Global = $false }
    "autologon"        = @{ Desc = "AutoLogon (自动登录工具 / Auto login utility)"; Global = $true }
    "process-explorer" = @{ Desc = "Process Explorer (高级任务管理器 / Advanced Task Manager)"; Global = $false }
    "procmon"          = @{ Desc = "Process Monitor (文件/注册表监视 / File & Registry monitor)"; Global = $false }
    "tcpview"          = @{ Desc = "TCPView (网络连接查看 / TCP/UDP connection viewer)"; Global = $false }
    "sigcheck"         = @{ Desc = "Sigcheck (文件签名检查 / File signature checker)"; Global = $false }
}

Install-ScoopPackages $sysinternalsTools

# 系统信息和监控工具
Write-Header "系统信息和监控工具 / System Info and Monitoring Tools"

$monitorTools = @{
    "fastfetch"      = @{ Desc = "fastfetch (系统信息显示 / System information display)"; Global = $false }
    "trafficmonitor" = @{ Desc = "TrafficMonitor (网速监控悬浮窗 / Network traffic monitor)"; Global = $false }
}

Install-ScoopPackages $monitorTools

# 文件管理器
Write-Header "文件管理器 / File Managers"

$fileManagers = @{
    "yazi" = @{ Desc = "Yazi (终端文件管理器 / Terminal file manager)"; Global = $false; PostNote = @("提示：Yazi 会自动安装以下依赖：imagemagick, poppler, resvg / Note: Yazi auto-installs deps: imagemagick, poppler, resvg") }
}

Install-ScoopPackages $fileManagers

# 压缩工具
Write-Header "压缩工具 / Compression Tools"

$compressionTools = @{
    "7zip"   = @{ Desc = "7zip (压缩/解压工具 / Archive utility)"; Global = $false }
    "peazip" = @{ Desc = "PeaZip (压缩/解压工具 / Archive utility)"; Global = $false }
}

Install-ScoopPackages $compressionTools

# Windows 增强工具
Write-Header "Windows 增强工具 / Windows Enhancement Tools"

$winTools = @{
    "everything-beta" = @{ Desc = "Everything (快速文件搜索 / Fast file search)"; Global = $false }
    "everything-cli"  = @{ Desc = "Everything CLI (命令行文件搜索 / Command-line file search)"; Global = $false }
    "fancontrol"      = @{ Desc = "FanControl (风扇控制工具 / Fan control utility)"; Global = $false }
    "hwinfo"          = @{ Desc = "HWiNFO (系统信息与诊断工具 / System information and diagnostics)"; Global = $false }
    "y-cruncher"      = @{ Desc = "Y-Cruncher (高性能计算工具 / High-performance computing tool)"; Global = $false }
    "krokiet"         = @{ Desc = "Krokiet (图片查重工具 / picture duplicate finder)"; Global = $false }
    "ventoy"          = @{ Desc = "Ventoy (多合一启动盘制作工具 / Multi-boot USB creator)"; Global = $false }
    "rufus"           = @{ Desc = "Rufus (USB 启动盘制作工具 / USB bootable creator)"; Global = $false }
    "wiztree"         = @{ Desc = "WizTree (磁盘空间分析工具 / Disk space analyzer)"; Global = $false }
    "spacesniffer"    = @{ Desc = "SpaceSniffer (磁盘空间可视化工具 / Disk space visualizer)"; Global = $false }
    "memreduct"       = @{ Desc = "Mem Reduct (内存优化工具 / Memory optimizer)"; Global = $false }
    "msiafterburner"  = @{ Desc = "MSI Afterburner (GPU 超频与监控 / GPU overclocking and monitoring)"; Global = $true }
    "rtss"            = @{ Desc = "RivaTuner Statistics Server (OSD & FPS 限制 / OSD & FPS limiter)"; Global = $true }
    "ddu"             = @{ Desc = "Display Driver Uninstaller (显卡驱动清理工具 / GPU driver cleaner)"; Global = $false }
    "quicklook"       = @{ Desc = "QuickLook (空格键快速预览文件 / File preview with spacebar)"; Global = $false }
    "geekuninstaller" = @{ Desc = "Geek Uninstaller (强力卸载工具 / Thorough uninstaller)"; Global = $false }
    "nircmd"          = @{ Desc = "NirCmd (命令行小工具集合 / Command-line utility collection)"; Global = $false }
}

Install-ScoopPackages $winTools

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
    $wingApps = @{ 
        "namazso.OpenHashTab" = @{ Desc = "OpenHashTab (文件哈希右键扩展 / File Hash Context Menu)"; InstallArgs = @("--exact", "--silent") }
    }
    Install-WingetApps $wingApps -Force
}

# 终端与命令行工具
Write-Header "终端与命令行工具 / Terminal & CLI Tools"

$termTools = @{
    "wezterm-nightly"     = @{ Desc = "WezTerm (GPU 加速终端 / GPU-accelerated terminal)"; Global = $false }
    "windows-terminal"    = @{ Desc = "Windows Terminal (微软官方终端 / Microsoft official terminal)"; Global = $false }
    "less"                = @{ Desc = "less (终端分页器 / Terminal pager)"; Global = $false }
    "microsoft-coreutils" = @{ Desc = "GNU Coreutils (ls/cp/mv 等 Linux 核心命令 / GNU core utilities)"; Global = $false }
    "starship"            = @{ Desc = "Starship (跨平台命令行提示符 / Cross-platform shell prompt)"; Global = $false }
    "zoxide"              = @{ Desc = "zoxide (智能目录跳转 / Smarter cd command)"; Global = $false }
    "fzf"                 = @{ Desc = "fzf (模糊查找器 / Fuzzy finder)"; Global = $false }
    "ripgrep"             = @{ Desc = "ripgrep (快速搜索工具 / Fast search tool)"; Global = $false }
    "fd"                  = @{ Desc = "fd (快速文件查找 / Fast file finder)"; Global = $false }
    "bat"                 = @{ Desc = "bat (cat 增强版 / cat with syntax highlighting)"; Global = $false }
    "eza"                 = @{ Desc = "eza (ls 增强版 / Modern ls replacement)"; Global = $false }
}

Install-ScoopPackages $termTools

# 网络工具
Write-Header "网络工具 / Network Tools"

$networkTools = @{
    "nmap"      = @{ Desc = "nmap (网络扫描工具，含 ncat / Network scanner, includes ncat)"; Global = $false }
    "scrcpy"    = @{ Desc = "scrcpy (Android 投屏工具 / Android screen mirroring)"; Global = $false }
    "mkcert"    = @{ Desc = "mkcert (本地 HTTPS 证书 / Local HTTPS certificates)"; Global = $false }
    "wireshark" = @{ Desc = "Wireshark (网络协议分析器 / Network protocol analyzer)"; Global = $false }
}

Install-ScoopPackages $networkTools

# OpenSSH Preview（比 Windows 内置版本更新 / Newer than the built-in OpenSSH）
Write-Header "OpenSSH Preview"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过 OpenSSH Preview 安装 / winget not installed, skipping OpenSSH Preview installation"
}
else {
    $wingApps = @{
        "Microsoft.OpenSSH.Preview" = @{ Desc = "OpenSSH Preview (Microsoft 官方 OpenSSH 预览版 / Microsoft OpenSSH preview)"; InstallArgs = @("--exact", "--silent") }
    }
    Install-WingetApps $wingApps -Force

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
