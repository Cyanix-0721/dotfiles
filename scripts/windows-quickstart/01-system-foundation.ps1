#!/usr/bin/env pwsh

<#
.SYNOPSIS
    系统基础环境配置 / System Foundation Setup

.DESCRIPTION
    安装和配置 Scoop 包管理器及基础开发工具
    Install and configure Scoop package manager and basic development tools
#>

$ErrorActionPreference = "Stop"

# 加载公共函数
. "$PSScriptRoot/00-common.ps1"

Write-Header "系统基础环境配置 / System Foundation Setup"

# 更新 winget 源
Write-Step "更新 winget 源 / Updating winget sources"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过更新 / winget not installed, skipping source update"

    $openChoice = Read-Host "是否打开安装页面以安装 winget？1) Microsoft Store（推荐） 2) GitHub Releases（下载）；输入 1/2，回车跳过 / Open install page? 1) MS Store (recommended) 2) GitHub Releases (download); enter to skip"
    switch ($openChoice) {
        '1' {
            try {
                Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
                Write-Ok "已打开 Microsoft Store 页面 / Opened Microsoft Store"
            }
            catch {
                Write-Err "无法打开 Microsoft Store 页面，请手动访问：ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
            }
        }
        '2' {
            try {
                Start-Process "https://github.com/microsoft/winget-cli/releases"
                Write-Ok "已打开 GitHub Releases 页面 / Opened GitHub Releases"
            }
            catch {
                Write-Err "无法打开 GitHub Releases 页面，请手动访问：https://github.com/microsoft/winget-cli/releases"
            }
        }
        default {
            Write-Note "跳过 winget 安装页面 / Skipping winget install page"
        }
    }
}
else {
    try {
        winget source update
    }
    catch {
        Write-Warn "更新 winget 源失败（非致命），继续执行后续步骤 / Updating winget sources failed (non-fatal), continuing"
    }
}

# 检查并安装 Scoop
Write-Step "检查 Scoop 安装状态 / Checking Scoop installation"
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Note "Scoop 未安装，开始安装… / Scoop not installed, starting installation…"
    
    # 设置执行策略
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    
    # 安装 Scoop
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    
    Write-Ok "Scoop 安装完成 / Scoop installation completed"
}
else {
    Write-Ok "Scoop 已安装 / Scoop is already installed"
}

# 更新 Scoop
Write-Step "更新 Scoop / Updating Scoop"
scoop update

# 安装 Git（Scoop 依赖）
Write-Step "安装 Git / Installing Git"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    scoop install git --global
    Write-Ok "Git 安装完成 / Git installation completed"
}
else {
    Write-Ok "Git 已安装 / Git is already installed"
}

# 安装 Aria2（加速下载）
Write-Step "配置 Aria2 下载加速 / Configuring Aria2 for faster downloads"
if (-not (scoop list | Select-String -Pattern "aria2")) {
    scoop install aria2
    scoop config aria2-enabled true
    scoop config aria2-warning-enabled false
    Write-Ok "Aria2 配置完成 / Aria2 configuration completed"
}
else {
    Write-Ok "Aria2 已安装 / Aria2 is already installed"
}

# 添加 Scoop 常用 buckets
Write-Step "添加 Scoop buckets / Adding Scoop buckets"

$buckets = @("extras", "versions", "nerd-fonts", "sysinternals")

foreach ($bucketName in $buckets) {
    $bucketList = scoop bucket list
    
    if ($bucketList -match $bucketName) {
        Write-Ok "Bucket '$bucketName' 已添加 / Bucket '$bucketName' already added"
    }
    else {
        Write-Step "添加 bucket: $bucketName / Adding bucket: $bucketName"
        scoop bucket add $bucketName
        Write-Ok "Bucket '$bucketName' 添加成功 / Bucket '$bucketName' added successfully"
    }
}

# 安装 gsudo（类似 Linux 的 sudo）
Write-Step "安装 gsudo / Installing gsudo"
if (-not (Get-Command gsudo -ErrorAction SilentlyContinue)) {
    scoop install gsudo
    Write-Ok "gsudo 安装完成 / gsudo installation completed"
}
else {
    Write-Ok "gsudo 已安装 / gsudo is already installed"
}

# 通过 Scoop 安装 PowerShell 7
Write-Step "安装 PowerShell 7 / Installing PowerShell 7"
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    scoop install pwsh
    Write-Ok "PowerShell 7 安装完成，请重新启动终端并使用 pwsh 运行本脚本 / PowerShell 7 installation completed, please restart terminal and rerun this script with pwsh"
    exit
}
else {
    Write-Ok "PowerShell 7 已安装 / PowerShell 7 is already installed"
}

# 安装 Visual C++ 运行库
Write-Header "Visual C++ 运行库 / Visual C++ Redistributables"

$installVCRedist = Read-Host "是否安装 Visual C++ 2005-2022 运行库？(Y/n) / Install Visual C++ 2005-2022 Redistributables? (Y/n)"
if ($installVCRedist -notmatch '^[Nn]$') {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warn "winget 未安装，跳过 Visual C++ 运行库安装 / winget not installed, skipping Visual C++ installation"
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
        
        Write-Step "正在安装 Visual C++ 运行库... / Installing Visual C++ Redistributables..."
        
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
                Write-Step "安装 $($appInfo.Name) / Installing $($appInfo.Name)..."
                winget install --id $appId $($appInfo.InstallArgs) --accept-source-agreements --accept-package-agreements
                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "$($appInfo.Name) 安装完成 / $($appInfo.Name) installation completed"
                }
                else {
                    Write-Err "$($appInfo.Name) 安装失败 / $($appInfo.Name) installation failed"
                }
            }
            else {
                Write-Ok "$($appInfo.Name) 已安装 / $($appInfo.Name) is already installed"
            }
        }
        
        Write-Ok "Visual C++ 运行库安装完成 / Visual C++ Redistributables installation completed"
    }
}

# 安装 Microsoft Edge WebView2 运行时
Write-Header "Microsoft Edge WebView2 运行时 / WebView2 Runtime"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过 WebView2 安装 / winget not installed, skipping WebView2 installation"
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
            Write-Step "安装 $($appInfo.Desc) / Installing $($appInfo.Desc)..."
            winget install --id $appId $($appInfo.InstallArgs) --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "$($appInfo.Desc) 安装完成 / $($appInfo.Desc) installation completed"
            }
            else {
                Write-Err "$($appInfo.Desc) 安装失败 / $($appInfo.Desc) installation failed"
            }
        }
        else {
            Write-Ok "$($appInfo.Desc) 已安装 / $($appInfo.Desc) is already installed"
        }
    }
}

# 安装 Chezmoi 配置管理工具
Write-Header "Chezmoi 配置管理工具 / Chezmoi Configuration Management Tool"
if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    $installChezmoi = Read-Host "是否安装 Chezmoi？(Y/n) / Install Chezmoi? (Y/n)"
    if ($installChezmoi -notmatch '^[Nn]$') {
        scoop install chezmoi
        Write-Ok "Chezmoi 安装完成 / Chezmoi installation completed"
        
        $initChezmoi = Read-Host "是否初始化 dotfiles 配置？(Y/n) / Initialize dotfiles configuration? (Y/n)"
        if ($initChezmoi -notmatch '^[Nn]$') {
            chezmoi init https://github.com/Cyanix-0721/dotfiles.git --apply
            Write-Ok "dotfiles 配置初始化完成 / dotfiles configuration initialized"
        }
    }
}
else {
    Write-Ok "Chezmoi 已安装 / Chezmoi is already installed"
}

Write-Header "系统基础环境配置完成 / System foundation setup completed"
Write-Note "当前已安装的应用列表 / Currently installed applications:"
scoop list
