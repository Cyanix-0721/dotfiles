#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Windows 快速配置主菜单 / Windows Quick Setup Main Menu

.DESCRIPTION
    提供交互式菜单，用于快速配置 Windows 系统环境
    Uses Scoop package manager for application installation
#>

param(
    [switch]$DryRun,
    [switch]$AutoYes
)

$ErrorActionPreference = "Stop"
$Script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 加载公共函数
. "$Script:ScriptDir/00-common.ps1"

$prevDryRun = $env:QUICKSTART_DRY_RUN
$prevLogFile = $env:QUICKSTART_LOG_FILE
$prevAutoYes = $env:QUICKSTART_AUTO_YES
$prevNoPrompt = $env:QUICKSTART_NO_AUTO_YES_PROMPT

$Script:IsDryRun = Set-DryRun -DryRun:$DryRun
if ($Script:IsDryRun) { $env:QUICKSTART_DRY_RUN = '1' }
Start-Log
if ($Script:LogFile) { $env:QUICKSTART_LOG_FILE = $Script:LogFile }

$Script:MainAutoYes = [bool]($AutoYes -or $env:QUICKSTART_AUTO_YES -eq '1' -or $env:AUTO_YES -eq '1')
if ($Script:MainAutoYes) { $env:QUICKSTART_AUTO_YES = '1' }
$Script:ShouldExit = $false

# ===== 菜单单一真源 / Single source of truth =====
# 菜单显示、选项分派与 RunAll 都读取本表，新增/调整项只改这里
$Script:MenuItems = @(
    [pscustomobject]@{ Key = '1'; Color = 'Green'; Title = '全部运行 / Run All (Complete Setup)'; Action = 'RunAll' }
    [pscustomobject]@{ Key = '2'; Color = 'Yellow'; Title = '系统基础环境配置 / System Foundation Setup'; Script = '01-system-foundation.ps1' }
    [pscustomobject]@{ Key = '3'; Color = 'Yellow'; Title = '开发工具安装 / Development Tools Installation'; Script = '02-development-tools.ps1' }
    [pscustomobject]@{ Key = '4'; Color = 'Yellow'; Title = '系统工具安装 / System Tools Installation'; Script = '03-system-tools.ps1' }
    [pscustomobject]@{ Key = '5'; Color = 'Yellow'; Title = '必备软件包安装 / Essential Applications Installation'; Script = '04-essential-packages.ps1' }
    [pscustomobject]@{ Key = '0'; Color = 'Red'; Title = '退出 / Exit'; Action = 'Exit' }
)

function Show-Menu {
    Clear-Host
    Write-Header "Windows 快速配置菜单 / Windows Quick Setup Menu"
    foreach ($item in $Script:MenuItems) {
        Write-Host (" [{0}] {1}" -f $item.Key, $item.Title) -ForegroundColor $item.Color
    }
    Write-Host ""
}

function Invoke-Script {
    param (
        [AllowEmptyString()]
        [string]$ScriptNumber = ''
    )

    $normalized = if ($null -eq $ScriptNumber) { '' } else { $ScriptNumber.Trim() }
    if ([string]::IsNullOrEmpty($normalized)) {
        Write-Warn "无效选项 / Invalid option"
        return $false
    }

    $item = $Script:MenuItems | Where-Object { $_.Key -eq $normalized } | Select-Object -First 1
    if (-not $item) {
        Write-Warn "无效选项 / Invalid option"
        return $false
    }

    switch ($item.Action) {
        'Exit' {
            Write-Ok "再见! / Goodbye!"
            $Script:ShouldExit = $true
            return $true
        }
        'RunAll' {
            $runAutoYes = $Script:MainAutoYes
            if (-not $runAutoYes) {
                $runAutoYes = Confirm-YesNo -Prompt "是否启用自动确认（自动确认默认推荐项 Y/n，跳过默认否项 y/N）？(Y/n) / Enable auto-confirm (Y/n items only, skip y/N)? (Y/n)" -DefaultYes
                if ($runAutoYes) {
                    Write-Note "自动确认模式已启用（仅自动确认默认推荐项 Y/n，跳过默认否项 y/N）/ Auto-yes mode enabled (Y/n only, skips y/N)"
                }
            }

            Write-Step "开始完整配置 / Starting complete setup"
            $menuScripts = @($Script:MenuItems | Where-Object { $_.PSObject.Properties['Script'] -and $_.Script })
            $hadFailure = $false
            foreach ($menuItem in $menuScripts) {
                $scriptPath = Join-Path $Script:ScriptDir $menuItem.Script
                if (-not (Test-Path -LiteralPath $scriptPath)) {
                    Write-Err "错误: 脚本 $($menuItem.Script) 不存在 / Error: Script $($menuItem.Script) does not exist"
                    $hadFailure = $true
                    continue
                }
                Write-Step "执行 $($menuItem.Script) / Executing $($menuItem.Script)"
                try {
                    $global:LASTEXITCODE = 0
                    & $scriptPath -AutoYes:$runAutoYes -DryRun:$Script:IsDryRun -NoAutoYesPrompt:(-not $runAutoYes)
                    if ($LASTEXITCODE -ne 0) {
                        $hadFailure = $true
                        Write-Warn "脚本 $($menuItem.Script) 返回非零退出码 ($LASTEXITCODE) / Script $($menuItem.Script) exited with code $LASTEXITCODE"
                        if (-not $runAutoYes) {
                            Read-Host "按回车键继续… / Press Enter to continue…" | Out-Null
                        }
                    }
                }
                catch {
                    $hadFailure = $true
                    Write-Warn "脚本 $($menuItem.Script) 执行失败 / Script $($menuItem.Script) execution failed: $($_.Exception.Message)"
                    if (-not $runAutoYes) {
                        Read-Host "按回车键继续… / Press Enter to continue…" | Out-Null
                    }
                }
            }
            if ($hadFailure) {
                Write-Warn "完整配置已完成，但部分脚本执行失败 / Complete setup finished with failures"
                return $false
            }
            Write-Ok "所有配置完成! / All configurations completed!"
            return $true
        }
    }

    if ($item.Script) {
        $scriptPath = Join-Path $Script:ScriptDir $item.Script
        if (Test-Path -LiteralPath $scriptPath) {
            Write-Step "执行 $($item.Script) / Executing $($item.Script)"
            try {
                $global:LASTEXITCODE = 0
                & $scriptPath -AutoYes:$Script:MainAutoYes -DryRun:$Script:IsDryRun
                if ($LASTEXITCODE -ne 0) {
                    Write-Err "脚本 $($item.Script) 返回非零退出码 ($LASTEXITCODE) / Script $($item.Script) exited with code $LASTEXITCODE"
                    return $false
                }
                return $true
            }
            catch {
                Write-Err "脚本 $($item.Script) 执行失败 / Script $($item.Script) execution failed: $($_.Exception.Message)"
                return $false
            }
        }
        else {
            Write-Err "错误: 脚本 $($item.Script) 不存在 / Error: Script $($item.Script) does not exist"
            return $false
        }
    }

    return $true
}

# 主循环（通过 try/finally 确保环境变量不泄漏到父会话）
try {
    $maxKey = ($Script:MenuItems | ForEach-Object { [int]$_.Key } | Measure-Object -Maximum).Maximum
    while (-not $Script:ShouldExit) {
        Show-Menu
        $choice = Read-Host "请选择操作 / Please select an option [0-$maxKey]"
        if ($null -eq $choice) {
            break
        }

        $success = Invoke-Script -ScriptNumber $choice
        if ($Script:ShouldExit) {
            break
        }

        Write-Host ""
        if ($success) {
            Write-Ok "操作成功 / Operation successful"
        }
        else {
            Write-Warn "执行失败，请检查错误信息 / Execution failed, please check error messages"
        }
        if (-not $Script:MainAutoYes) {
            Read-Host "按回车键返回主菜单… / Press Enter to return to main menu…" | Out-Null
        }
    }
}
finally {
    $env:QUICKSTART_DRY_RUN = $prevDryRun
    $env:QUICKSTART_LOG_FILE = $prevLogFile
    $env:QUICKSTART_AUTO_YES = $prevAutoYes
    $env:QUICKSTART_NO_AUTO_YES_PROMPT = $prevNoPrompt
}
