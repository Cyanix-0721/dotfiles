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

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "⚠️ winget 未安装，跳过更新 / winget not installed, skipping source update" -ForegroundColor Yellow

    $openChoice = Read-Host "是否打开安装页面以安装 winget？1) Microsoft Store（推荐） 2) GitHub Releases（下载）；输入 1/2，回车跳过 / Open install page? 1) MS Store (recommended) 2) GitHub Releases (download); enter to skip"
    switch ($openChoice) {
        '1' {
            try {
                Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
                Write-Host "已打开 Microsoft Store 页面 / Opened Microsoft Store" -ForegroundColor Cyan
            }
            catch {
                Write-Host "无法打开 Microsoft Store 页面，请手动访问：ms-windows-store://pdp/?productid=9NBLGGH4NNS1" -ForegroundColor Red
            }
        }
        '2' {
            try {
                Start-Process "https://github.com/microsoft/winget-cli/releases"
                Write-Host "已打开 GitHub Releases 页面 / Opened GitHub Releases" -ForegroundColor Cyan
            }
            catch {
                Write-Host "无法打开 GitHub Releases 页面，请手动访问：https://github.com/microsoft/winget-cli/releases" -ForegroundColor Red
            }
        }
        default {
            Write-Host "跳过 winget 安装页面 / Skipping winget install page" -ForegroundColor Yellow
        }
    }
}
else {
    try {
        winget source update
    }
    catch {
        Write-Host "⚠️ 更新 winget 源失败（非致命），继续执行后续步骤 / Updating winget sources failed (non-fatal), continuing" -ForegroundColor Yellow
    }
}

# 检查是否已安装 PowerShell 7
Write-Host "`n检查 PowerShell 7… / Checking PowerShell 7…" -ForegroundColor Yellow
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "⚠️ winget 未安装，无法安装 PowerShell 7，请手动安装 / winget not installed, please install PowerShell manually" -ForegroundColor Yellow
        exit 1
    }
    else {
        $wingApps = @{ 
            "Microsoft.PowerShell" = @{ Desc = "PowerShell 7"; InstallArgs = "--exact --source winget" }
        }

        foreach ($entry in $wingApps.GetEnumerator()) {
            $appId = $entry.Key
            $appInfo = $entry.Value

            try {
                $isInstalled = winget list --id $appId --exact -s winget 2>$null | Select-String $appId
            }
            catch {
                $isInstalled = $null
            }

            if (-not $isInstalled) {
                Write-Host "正在通过 winget 安装 $($appInfo.Desc) ($appId)..." -ForegroundColor Cyan
                winget install --id $appId $($appInfo.InstallArgs) --accept-source-agreements --accept-package-agreements
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✓ $($appInfo.Desc) 安装完成，请重新启动终端并使用 pwsh 运行本脚本 / $($appInfo.Desc) installation completed, please restart terminal and rerun this script with pwsh" -ForegroundColor Green
                }
                else {
                    Write-Host "✗ $($appInfo.Desc) 安装失败 / $($appInfo.Desc) installation failed" -ForegroundColor Red
                    exit 1
                }
            }
            else {
                Write-Host "✓ $($appInfo.Desc) 已安装 / $($appInfo.Desc) is already installed" -ForegroundColor Green
            }
        }

        exit
    }
}
else {
    Write-Host "✓ PowerShell 7 已安装 / PowerShell 7 is already installed" -ForegroundColor Green
}

# 安装 Windows Terminal
Write-Host "`n检查 Windows Terminal… / Checking Windows Terminal…" -ForegroundColor Yellow
if (-not (Get-Command wt -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "⚠️ winget 未安装，跳过 Windows Terminal 安装 / winget not installed, skipping Windows Terminal installation" -ForegroundColor Yellow
    }
    else {
        $wingApps = @{ 
            "Microsoft.WindowsTerminal" = @{ Desc = "Windows Terminal"; InstallArgs = "--exact --source winget" }
        }

        foreach ($entry in $wingApps.GetEnumerator()) {
            $appId = $entry.Key
            $appInfo = $entry.Value

            try {
                $isInstalled = winget list --id $appId --exact -s winget 2>$null | Select-String $appId
            }
            catch {
                $isInstalled = $null
            }

            if (-not $isInstalled) {
                Write-Host "正在通过 winget 安装 $($appInfo.Desc) ($appId)..." -ForegroundColor Cyan
                winget install --id $appId $($appInfo.InstallArgs) --accept-source-agreements --accept-package-agreements
                Write-Host "✓ $appId 安装完成 / $appId installation completed" -ForegroundColor Green
            }
            else {
                Write-Host "✓ $appId 已安装 / $appId is already installed" -ForegroundColor Green
            }
        }
    }
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
    scoop install aria2
    scoop config aria2-enabled true
    scoop config aria2-warning-enabled false
    Write-Host "✓ Aria2 配置完成 / Aria2 configuration completed" -ForegroundColor Green
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
    scoop install gsudo
    Write-Host "✓ gsudo 安装完成 / gsudo installation completed" -ForegroundColor Green
}
else {
    Write-Host "✓ gsudo 已安装 / gsudo is already installed" -ForegroundColor Green
}

# 安装 Visual C++ 运行库
Write-Host "`n=== Visual C++ 运行库 / Visual C++ Redistributables ===" -ForegroundColor Cyan

$installVCRedist = Read-Host "是否安装 Visual C++ 2005-2022 运行库？(Y/n) / Install Visual C++ 2005-2022 Redistributables? (Y/n)"
if ($installVCRedist -notmatch '^[Nn]$') {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "⚠️ winget 未安装，跳过 Visual C++ 运行库安装 / winget not installed, skipping Visual C++ installation" -ForegroundColor Yellow
    }
    else {
        $wingApps = @{ 
            "Microsoft.VCRedist.2005.x64"  = @{ Name = "VC++ 2005 x64"; InstallArgs = "--exact --silent" }
            "Microsoft.VCRedist.2005.x86"  = @{ Name = "VC++ 2005 x86"; InstallArgs = "--exact --silent" }
            "Microsoft.VCRedist.2008.x64"  = @{ Name = "VC++ 2008 x64"; InstallArgs = "--exact --silent" }
            "Microsoft.VCRedist.2008.x86"  = @{ Name = "VC++ 2008 x86"; InstallArgs = "--exact --silent" }
            "Microsoft.VCRedist.2010.x64"  = @{ Name = "VC++ 2010 x64"; InstallArgs = "--exact --silent" }
            "Microsoft.VCRedist.2010.x86"  = @{ Name = "VC++ 2010 x86"; InstallArgs = "--exact --silent" }
            "Microsoft.VCRedist.2012.x64"  = @{ Name = "VC++ 2012 x64"; InstallArgs = "--exact --silent" }
            "Microsoft.VCRedist.2012.x86"  = @{ Name = "VC++ 2012 x86"; InstallArgs = "--exact --silent" }
            "Microsoft.VCRedist.2013.x64"  = @{ Name = "VC++ 2013 x64"; InstallArgs = "--exact --silent" }
            "Microsoft.VCRedist.2013.x86"  = @{ Name = "VC++ 2013 x86"; InstallArgs = "--exact --silent" }
            "Microsoft.VCRedist.2015+.x64" = @{ Name = "VC++ 2015-2022 x64"; InstallArgs = "--exact --silent" }
            "Microsoft.VCRedist.2015+.x86" = @{ Name = "VC++ 2015-2022 x86"; InstallArgs = "--exact --silent" }
        }
        
        Write-Host "正在安装 Visual C++ 运行库... / Installing Visual C++ Redistributables..." -ForegroundColor Yellow
        
        foreach ($entry in $wingApps.GetEnumerator()) {
            $appId = $entry.Key
            $appInfo = $entry.Value

            try {
                $isInstalled = winget list --id $appId --exact -s winget 2>$null | Select-String $appId
            }
            catch {
                $isInstalled = $null
            }

            if (-not $isInstalled) {
                Write-Host "  安装 $($appInfo.Name)... / Installing $($appInfo.Name)..." -ForegroundColor Cyan
                winget install --id $appId $($appInfo.InstallArgs) --accept-source-agreements --accept-package-agreements
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✓ $($appInfo.Name) 安装完成 / $($appInfo.Name) installation completed" -ForegroundColor Green
                }
                else {
                    Write-Host "  ✗ $($appInfo.Name) 安装失败 / $($appInfo.Name) installation failed" -ForegroundColor Red
                }
            }
            else {
                Write-Host "  ✓ $($appInfo.Name) 已安装 / $($appInfo.Name) is already installed" -ForegroundColor Green
            }
        }
        
        Write-Host "✓ Visual C++ 运行库安装完成 / Visual C++ Redistributables installation completed" -ForegroundColor Green
    }
}

# 安装 Microsoft Edge WebView2 运行时
Write-Host "`n=== Microsoft Edge WebView2 运行时 / WebView2 Runtime ===" -ForegroundColor Cyan

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "⚠️ winget 未安装，跳过 WebView2 安装 / winget not installed, skipping WebView2 installation" -ForegroundColor Yellow
}
else {
    $wingApps = @{ 
        "Microsoft.EdgeWebView2Runtime" = @{ Desc = "WebView2 Runtime"; InstallArgs = "--exact --silent" }
    }

    foreach ($entry in $wingApps.GetEnumerator()) {
        $appId = $entry.Key
        $appInfo = $entry.Value

        try {
            $isInstalled = winget list --id $appId --exact -s winget 2>$null | Select-String $appId
        }
        catch {
            $isInstalled = $null
        }

        if (-not $isInstalled) {
            Write-Host "安装 $($appInfo.Desc)… / Installing $($appInfo.Desc)…" -ForegroundColor Yellow
            winget install --id $appId $($appInfo.InstallArgs) --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ $($appInfo.Desc) 安装完成 / $($appInfo.Desc) installation completed" -ForegroundColor Green
            }
            else {
                Write-Host "✗ $($appInfo.Desc) 安装失败 / $($appInfo.Desc) installation failed" -ForegroundColor Red
            }
        }
        else {
            Write-Host "✓ $($appInfo.Desc) 已安装 / $($appInfo.Desc) is already installed" -ForegroundColor Green
        }
    }
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
