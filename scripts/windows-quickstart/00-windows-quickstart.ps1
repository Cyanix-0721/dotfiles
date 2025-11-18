#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Windows 快速配置主菜单 / Windows Quick Setup Main Menu

.DESCRIPTION
    提供交互式菜单，用于快速配置 Windows 系统环境
    Uses Scoop package manager for application installation
#>

$ErrorActionPreference = "Stop"
$Script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-Menu {
    Clear-Host
    Write-Host "=== Windows 快速配置菜单 / Windows Quick Setup Menu ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. 全部运行 / Run All (Complete Setup)" -ForegroundColor Green
    Write-Host "2. 系统基础环境配置 / System Foundation Setup" -ForegroundColor Yellow
    Write-Host "3. 开发工具安装 / Development Tools Installation" -ForegroundColor Yellow
    Write-Host "4. 系统工具安装 / System Tools Installation" -ForegroundColor Yellow
    Write-Host "5. 必备软件包安装 / Essential Applications Installation" -ForegroundColor Yellow
    Write-Host "0. 退出 / Exit" -ForegroundColor Red
    Write-Host ""
}

function Invoke-Script {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptNumber
    )
    
    $scriptName = ""
    
    switch ($ScriptNumber) {
        "0" { 
            Write-Host "再见! / Goodbye!" -ForegroundColor Cyan
            exit 0
        }
        "1" {
            Write-Host "开始完整配置… / Starting complete setup…" -ForegroundColor Green
            $scripts = Get-ChildItem -Path $Script:ScriptDir -Filter "0[1-5]-*.ps1" | Sort-Object Name
            foreach ($script in $scripts) {
                Write-Host "`n执行: $($script.Name) / Executing: $($script.Name)" -ForegroundColor Cyan
                & $script.FullName
                if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
                    Write-Warning "脚本 $($script.Name) 执行失败 / Script $($script.Name) execution failed"
                    Read-Host "按回车键继续… / Press Enter to continue…"
                }
            }
            Write-Host "`n✓ 所有配置完成! / All configurations completed!" -ForegroundColor Green
            return $true
        }
        "2" { $scriptName = "01-system-foundation.ps1" }
        "3" { $scriptName = "02-development-tools.ps1" }
        "4" { $scriptName = "03-system-tools.ps1" }
        "5" { $scriptName = "04-essential-packages.ps1" }
        default {
            Write-Warning "无效选项 / Invalid option"
            return $false
        }
    }
    
    if ($scriptName) {
        $scriptPath = Join-Path $Script:ScriptDir $scriptName
        if (Test-Path $scriptPath) {
            Write-Host "执行: $scriptName / Executing: $scriptName" -ForegroundColor Cyan
            & $scriptPath
            return $?
        }
        else {
            Write-Error "错误: 脚本 $scriptName 不存在 / Error: Script $scriptName does not exist"
            return $false
        }
    }
    
    return $true
}

# 主循环
while ($true) {
    Show-Menu
    $choice = Read-Host "请选择操作 / Please select an option [0-5]"
    
    $success = Invoke-Script -ScriptNumber $choice
    
    if ($choice -ne "0") {
        Write-Host ""
        if ($success) {
            Write-Host "✓ 操作成功 / Operation successful" -ForegroundColor Green
        }
        else {
            Write-Warning "执行失败，请检查错误信息 / Execution failed, please check error messages"
        }
        Read-Host "按回车键返回主菜单… / Press Enter to return to main menu…"
    }
}
