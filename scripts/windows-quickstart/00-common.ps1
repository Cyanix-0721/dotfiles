#!/usr/bin/env pwsh

<#
.SYNOPSIS
    公共函数库 / Common functions for quick-setup scripts

.DESCRIPTION
    提供统一的日志输出、安装确认、Scoop/winget 安装封装
    由各 quick-start 脚本通过 dot-source 加载
#>

$Script:CommonLoaded = $true

# ===== 日志输出 / Logging =====
function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host "→ $Message…" -ForegroundColor Magenta
}

function Write-Ok {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Note {
    param([string]$Message)
    Write-Host "∙ $Message" -ForegroundColor Gray
}

# ===== 安装确认 / Install confirmation =====
function Initialize-AutoYes {
    param([switch]$AutoYes)
    # -AutoYes 显式传入（Run All）或脚本级 $Script:AutoYes 已启用时，直接进入自动确认
    if ($AutoYes -or $Script:AutoYes) {
        $Script:AutoYes = $true
        Write-Note "自动确认模式已启用 / Auto-yes mode enabled"
    }
    else {
        $autoYesChoice = Read-Host "是否全选 Y（自动确认所有安装）？(Y/n) / Select all Y (auto-confirm all installations)? (Y/n)"
        if ($autoYesChoice -notmatch '^[Nn]') { $Script:AutoYes = $true }
    }
}

function Confirm-Install {
    param([string]$Prompt)
    if ($Script:AutoYes) { return "Y" }
    return Read-Host $Prompt
}

function Read-Choice {
    # 选择型提示（非 Y/N）：自动确认模式下返回默认值，避免被强塞 "Y"
    param(
        [string]$Prompt,
        [string]$Default = ""
    )
    if ($Script:AutoYes) { return $Default }
    $choice = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($choice)) { return $Default }
    return $choice
}

# ===== Scoop 已安装检测（缓存结果，避免重复调用 scoop list）=====
$Script:ScoopInstalledCache = $null

function Get-ScoopInstalled {
    if ($null -eq $Script:ScoopInstalledCache) {
        $Script:ScoopInstalledCache = @(scoop list 2>$null)
    }
    return $Script:ScoopInstalledCache
}

function Reset-ScoopCache {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    if ($PSCmdlet.ShouldProcess('Scoop 已安装缓存', 'Reset')) {
        $Script:ScoopInstalledCache = $null
    }
}

function Test-ScoopInstalled {
    param([string]$Name)
    # scoop list 返回对象，按 Name 精确匹配（大小写不敏感）
    return [bool](Get-ScoopInstalled | Where-Object { $_.Name -eq $Name })
}

# ===== Scoop 安装封装 =====
function Install-ScoopPackage {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Desc = $Name,
        [switch]$AsGlobal,
        [switch]$DefaultYes,   # $true：默认安装（回车=装）；$false：默认跳过（回车=不装）
        [string[]]$PostNote,
        [string[]]$AlreadyNote
    )

    if (Test-ScoopInstalled $Name) {
        Write-Ok "$Name 已安装 / $Name is already installed"
        if ($AlreadyNote) { foreach ($line in $AlreadyNote) { Write-Note $line } }
        return
    }

    if ($DefaultYes) {
        $install = Confirm-Install "是否安装 $Desc？(Y/n) / Install $Desc? (Y/n)"
        $shouldInstall = ($install -notmatch '^[Nn]$')
    }
    else {
        $install = Confirm-Install "是否安装 $Desc？(y/N) / Install $Desc? (y/N)"
        $shouldInstall = ($install -match '^[Yy]$')
    }
    if (-not $shouldInstall) { return }

    if ($AsGlobal) {
        scoop install $Name --global
        if ($LASTEXITCODE -eq 0) { Write-Ok "$Name 安装完成（全局） / $Name installation completed (global)" }
        else { Write-Err "$Name 安装失败（全局，退出码 $LASTEXITCODE）/ $Name installation failed (global, exit $LASTEXITCODE)" }
    }
    else {
        scoop install $Name
        if ($LASTEXITCODE -eq 0) { Write-Ok "$Name 安装完成 / $Name installation completed" }
        else { Write-Err "$Name 安装失败（退出码 $LASTEXITCODE）/ $Name installation failed (exit $LASTEXITCODE)" }
    }
    Reset-ScoopCache
    if ($PostNote) { foreach ($line in $PostNote) { Write-Note $line } }
}

function Install-ScoopPackages {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Batch install helper; plural noun is intentional')]
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Packages
    )
    foreach ($entry in $Packages.GetEnumerator()) {
        $info = $entry.Value
        # 未显式指定 Default 时默认推荐安装（$true）；只有显式写 $false 才表示可选
        $defaultYes = if ($info.ContainsKey('Default')) { [bool]$info.Default } else { $true }
        Install-ScoopPackage -Name $entry.Key -Desc $info.Desc -AsGlobal:$info.Global -DefaultYes:$defaultYes -PostNote $info.PostNote -AlreadyNote $info.AlreadyNote
    }
}

# ===== winget 已安装检测 =====
function Test-WingetInstalled {
    param([Parameter(Mandatory = $true)][string]$Id)
    try {
        # -SimpleMatch 按字面匹配，避免 ID 中的 + 等正则特殊字符导致误判
        return [bool](winget list --id $Id --exact -s winget 2>$null | Select-String -SimpleMatch $Id)
    }
    catch {
        return $false
    }
}

# ===== winget 底层安装执行 =====
# 统一携带 --source winget 与协议接受参数；供 Install-WingetApp 封装及各脚本直接调用
function Invoke-WingetInstall {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [string[]]$InstallArgs = @("--exact", "--silent")
    )
    winget install --id $Id @($InstallArgs) --source winget --accept-source-agreements --accept-package-agreements
}

# ===== winget 安装封装 =====
function Install-WingetApp {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$Desc = $Id,
        [string[]]$InstallArgs = @("--exact", "--silent"),
        [switch]$Force,       # 跳过询问直接安装（用于已确认的批量安装）
        [switch]$DefaultYes
    )

    if (Test-WingetInstalled -Id $Id) {
        Write-Ok "$Id 已安装 / $Id is already installed"
        return
    }

    $shouldInstall = $true
    if (-not $Force) {
        if ($DefaultYes) {
            $install = Confirm-Install "是否安装 $Desc？(Y/n) / Install $Desc? (Y/n)"
            $shouldInstall = ($install -notmatch '^[Nn]$')
        }
        else {
            $install = Confirm-Install "是否安装 $Desc？(y/N) / Install $Desc? (y/N)"
            $shouldInstall = ($install -match '^[Yy]$')
        }
    }
    if (-not $shouldInstall) { return }

    Write-Step "通过 winget 安装 $Desc ($Id) / Installing $Desc via winget"
    Invoke-WingetInstall -Id $Id -InstallArgs $InstallArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "$Id 安装完成 / $Id installation completed"
    }
    else {
        Write-Err "$Id 安装失败 / $Id installation failed"
    }
}

function Install-WingetApps {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Batch install helper; plural noun is intentional')]
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Apps,
        [switch]$Force
    )
    foreach ($entry in $Apps.GetEnumerator()) {
        $info = $entry.Value
        # 未显式指定 Default 时默认推荐安装（$true）；只有显式写 $false 才表示可选
        $defaultYes = if ($info.ContainsKey('Default')) { [bool]$info.Default } else { $true }
        if ($info.InstallArgs) {
            Install-WingetApp -Id $entry.Key -Desc $info.Desc -InstallArgs $info.InstallArgs -Force:$Force -DefaultYes:$defaultYes
        }
        else {
            Install-WingetApp -Id $entry.Key -Desc $info.Desc -Force:$Force -DefaultYes:$defaultYes
        }
    }
}
