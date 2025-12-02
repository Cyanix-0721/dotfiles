#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    系统基础环境配置 / System Foundation Setup

.DESCRIPTION
    安装和配置 Scoop 包管理器及基础开发工具
    Install and configure Scoop package manager and basic development tools
#>

$ErrorActionPreference = "Stop"

Write-Host "=== 系统基础环境配置 / System Foundation Setup ===" -ForegroundColor Cyan

# 更新 winget 源
Write-Host "`n更新 winget 源… / Updating winget sources…" -ForegroundColor Yellow
winget source update

# 检查是否已安装 PowerShell 7
Write-Host "`n检查 PowerShell 7… / Checking PowerShell 7…" -ForegroundColor Yellow
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    Write-Host "安装 PowerShell 7… / Installing PowerShell 7…" -ForegroundColor Yellow
    winget install --id Microsoft.PowerShell --exact --source winget
    Write-Host "✓ PowerShell 7 安装完成，请重新启动终端并使用 pwsh 运行本脚本 / PowerShell 7 installed, please restart terminal and rerun this script with pwsh" -ForegroundColor Green
    exit
}
else {
    Write-Host "✓ PowerShell 7 已安装 / PowerShell 7 is already installed" -ForegroundColor Green
}

# 安装 Windows Terminal
Write-Host "`n检查 Windows Terminal… / Checking Windows Terminal…" -ForegroundColor Yellow
if (-not (Get-Command wt -ErrorAction SilentlyContinue)) {
    Write-Host "安装 Windows Terminal… / Installing Windows Terminal…" -ForegroundColor Yellow
    winget install --id Microsoft.WindowsTerminal --exact --source winget
    Write-Host "✓ Windows Terminal 安装完成 / Windows Terminal installation completed" -ForegroundColor Green
}
else {
    Write-Host "✓ Windows Terminal 已安装 / Windows Terminal is installed" -ForegroundColor Green
}

# 检查并安装 Scoop
Write-Host "`n检查 Scoop 安装状态… / Checking Scoop installation…" -ForegroundColor Yellow
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Scoop 未安装，开始安装… / Scoop not installed, starting installation…" -ForegroundColor Yellow
    
    # 设置执行策略
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    
    # 安装 Scoop
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    
    Write-Host "✓ Scoop 安装完成 / Scoop installation completed" -ForegroundColor Green
}
else {
    Write-Host "✓ Scoop 已安装 / Scoop is already installed" -ForegroundColor Green
}

# 更新 Scoop
Write-Host "`n更新 Scoop… / Updating Scoop…" -ForegroundColor Yellow
scoop update

# 安装 Git（Scoop 依赖）
Write-Host "`n安装 Git… / Installing Git…" -ForegroundColor Yellow
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    scoop install git --global
    Write-Host "✓ Git 安装完成 / Git installation completed" -ForegroundColor Green
}
else {
    Write-Host "✓ Git 已安装 / Git is already installed" -ForegroundColor Green
}

# 安装 Aria2（加速下载）
Write-Host "`n配置 Aria2 下载加速… / Configuring Aria2 for faster downloads…" -ForegroundColor Yellow
if (-not (scoop list | Select-String -Pattern "aria2")) {
    scoop install aria2 --global
    scoop config aria2-enabled true
    scoop config aria2-warning-enabled false
    Write-Host "✓ Aria2 配置完成（全局） / Aria2 configuration completed (global)" -ForegroundColor Green
}
else {
    Write-Host "✓ Aria2 已安装 / Aria2 is already installed" -ForegroundColor Green
}

# 添加 Scoop 常用 buckets
Write-Host "`n添加 Scoop buckets… / Adding Scoop buckets…" -ForegroundColor Yellow

$buckets = @("extras", "versions", "nerd-fonts", "sysinternals")

foreach ($bucketName in $buckets) {
    $bucketList = scoop bucket list
    
    if ($bucketList -match $bucketName) {
        Write-Host "✓ Bucket '$bucketName' 已添加 / Bucket '$bucketName' already added" -ForegroundColor Green
    }
    else {
        Write-Host "添加 bucket: $bucketName … / Adding bucket: $bucketName …" -ForegroundColor Yellow
        scoop bucket add $bucketName
        Write-Host "✓ Bucket '$bucketName' 添加成功 / Bucket '$bucketName' added successfully" -ForegroundColor Green
    }
}

# 安装 gsudo（类似 Linux 的 sudo）
Write-Host "`n安装 gsudo… / Installing gsudo…" -ForegroundColor Yellow
if (-not (Get-Command gsudo -ErrorAction SilentlyContinue)) {
    scoop install gsudo --global
    Write-Host "✓ gsudo 安装完成（全局） / gsudo installation completed (global)" -ForegroundColor Green
}
else {
    Write-Host "✓ gsudo 已安装 / gsudo is already installed" -ForegroundColor Green
}

# 安装 Visual C++ 运行库
Write-Host "`n=== Visual C++ 运行库 / Visual C++ Redistributables ===" -ForegroundColor Cyan

$installVCRedist = Read-Host "是否安装 Visual C++ 2005-2022 运行库？(Y/n) / Install Visual C++ 2005-2022 Redistributables? (Y/n)"
if ($installVCRedist -notmatch '^[Nn]$') {
    $vcRedistPackages = @(
        @{ Id = "Microsoft.VCRedist.2005.x64"; Name = "VC++ 2005 x64" }
        @{ Id = "Microsoft.VCRedist.2005.x86"; Name = "VC++ 2005 x86" }
        @{ Id = "Microsoft.VCRedist.2008.x64"; Name = "VC++ 2008 x64" }
        @{ Id = "Microsoft.VCRedist.2008.x86"; Name = "VC++ 2008 x86" }
        @{ Id = "Microsoft.VCRedist.2010.x64"; Name = "VC++ 2010 x64" }
        @{ Id = "Microsoft.VCRedist.2010.x86"; Name = "VC++ 2010 x86" }
        @{ Id = "Microsoft.VCRedist.2012.x64"; Name = "VC++ 2012 x64" }
        @{ Id = "Microsoft.VCRedist.2012.x86"; Name = "VC++ 2012 x86" }
        @{ Id = "Microsoft.VCRedist.2013.x64"; Name = "VC++ 2013 x64" }
        @{ Id = "Microsoft.VCRedist.2013.x86"; Name = "VC++ 2013 x86" }
        @{ Id = "Microsoft.VCRedist.2015+.x64"; Name = "VC++ 2015-2022 x64" }
        @{ Id = "Microsoft.VCRedist.2015+.x86"; Name = "VC++ 2015-2022 x86" }
    )
    
    Write-Host "正在安装 Visual C++ 运行库... / Installing Visual C++ Redistributables..." -ForegroundColor Yellow
    
    foreach ($package in $vcRedistPackages) {
        $null = winget list --id $package.Id --exact 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  安装 $($package.Name)... / Installing $($package.Name)..." -ForegroundColor Cyan
            winget install --id $package.Id --exact --silent --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ $($package.Name) 安装完成 / $($package.Name) installation completed" -ForegroundColor Green
            }
            else {
                Write-Host "  ✗ $($package.Name) 安装失败 / $($package.Name) installation failed" -ForegroundColor Red
            }
        }
        else {
            Write-Host "  ✓ $($package.Name) 已安装 / $($package.Name) is already installed" -ForegroundColor Green
        }
    }
    
    Write-Host "✓ Visual C++ 运行库安装完成 / Visual C++ Redistributables installation completed" -ForegroundColor Green
}

# 安装 Chezmoi 配置管理工具
Write-Host "`n=== Chezmoi 配置管理工具 / Chezmoi Configuration Management Tool ===" -ForegroundColor Cyan
if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    $installChezmoi = Read-Host "是否安装 Chezmoi？(Y/n) / Install Chezmoi? (Y/n)"
    if ($installChezmoi -notmatch '^[Nn]$') {
        scoop install chezmoi
        Write-Host "✓ Chezmoi 安装完成 / Chezmoi installation completed" -ForegroundColor Green
        
        $initChezmoi = Read-Host "是否初始化 dotfiles 配置？(Y/n) / Initialize dotfiles configuration? (Y/n)"
        if ($initChezmoi -notmatch '^[Nn]$') {
            chezmoi init https://github.com/Cyanix-0721/dotfiles.git --apply
            Write-Host "✓ dotfiles 配置初始化完成 / dotfiles configuration initialized" -ForegroundColor Green
        }
    }
}
else {
    Write-Host "✓ Chezmoi 已安装 / Chezmoi is already installed" -ForegroundColor Green
}

Write-Host "`n✓ 系统基础环境配置完成 / System foundation setup completed" -ForegroundColor Green
Write-Host "`n当前已安装的应用列表 / Currently installed applications:" -ForegroundColor Cyan
scoop list
