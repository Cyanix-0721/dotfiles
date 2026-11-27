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
    [switch]$DryRun,
    [switch]$NoAutoYesPrompt
)

$ErrorActionPreference = "Stop"

# 加载公共函数
. "$PSScriptRoot/00-common.ps1"
Set-DryRun -DryRun:$DryRun | Out-Null

# 初始化自动确认模式
Initialize-AutoYes -AutoYes:$AutoYes -NoPrompt:$NoAutoYesPrompt

Write-Header "系统基础环境配置 / System Foundation Setup"

# 更新 winget 源
Write-Step "更新 winget 源 / Updating winget sources"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过更新 / winget not installed, skipping source update"

    $openChoice = Read-Choice -Prompt "是否打开安装页面以安装 winget？1) Microsoft Store（推荐） 2) GitHub Releases（下载）；输入 1/2，回车跳过 / Open install page? 1) MS Store (recommended) 2) GitHub Releases (download); enter to skip" -Default ""
    switch ($openChoice) {
        '1' {
            if (Test-DryRun) {
                Write-Note "[dry-run] 将打开 Microsoft Store 页面 / would open Microsoft Store: ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
            }
            else {
                try {
                    Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
                    Write-Ok "已打开 Microsoft Store 页面 / Opened Microsoft Store"
                }
                catch {
                    Write-Err "无法打开 Microsoft Store 页面，请手动访问：ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
                }
            }
        }
        '2' {
            if (Test-DryRun) {
                Write-Note "[dry-run] 将打开 GitHub Releases 页面 / would open GitHub Releases: https://github.com/microsoft/winget-cli/releases"
            }
            else {
                try {
                    Start-Process "https://github.com/microsoft/winget-cli/releases"
                    Write-Ok "已打开 GitHub Releases 页面 / Opened GitHub Releases"
                }
                catch {
                    Write-Err "无法打开 GitHub Releases 页面，请手动访问：https://github.com/microsoft/winget-cli/releases"
                }
            }
        }
        default {
            Write-Note "跳过 winget 安装页面 / Skipping winget install page"
        }
    }
}
else {
    if (Test-DryRun) {
        Write-Note "[dry-run] 将执行 / would run: winget source update --accept-source-agreements --disable-interactivity"
    }
    else {
        try {
            $global:LASTEXITCODE = 0
            & winget @('source', 'update', '--accept-source-agreements', '--disable-interactivity')
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "更新 winget 源返回非零（退出码 $LASTEXITCODE，非致命），继续执行后续步骤 / Updating winget sources returned exit $LASTEXITCODE (non-fatal), continuing"
            }
        }
        catch {
            Write-Warn "更新 winget 源失败（非致命），继续执行后续步骤 / Updating winget sources failed (non-fatal), continuing"
        }
    }
}

# 检查并安装 Scoop
Write-Step "检查 Scoop 安装状态 / Checking Scoop installation"
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    if (Test-DryRun) {
        $adminHint = if (Test-IsAdministrator) { ' -RunAsAdmin' } else { '' }
        Write-Note "[dry-run] 将设置 CurrentUser 执行策略并下载执行 Scoop 安装脚本$adminHint / would set ExecutionPolicy and install Scoop$adminHint"
    }
    else {
        Write-Note "Scoop 未安装，开始安装… / Scoop not installed, starting installation…"
        $scoopInstallScript = Join-Path ([System.IO.Path]::GetTempPath()) ("scoop-install-{0}.ps1" -f $PID)
        try {
            # 设置执行策略 & TLS 1.2（供 PowerShell 5.1）
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

            # 下载官方安装脚本到临时文件并执行（管理员身份需传 -RunAsAdmin，且避免 Invoke-Expression）
            Invoke-RestMethod -Uri 'https://get.scoop.sh' -OutFile $scoopInstallScript
            if (Test-IsAdministrator) {
                & $scoopInstallScript -RunAsAdmin
            }
            else {
                & $scoopInstallScript
            }
            if (Get-Command scoop -ErrorAction SilentlyContinue) {
                Write-Ok "Scoop 安装完成 / Scoop installation completed"
            }
            else {
                Write-Err "Scoop 安装脚本执行完成但未检测到 scoop 命令 / Scoop installer finished but 'scoop' was not found"
                Add-Failure "scoop"
            }
        }
        catch {
            Write-Err "Scoop 安装失败 / Scoop installation failed: $($_.Exception.Message)"
            Add-Failure "scoop"
        }
        finally {
            if (Test-Path -LiteralPath $scoopInstallScript) {
                Remove-Item -LiteralPath $scoopInstallScript -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
else {
    Write-Ok "Scoop 已安装 / Scoop is already installed"
}

$hasScoop = [bool](Get-Command scoop -ErrorAction SilentlyContinue)

# 更新 Scoop
Write-Step "更新 Scoop / Updating Scoop"
if (Test-DryRun) {
    Write-Note "[dry-run] 将执行 / would run: scoop update"
}
elseif (-not $hasScoop) {
    Write-Warn "Scoop 不可用，跳过更新 / Scoop unavailable, skipping update"
}
else {
    $global:LASTEXITCODE = 0
    & scoop @('update')
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Scoop 更新完成 / Scoop updated"
    }
    else {
        Write-Err "Scoop 更新失败（退出码 $LASTEXITCODE）/ Scoop update failed (exit $LASTEXITCODE)"
        Add-Failure "scoop update"
    }
}

# 确保 PowerShell 7 已安装（可选，推荐；脚本本身兼容 PowerShell 5.1）
# Ensure PowerShell 7 is installed via Scoop (optional, recommended; scripts stay 5.1-compatible)
Write-Step "检查 PowerShell 7 / Checking PowerShell 7"
if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    Write-Ok "PowerShell 7 已安装 / PowerShell 7 is already installed"
}
else {
    if (Confirm-YesNo -Prompt "未检测到 PowerShell 7，是否用 scoop 安装？(Y/n) / PowerShell 7 not found, install via scoop? (Y/n)" -DefaultYes) {
        if (Test-DryRun) {
            Write-Note "[dry-run] 将安装 pwsh (scoop) / would install pwsh via scoop"
        }
        elseif (-not $hasScoop) {
            Write-Warn "Scoop 不可用，跳过 PowerShell 7 安装 / Scoop unavailable, skipping PowerShell 7 installation"
            Add-Failure "pwsh"
        }
        else {
            $global:LASTEXITCODE = 0
            & scoop @('install', 'pwsh')
            $pwshExit = $LASTEXITCODE
            Reset-ScoopCache
            if ($pwshExit -eq 0) {
                Write-Ok "PowerShell 7 安装完成，请重新打开终端以使用 pwsh / PowerShell 7 installed; reopen terminal to use pwsh"
            }
            else {
                Write-Err "PowerShell 7 安装失败（退出码 $pwshExit）/ Installing PowerShell 7 failed (exit $pwshExit)"
                Add-Failure "pwsh"
            }
        }
    }
    else {
        Write-Note "跳过 PowerShell 7 安装 / Skipping PowerShell 7 installation"
    }
}

# 清理 Scoop 旧版本（可选，默认否；仅回车=不清；-AutoYes 跳过）
Write-Step "清理 Scoop 旧版本 / Clean up old Scoop versions"
if (Confirm-YesNo -Prompt "是否自动清除 Scoop 旧版本？(y/N) / Automatically remove old Scoop versions? (y/N)") {
    if (Test-DryRun) {
        Write-Note "[dry-run] 将执行 / would run: scoop cleanup --all"
    }
    elseif (-not $hasScoop) {
        Write-Warn "Scoop 不可用，跳过旧版本清理 / Scoop unavailable, skipping cleanup"
    }
    else {
        $global:LASTEXITCODE = 0
        & scoop @('cleanup', '--all')
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Scoop 旧版本清理完成 / Old Scoop versions cleaned up"
        }
        else {
            Write-Err "Scoop 旧版本清理失败（退出码 $LASTEXITCODE）/ Scoop cleanup failed (exit $LASTEXITCODE)"
            Add-Failure "scoop cleanup"
        }
    }
}
else {
    Write-Note "跳过旧版本清理 / Skipping old version cleanup"
}

# 安装 Git（Scoop 依赖）
Write-Step "安装 Git / Installing Git"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    if (Test-DryRun) {
        Write-Note "[dry-run] 将安装 git (scoop) / would install git via scoop"
    }
    elseif (-not $hasScoop) {
        Write-Warn "Scoop 不可用，跳过 Git 安装 / Scoop unavailable, skipping Git installation"
        Add-Failure "git"
    }
    else {
        $global:LASTEXITCODE = 0
        & scoop @('install', 'git')
        $gitExit = $LASTEXITCODE
        Reset-ScoopCache
        if ($gitExit -eq 0) {
            Write-Ok "Git 安装完成 / Git installation completed"
        }
        else {
            Write-Err "Git 安装失败（退出码 $gitExit）/ Git installation failed (exit $gitExit)"
            Add-Failure "git"
        }
    }
}
else {
    Write-Ok "Git 已安装 / Git is already installed"
}

# 安装 Aria2（加速下载）
Write-Step "配置 Aria2 下载加速 / Configuring Aria2 for faster downloads"
if (-not (Test-ScoopInstalled "aria2")) {
    if (Test-DryRun) {
        Write-Note "[dry-run] 将安装 aria2 并配置 scoop aria2 选项 / would install aria2 and configure scoop aria2"
    }
    elseif (-not $hasScoop) {
        Write-Warn "Scoop 不可用，跳过 Aria2 安装 / Scoop unavailable, skipping Aria2 installation"
        Add-Failure "aria2"
    }
    else {
        $global:LASTEXITCODE = 0
        & scoop @('install', 'aria2')
        $ariaExit = $LASTEXITCODE
        Reset-ScoopCache
        if ($ariaExit -eq 0) {
            $cfgOk = $true
            $global:LASTEXITCODE = 0
            & scoop @('config', 'aria2-enabled', 'true')
            if ($LASTEXITCODE -ne 0) { $cfgOk = $false }
            $global:LASTEXITCODE = 0
            & scoop @('config', 'aria2-warning-enabled', 'false')
            if ($LASTEXITCODE -ne 0) { $cfgOk = $false }

            if ($cfgOk) {
                Write-Ok "Aria2 配置完成 / Aria2 configuration completed"
            }
            else {
                Write-Err "Aria2 已安装但 Scoop 配置失败 / Aria2 installed but scoop config failed"
                Add-Failure "aria2 config"
            }
        }
        else {
            Write-Err "Aria2 安装失败（退出码 $ariaExit），跳过后续配置 / Aria2 installation failed (exit $ariaExit), skipping config"
            Add-Failure "aria2"
        }
    }
}
else {
    Write-Ok "Aria2 已安装 / Aria2 is already installed"
}

# 添加 Scoop 常用 buckets
Write-Step "添加 Scoop buckets / Adding Scoop buckets"

$buckets = @("extras", "versions", "nerd-fonts", "sysinternals", "nirsoft")
foreach ($bucketName in $buckets) {
    if ($hasScoop -and (Test-ScoopBucket -Name $bucketName)) {
        Write-Ok "Bucket '$bucketName' 已添加 / Bucket '$bucketName' already added"
    }
    elseif (Test-DryRun) {
        Write-Note "[dry-run] 将添加 bucket: $bucketName / would add bucket: $bucketName"
    }
    elseif (-not $hasScoop) {
        Write-Warn "Scoop 不可用，跳过添加 bucket '$bucketName' / Scoop unavailable, skipping bucket '$bucketName'"
        Add-Failure "scoop bucket $bucketName"
    }
    else {
        Write-Step "添加 bucket: $bucketName / Adding bucket: $bucketName"
        $global:LASTEXITCODE = 0
        & scoop @('bucket', 'add', $bucketName)
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Bucket '$bucketName' 添加成功 / Bucket '$bucketName' added successfully"
        }
        else {
            Write-Err "Bucket '$bucketName' 添加失败（退出码 $LASTEXITCODE）/ Failed to add bucket '$bucketName' (exit $LASTEXITCODE)"
            Add-Failure "scoop bucket $bucketName"
        }
    }
}

# 安装 gsudo（类似 Linux 的 sudo；必装）
Write-Step "安装 gsudo / Installing gsudo"
if (-not (Get-Command gsudo -ErrorAction SilentlyContinue)) {
    if (Test-DryRun) {
        Write-Note "[dry-run] 将安装 gsudo (scoop) / would install gsudo via scoop"
    }
    elseif (-not $hasScoop) {
        Write-Warn "Scoop 不可用，跳过 gsudo 安装 / Scoop unavailable, skipping gsudo installation"
        Add-Failure "gsudo"
    }
    else {
        $global:LASTEXITCODE = 0
        & scoop @('install', 'gsudo')
        $gsudoExit = $LASTEXITCODE
        Reset-ScoopCache
        if ($gsudoExit -eq 0) {
            Write-Ok "gsudo 安装完成 / gsudo installation completed"
        }
        else {
            Write-Err "gsudo 安装失败（退出码 $gsudoExit）/ gsudo installation failed (exit $gsudoExit)"
            Add-Failure "gsudo"
        }
    }
}
else {
    Write-Ok "gsudo 已安装 / gsudo is already installed"
}

# PowerShell 组件（pwsh 装好后一次性可选安装；默认否，-AutoYes 跳过）
# PowerShell components (one-time optional install after pwsh; default no, skipped in -AutoYes)
Write-Header "PowerShell 组件 / PowerShell Components"
if (Confirm-YesNo -Prompt "是否安装常用 PowerShell 组件（PSScriptAnalyzer / PSReadLine / PSWindowsUpdate / ImportExcel / NTFSSecurity / Pester）？(y/N) / Install PowerShell components? (y/N)") {
    # PS 模块（缺则装；TLS1.2 供 PowerShell 5.1）
    if (-not (Test-DryRun)) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        if ($PSVersionTable.PSVersion.Major -lt 6 -and -not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Warn "NuGet PackageProvider 预装失败（继续尝试安装模块）/ Failed to bootstrap NuGet provider: $($_.Exception.Message)"
            }
        }
    }
    # 模块 → 最低版本（$null 表示不限）。Pester 系统自带 3.4.0，需强制 >=5，避免被旧版占位跳过。
    $psModules = [ordered]@{
        'PSScriptAnalyzer' = $null
        'PSReadLine'       = $null
        'PSWindowsUpdate'  = $null
        'ImportExcel'      = $null
        'NTFSSecurity'     = $null
        'Pester'           = [version]'5.0.0'
    }
    foreach ($moduleName in $psModules.Keys) {
        $minVersion = $psModules[$moduleName]
        $available = Get-Module -ListAvailable -Name $moduleName
        $satisfied = $false
        if ($available) {
            $satisfied = if ($null -eq $minVersion) { $true } else { [bool]($available | Where-Object { $_.Version -ge $minVersion }) }
        }
        if ($satisfied) {
            if ($null -eq $minVersion) { Write-Ok "$moduleName 已安装 / $moduleName already installed" }
            else { Write-Ok "$moduleName（>= $minVersion）已安装 / $moduleName (>= $minVersion) already installed" }
            continue
        }
        if (Test-DryRun) {
            $verHint = if ($null -ne $minVersion) { " (>= $minVersion)" } else { "" }
            Write-Note "[dry-run] 将安装 PowerShell 模块 $moduleName$verHint / would install PS module $moduleName$verHint"
            continue
        }
        try {
            if ($null -eq $minVersion) {
                Install-Module -Name $moduleName -Scope CurrentUser -Force -ErrorAction Stop
            }
            else {
                Install-Module -Name $moduleName -MinimumVersion $minVersion -Scope CurrentUser -Force -ErrorAction Stop
            }
            Write-Ok "$moduleName 安装完成 / $moduleName installation completed"
        }
        catch {
            Write-Err "$moduleName 安装失败 / Installing $moduleName failed: $($_.Exception.Message)"
            Add-Failure "$moduleName (PSModule)"
        }
    }
}
else {
    Write-Note "跳过 PowerShell 组件安装 / Skipping PowerShell components installation"
}

# 安装 Visual C++ 运行库
Write-Header "Visual C++ 运行库 / Visual C++ Redistributables"

if (Confirm-YesNo -Prompt "是否安装 Visual C++ 2005-2022 运行库？(Y/n) / Install Visual C++ 2005-2022 Redistributables? (Y/n)" -DefaultYes) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warn "winget 未安装，跳过 Visual C++ 运行库安装 / winget not installed, skipping Visual C++ installation"
    }
    else {
        Write-Step "正在安装 Visual C++ 运行库... / Installing Visual C++ Redistributables..."
        $failuresBefore = Get-FailureCount
        Install-WingetApps (Get-PackageSection 'foundation.vcredist') -Force
        if (-not (Test-DryRun) -and (Get-FailureCount) -eq $failuresBefore) {
            Write-Ok "Visual C++ 运行库安装完成 / Visual C++ Redistributables installation completed"
        }
    }
}

# 安装 Microsoft Edge WebView2 运行时
Write-Header "Microsoft Edge WebView2 运行时 / WebView2 Runtime"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过 WebView2 安装 / winget not installed, skipping WebView2 installation"
}
else {
    Install-WingetApps (Get-PackageSection 'foundation.webview2')
}

# 安装 Chezmoi 配置管理工具
Write-Header "Chezmoi 配置管理工具 / Chezmoi Configuration Management Tool"
if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    if (Confirm-YesNo -Prompt "是否安装 Chezmoi？(Y/n) / Install Chezmoi? (Y/n)" -DefaultYes) {
        $chezmoiInstalled = $false
        if (Test-DryRun) {
            Write-Note "[dry-run] 将安装 chezmoi (scoop) / would install chezmoi via scoop"
            $chezmoiInstalled = $true
        }
        elseif (-not $hasScoop) {
            Write-Warn "Scoop 不可用，跳过 Chezmoi 安装 / Scoop unavailable, skipping Chezmoi installation"
            Add-Failure "chezmoi"
        }
        else {
            $global:LASTEXITCODE = 0
            & scoop @('install', 'chezmoi')
            $chezmoiExit = $LASTEXITCODE
            Reset-ScoopCache
            if ($chezmoiExit -eq 0) {
                Write-Ok "Chezmoi 安装完成 / Chezmoi installation completed"
                $chezmoiInstalled = $true
            }
            else {
                Write-Err "Chezmoi 安装失败（退出码 $chezmoiExit）/ Chezmoi installation failed (exit $chezmoiExit)"
                Add-Failure "chezmoi"
            }
        }

        if ($chezmoiInstalled) {
            if ($Script:AutoYes) {
                Write-Note "自动确认模式下跳过交互式 chezmoi init --apply；请稍后手动运行: chezmoi init https://github.com/Cyanix-0721/dotfiles.git --apply / Skipping interactive chezmoi init --apply in auto-yes mode"
            }
            elseif (Confirm-YesNo -Prompt "是否初始化 dotfiles 配置？(Y/n) / Initialize dotfiles configuration? (Y/n)" -DefaultYes) {
                if (Test-DryRun) {
                    Write-Note "[dry-run] 将执行 / would run: chezmoi init https://github.com/Cyanix-0721/dotfiles.git --apply"
                }
                else {
                    $global:LASTEXITCODE = 0
                    & chezmoi @('init', 'https://github.com/Cyanix-0721/dotfiles.git', '--apply')
                    if ($LASTEXITCODE -eq 0) {
                        Write-Ok "dotfiles 配置初始化完成 / dotfiles configuration initialized"
                    }
                    else {
                        Write-Err "dotfiles 配置初始化失败（退出码 $LASTEXITCODE）/ dotfiles configuration initialization failed (exit $LASTEXITCODE)"
                        Add-Failure "chezmoi init"
                    }
                }
            }
        }
    }
}
else {
    Write-Ok "Chezmoi 已安装 / Chezmoi is already installed"
}

Write-Header "系统基础环境配置完成 / System foundation setup completed"
if (-not (Test-DryRun) -and (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Note "当前已安装的应用列表 / Currently installed applications:"
    & scoop @('list')
}

Write-FailureSummary
if ((Get-FailureCount) -gt 0) { exit 1 }
