#!/usr/bin/env pwsh

<#
.SYNOPSIS
    公共函数库 / Common functions for quick-setup scripts

.DESCRIPTION
    提供统一的日志输出、安装确认、Scoop/winget 安装封装
    由各 quick-start 脚本通过 dot-source 加载
#>

$Script:CommonLoaded = $true

# ===== 包清单 / Package manifest =====
# 清单数据在 manifests/packages.psd1；此处只做加载、校验与分组取用，不含包名。
$Script:PackageManifest = $null

function Get-PackageManifest {
    <#
    .SYNOPSIS
        加载并校验包清单数据文件（manifests/packages.psd1）。
    #>
    if ($null -ne $Script:PackageManifest) { return $Script:PackageManifest }

    $manifestPath = Join-Path $PSScriptRoot 'manifests/packages.psd1'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "未找到包清单文件 / Package manifest not found: $manifestPath"
    }
    $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
    if (-not $manifest.ContainsKey('Sections')) {
        throw "包清单缺少 Sections 键 / Manifest missing 'Sections': $manifestPath"
    }
    foreach ($id in $manifest.Sections.Keys) {
        $section = $manifest.Sections[$id]
        foreach ($field in 'Installer', 'Packages') {
            if (-not $section.ContainsKey($field)) {
                throw "包分组 '$id' 缺少字段 '$field' / Section '$id' missing '$field'"
            }
        }
        if ($section.Installer -notin @('scoop', 'winget')) {
            throw "包分组 '$id' 的 Installer 非法（应为 scoop/winget）: $($section.Installer)"
        }
        if (@($section.Packages).Count -eq 0) {
            throw "包分组 '$id' 的 Packages 为空 / Section '$id' has empty Packages"
        }
    }
    $Script:PackageManifest = $manifest
    return $Script:PackageManifest
}

function Get-PackageSection {
    <#
    .SYNOPSIS
        按分组 Id 取出该组包，转为 Install-ScoopPackages / Install-WingetApps 需要的
        有序字典（scoop 用 Name 作键，winget 用 Id 作键）。顺序与清单一致。
    #>
    param([Parameter(Mandatory = $true)][string]$Id)

    $manifest = Get-PackageManifest
    if (-not $manifest.Sections.ContainsKey($Id)) {
        throw "未知包分组 / Unknown package section: $Id"
    }
    $section = $manifest.Sections[$Id]
    $isWinget = ($section.Installer -eq 'winget')

    $ordered = [ordered]@{}
    foreach ($pkg in $section.Packages) {
        $key = if ($isWinget) { $pkg.Id } else { $pkg.Name }
        if ([string]::IsNullOrWhiteSpace($key)) {
            throw "包分组 '$Id' 存在缺少 $(if ($isWinget) { 'Id' } else { 'Name' }) 的条目 / Entry without key in '$Id'"
        }
        $info = @{}
        foreach ($prop in 'Desc', 'Global', 'Default', 'PostNote', 'AlreadyNote', 'InstallArgs') {
            if ($pkg.ContainsKey($prop)) { $info[$prop] = $pkg[$prop] }
        }
        $ordered[$key] = $info
    }
    return $ordered
}

# ===== 可观测性 / Observability =====
# 记录失败的安装项，供脚本末尾汇总并决定退出码。
$Script:Failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([Parameter(Mandatory = $true)][string]$Message)
    if (-not $Script:Failures.Contains($Message)) { $Script:Failures.Add($Message) }
}

function Get-FailureCount {
    return $Script:Failures.Count
}

function Write-FailureSummary {
    if ($Script:Failures.Count -eq 0) {
        Write-Ok "全部安装完成，无失败项 / All installations completed with no failures"
        return
    }
    Write-Warn "有 $($Script:Failures.Count) 项未成功 / $($Script:Failures.Count) item(s) failed:"
    foreach ($item in $Script:Failures) { Write-Note $item }
}

# 统一外部命令执行：检查 $LASTEXITCODE，非 0 抛出带命令与退出码的异常。
function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$Description = $FilePath
    )
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "命令失败 / Command failed (exit $LASTEXITCODE): $Description"
    }
}

# ===== 可观测性 / Observability：dry-run 与日志 =====
$Script:DryRun = $false
$Script:LogFile = $null

function Set-DryRun {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Toggles a script-scope dry-run flag only')]
    param([switch]$DryRun)
    if ($DryRun -or $env:QUICKSTART_DRY_RUN -eq '1') { $Script:DryRun = $true }
    return $Script:DryRun
}
function Test-DryRun { return $Script:DryRun }
function Start-Log {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a log file for this run; not covered by ShouldProcess')]
    param([string]$Path)
    if (-not $Path) {
        $Path = Join-Path ([System.IO.Path]::GetTempPath()) ("quickstart-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
    }
    $Script:LogFile = $Path
    Set-Content -LiteralPath $Path -Value "# quickstart log @ $(Get-Date -Format o)" -Encoding UTF8
    Write-Note "日志文件 / Log file: $Path"
}
function Write-LogLine {
    param([string]$Line)
    if ($Script:LogFile) { Add-Content -LiteralPath $Script:LogFile -Value $Line -Encoding UTF8 }
}

# ===== 日志输出 / Logging =====
function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
    Write-LogLine "==> $Message"
}
function Write-Step {
    param([string]$Message)
    Write-Host "→ $Message…" -ForegroundColor Magenta
    Write-LogLine "→ $Message"
}
function Write-Ok {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
    Write-LogLine "✓ $Message"
}
function Write-Warn {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
    Write-LogLine "⚠ $Message"
}
function Write-Err {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
    Write-LogLine "✗ $Message"
}
function Write-Note {
    param([string]$Message)
    Write-Host "∙ $Message" -ForegroundColor Gray
    Write-LogLine "∙ $Message"
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

    if (Test-DryRun) { Write-Note ("[dry-run] 将安装 $Name / would install $Name"); return }
    if ($AsGlobal) {
        scoop install $Name --global
        if ($LASTEXITCODE -eq 0) { Write-Ok "$Name 安装完成（全局） / $Name installation completed (global)" }
        else { Write-Err "$Name 安装失败（全局，退出码 $LASTEXITCODE）/ $Name installation failed (global, exit $LASTEXITCODE)"; Add-Failure "$Name (global)" }
    }
    else {
        scoop install $Name
        if ($LASTEXITCODE -eq 0) { Write-Ok "$Name 安装完成 / $Name installation completed" }
        else { Write-Err "$Name 安装失败（退出码 $LASTEXITCODE）/ $Name installation failed (exit $LASTEXITCODE)"; Add-Failure $Name }
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

    if (Test-DryRun) { Write-Note ("[dry-run] 将安装 $Id (winget) / would install $Id"); return }
    Write-Step "通过 winget 安装 $Desc ($Id) / Installing $Desc via winget"
    Invoke-WingetInstall -Id $Id -InstallArgs $InstallArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "$Id 安装完成 / $Id installation completed"
    }
    else {
        Write-Err "$Id 安装失败 / $Id installation failed"
        Add-Failure "$Id (winget)"
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
