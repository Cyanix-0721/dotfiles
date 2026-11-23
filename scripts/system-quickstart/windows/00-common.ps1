#!/usr/bin/env pwsh

<#
.SYNOPSIS
    公共函数库 / Common functions for quick-setup scripts

.DESCRIPTION
    提供统一的日志输出、安装确认、Scoop/winget 安装封装
    由各 quick-start 脚本通过 dot-source 加载
#>

if (Get-Variable -Name CommonLoaded -Scope Script -ValueOnly -ErrorAction SilentlyContinue) {
    return
}
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
    $allowedProps = if ($isWinget) {
        @('Id', 'Desc', 'Default', 'InstallArgs')
    }
    else {
        @('Name', 'Desc', 'Global', 'Default', 'PostNote', 'AlreadyNote')
    }

    $ordered = [ordered]@{}
    foreach ($pkg in $section.Packages) {
        if (-not ($pkg -is [System.Collections.IDictionary])) {
            throw "包分组 '$Id' 包含非字典条目 / Non-dictionary entry in '$Id'"
        }
        $key = if ($isWinget) { $pkg.Id } else { $pkg.Name }
        if ([string]::IsNullOrWhiteSpace($key)) {
            throw "包分组 '$Id' 存在缺少 $(if ($isWinget) { 'Id' } else { 'Name' }) 的条目 / Entry without key in '$Id'"
        }
        if ($ordered.Contains($key)) {
            throw "包分组 '$Id' 存在重复条目 '$key' / Duplicate entry '$key' in '$Id'"
        }
        foreach ($propKey in $pkg.Keys) {
            if ($propKey -notin $allowedProps) {
                throw "包分组 '$Id' 条目 '$key' 包含未知字段 '$propKey' / Unknown property '$propKey' for '$key' in '$Id'"
            }
        }
        $info = @{}
        foreach ($prop in 'Desc', 'Global', 'Default', 'PostNote', 'AlreadyNote', 'InstallArgs') {
            if ($pkg.ContainsKey($prop)) { $info[$prop] = $pkg[$prop] }
        }
        if (-not $info.ContainsKey('Desc') -or [string]::IsNullOrWhiteSpace([string]$info['Desc'])) {
            $info['Desc'] = $key
        }
        $ordered[$key] = $info
    }
    return $ordered
}

# ===== 权限与原生命令兼容辅助 =====
function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-NativeQuiet {
    <#
    .SYNOPSIS
        兼容 PowerShell 5.1 的外部命令调用：屏蔽 stderr 时不因 $ErrorActionPreference='Stop' 中止。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = 0
        & $FilePath @Arguments 2>$null
    }
    finally {
        $ErrorActionPreference = $prevEap
    }
}

# ===== 可观测性 / Observability =====
# 记录失败的安装项，供脚本末尾汇总并决定退出码。
$Script:Failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([Parameter(Mandatory = $true)][string]$Message)
    if ([string]::IsNullOrWhiteSpace($Message)) { return }
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

# 统一外部命令执行：检查 dry-run 与 $LASTEXITCODE，非 0 抛出带命令与退出码的异常。
function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$Description = $FilePath
    )
    if (Test-DryRun) {
        $argText = if ($Arguments -and $Arguments.Count -gt 0) { " $($Arguments -join ' ')" } else { '' }
        Write-Note "[dry-run] 将执行 / would run: $FilePath$argText ($Description)"
        $global:LASTEXITCODE = 0
        return
    }
    $global:LASTEXITCODE = 0
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "命令失败 / Command failed (exit $LASTEXITCODE): $Description"
    }
}

# ===== 可观测性 / Observability：dry-run 与日志 =====
$Script:DryRun = $false
$Script:LogFile = $null
if (-not [string]::IsNullOrWhiteSpace($env:QUICKSTART_LOG_FILE) -and $env:QUICKSTART_DRY_RUN -ne '1') {
    $Script:LogFile = $env:QUICKSTART_LOG_FILE
}

function Set-DryRun {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Toggles a script-scope dry-run flag only')]
    param([switch]$DryRun)
    if ($DryRun -or $env:QUICKSTART_DRY_RUN -eq '1') {
        $Script:DryRun = $true
        $Script:LogFile = $null
    }
    return $Script:DryRun
}

function Test-DryRun { return $Script:DryRun }

function Start-Log {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a log file for this run; not covered by ShouldProcess')]
    param([string]$Path)
    if (Test-DryRun) {
        $Script:LogFile = $null
        Write-Note "[dry-run] 跳过创建日志文件 / Skipping log file creation in dry-run"
        return
    }
    if (-not $Path -and -not [string]::IsNullOrWhiteSpace($env:QUICKSTART_LOG_FILE)) {
        $Path = $env:QUICKSTART_LOG_FILE
    }
    if (-not $Path) {
        $Path = Join-Path ([System.IO.Path]::GetTempPath()) ("quickstart-{0:yyyyMMdd-HHmmss}-{1}.log" -f (Get-Date), $PID)
    }
    $Script:LogFile = $Path
    if (-not (Test-Path -LiteralPath $Path)) {
        Set-Content -LiteralPath $Path -Value "# quickstart log @ $(Get-Date -Format o)" -Encoding UTF8
    }
    Write-Note "日志文件 / Log file: $Path"
}

function Write-LogLine {
    param([string]$Line)
    if ($Script:LogFile -and -not (Test-DryRun)) {
        Add-Content -LiteralPath $Script:LogFile -Value $Line -Encoding UTF8
    }
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
$Script:AutoYes = $false

function Initialize-AutoYes {
    param(
        [switch]$AutoYes,
        [switch]$NoPrompt
    )
    $envAutoYes = ($env:QUICKSTART_AUTO_YES -eq '1') -or ($env:AUTO_YES -eq '1')
    # -AutoYes、环境变量或脚本级 $Script:AutoYes 已启用时，直接进入自动确认
    if ($AutoYes -or $Script:AutoYes -or $envAutoYes) {
        $Script:AutoYes = $true
        Write-Note "自动确认模式已启用（仅自动确认默认推荐项 Y/n，跳过默认否项 y/N）/ Auto-yes mode enabled (Y/n only, skips y/N)"
        return
    }
    if ($NoPrompt -or $env:QUICKSTART_NO_AUTO_YES_PROMPT -eq '1') {
        return
    }
    if (Confirm-YesNo -Prompt "是否启用自动确认（自动确认默认推荐项 Y/n，跳过默认否项 y/N）？(Y/n) / Enable auto-confirm (Y/n items only, skip y/N)? (Y/n)" -DefaultYes) {
        $Script:AutoYes = $true
        Write-Note "自动确认模式已启用（仅自动确认默认推荐项 Y/n，跳过默认否项 y/N）/ Auto-yes mode enabled (Y/n only, skips y/N)"
    }
}

function Confirm-Install {
    param(
        [string]$Prompt,
        [switch]$DefaultYes
    )
    if ($Script:AutoYes) {
        if ($DefaultYes) { return "Y" }
        return "N"
    }
    return Read-Host $Prompt
}

function Confirm-YesNo {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [switch]$DefaultYes
    )
    $answer = Confirm-Install -Prompt $Prompt -DefaultYes:$DefaultYes
    $trimmed = if ($null -eq $answer) { '' } else { $answer.Trim() }
    if ([string]::IsNullOrEmpty($trimmed)) {
        return [bool]$DefaultYes
    }
    if ($DefaultYes) {
        return ($trimmed -notmatch '^[Nn]')
    }
    return ($trimmed -match '^[Yy]')
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
    return $choice.Trim()
}

# ===== Scoop 已安装检测（缓存结果，避免重复调用 scoop list）=====
$Script:ScoopInstalledCache = $null

function Get-ScoopInstalled {
    if ($null -eq $Script:ScoopInstalledCache) {
        if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
            $Script:ScoopInstalledCache = @()
        }
        else {
            $Script:ScoopInstalledCache = @(Invoke-NativeQuiet -FilePath 'scoop' -Arguments @('list'))
        }
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

function Test-ScoopBucket {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { return $false }
    $buckets = @(Invoke-NativeQuiet -FilePath 'scoop' -Arguments @('bucket', 'list'))
    return [bool](@($buckets.Name) -contains $Name)
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

    $prompt = if ($DefaultYes) {
        "是否安装 $Desc？(Y/n) / Install $Desc? (Y/n)"
    }
    else {
        "是否安装 $Desc？(y/N) / Install $Desc? (y/N)"
    }
    if (-not (Confirm-YesNo -Prompt $prompt -DefaultYes:$DefaultYes)) { return }

    if (Test-DryRun) { Write-Note ("[dry-run] 将安装 $Name / would install $Name"); return }
    $scoopArgs = if ($AsGlobal) { @('install', $Name, '--global') } else { @('install', $Name) }
    $global:LASTEXITCODE = 0
    & scoop @scoopArgs
    $installExit = $LASTEXITCODE
    Reset-ScoopCache

    if ($installExit -eq 0) {
        if ($AsGlobal) {
            Write-Ok "$Name 安装完成（全局） / $Name installation completed (global)"
        }
        else {
            Write-Ok "$Name 安装完成 / $Name installation completed"
        }
        if ($PostNote) { foreach ($line in $PostNote) { Write-Note $line } }
    }
    else {
        if ($AsGlobal) {
            Write-Err "$Name 安装失败（全局，退出码 $installExit）/ $Name installation failed (global, exit $installExit)"
            Add-Failure "$Name (global)"
        }
        else {
            Write-Err "$Name 安装失败（退出码 $installExit）/ $Name installation failed (exit $installExit)"
            Add-Failure $Name
        }
    }
}

function Install-ScoopPackages {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Batch install helper; plural noun is intentional')]
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Packages
    )
    foreach ($entry in $Packages.GetEnumerator()) {
        $info = $entry.Value
        $desc = if ([string]::IsNullOrWhiteSpace([string]$info.Desc)) { $entry.Key } else { $info.Desc }
        # 未显式指定 Default 时默认推荐安装（$true）；只有显式写 $false 才表示可选
        $defaultYes = if ($info.ContainsKey('Default')) { [bool]$info.Default } else { $true }
        Install-ScoopPackage -Name $entry.Key -Desc $desc -AsGlobal:([bool]$info.Global) -DefaultYes:$defaultYes -PostNote $info.PostNote -AlreadyNote $info.AlreadyNote
    }
}

# ===== winget 已安装检测 =====
function Test-WingetInstalled {
    param([Parameter(Mandatory = $true)][string]$Id)
    try {
        $null = Invoke-NativeQuiet -FilePath 'winget' -Arguments @('list', '--id', $Id, '--exact', '--source', 'winget', '--accept-source-agreements', '--disable-interactivity')
        return ($LASTEXITCODE -eq 0)
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
    $wingetArgs = @('install', '--id', $Id) + @($InstallArgs) + @('--source', 'winget', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity')
    if (Test-DryRun) {
        Write-Note "[dry-run] 将执行 / would run: winget $($wingetArgs -join ' ')"
        $global:LASTEXITCODE = 0
        return
    }
    $global:LASTEXITCODE = 0
    & winget @wingetArgs
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

    if (-not $Force) {
        $prompt = if ($DefaultYes) {
            "是否安装 $Desc？(Y/n) / Install $Desc? (Y/n)"
        }
        else {
            "是否安装 $Desc？(y/N) / Install $Desc? (y/N)"
        }
        if (-not (Confirm-YesNo -Prompt $prompt -DefaultYes:$DefaultYes)) { return }
    }

    if (Test-DryRun) { Write-Note ("[dry-run] 将安装 $Id (winget) / would install $Id"); return }
    Write-Step "通过 winget 安装 $Desc ($Id) / Installing $Desc via winget"
    Invoke-WingetInstall -Id $Id -InstallArgs $InstallArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "$Id 安装完成 / $Id installation completed"
    }
    elseif ($LASTEXITCODE -eq 3010) {
        Write-Warn "$Id 安装完成，但需要重启系统以生效（退出码 3010）/ $Id installed, reboot required (exit 3010)"
    }
    else {
        Write-Err "$Id 安装失败（退出码 $LASTEXITCODE）/ $Id installation failed (exit $LASTEXITCODE)"
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
        $desc = if ([string]::IsNullOrWhiteSpace([string]$info.Desc)) { $entry.Key } else { $info.Desc }
        # 未显式指定 Default 时默认推荐安装（$true）；只有显式写 $false 才表示可选
        $defaultYes = if ($info.ContainsKey('Default')) { [bool]$info.Default } else { $true }
        if ($info.InstallArgs) {
            Install-WingetApp -Id $entry.Key -Desc $desc -InstallArgs $info.InstallArgs -Force:$Force -DefaultYes:$defaultYes
        }
        else {
            Install-WingetApp -Id $entry.Key -Desc $desc -Force:$Force -DefaultYes:$defaultYes
        }
    }
}
