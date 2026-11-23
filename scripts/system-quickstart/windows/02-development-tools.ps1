#!/usr/bin/env pwsh

<#
.SYNOPSIS
    开发工具安装 / Development Tools Installation

.DESCRIPTION
    安装常用的开发工具和编程语言环境
    Install common development tools and programming language environments
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

function Invoke-WslStdin {
    <#
    .SYNOPSIS
        以 UTF-8 (无 BOM) + LF 通过 stdin 调用 wsl.exe，避免 CRLF 破坏 POSIX sh 或 chpasswd。
    #>
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$InputText
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'wsl.exe'
    $escapedArgs = foreach ($arg in $Arguments) {
        if ($arg -match '[\s"]') { '"' + ($arg -replace '"', '\"') + '"' } else { $arg }
    }
    $psi.Arguments = ($escapedArgs -join ' ')
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $writer = New-Object System.IO.StreamWriter($proc.StandardInput.BaseStream, $utf8NoBom)
        $writer.NewLine = "`n"
        $normalizedInput = $InputText -replace "\r\n", "\n"
        $writer.Write($normalizedInput)
        $writer.Flush()
        $writer.Close()
        $proc.WaitForExit()
        $global:LASTEXITCODE = $proc.ExitCode
    }
    finally {
        $proc.Dispose()
    }
}

Write-Header "开发工具安装 / Development Tools Installation"

# 检查 Scoop
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Err "Scoop 未安装，请先运行系统基础环境配置脚本 / Scoop not installed, please run the system foundation setup script first"
    throw "Scoop 未安装 / Scoop not installed"
}

$scoopRoot = if (-not [string]::IsNullOrWhiteSpace($env:SCOOP)) { $env:SCOOP } else { Join-Path $HOME 'scoop' }

# 编辑器和 IDE
Write-Header "编辑器 / Editors and IDEs"

Install-ScoopPackages (Get-PackageSection 'dev.editors')

# Git 工具
Write-Header "Git 工具 / Git Tools"

Install-ScoopPackages (Get-PackageSection 'dev.gitTools')

# Shell 脚本工具
Write-Header "Shell 脚本工具 / Shell Script Tools"

Install-ScoopPackages (Get-PackageSection 'dev.shellTools')

# SVN 客户端
Write-Header "SVN 客户端 / SVN Clients"

Install-ScoopPackages (Get-PackageSection 'dev.svnTools')


# 环境管理
Write-Header "环境管理 / Environment Management"

# 1. 版本管理器 (必装 / Required)
Write-Step "版本管理器 / Version Manager (Required)"
Install-ScoopPackages (Get-PackageSection 'dev.versionManager')

# 1.2 按全局 mise 配置安装全部声明工具
# Install all tools declared in the global mise config.
# 全局工具声明由 chezmoi 纳管(dot_config/mise/config.toml → ~/.config/mise/config.toml),
# 此处不逐个指定工具,统一 `mise install` 按声明安装(幂等,只补缺失版本)。
if (Get-Command mise -ErrorAction SilentlyContinue) {
    $globalMiseConfig = Join-Path $HOME ".config/mise/config.toml"
    if (-not (Test-Path -LiteralPath $globalMiseConfig)) {
        Write-Warn "未找到全局 mise 配置 $globalMiseConfig,无法按声明安装。请先运行 chezmoi apply 部署配置后再重试 / Global mise config not found; run 'chezmoi apply' to deploy it, then rerun"
    }
    elseif (Test-DryRun) {
        Write-Note "[dry-run] 将执行 / would run: mise install"
    }
    else {
        # 首次运行需下载声明中的全部工具,放独立窗口跑以便观察进度;主脚本等待完成再继续
        # First run downloads all declared tools; run in its own window and -Wait before continuing
        Write-Step "在新窗口按全局 mise 配置安装全部声明工具(完成后自动继续)/ Installing all tools declared in global mise config in a new window (continues when done)"
        $miseInstallProc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "mise install" -Wait -PassThru
        if ($miseInstallProc.ExitCode -eq 0) {
            Write-Ok "全局 mise 配置中的工具已安装 / All tools in global mise config installed"
        }
        else {
            Write-Err "mise install 返回非零(退出码 $($miseInstallProc.ExitCode));可稍后手动运行 mise install 重试 / mise install returned non-zero (exit $($miseInstallProc.ExitCode)); rerun 'mise install' later"
            Add-Failure "mise install"
        }
    }
}
else {
    Write-Warn "mise 不可用,跳过按全局配置安装 / mise unavailable, skipping install from global mise config"
}

# 1.5 Node.js 最新 LTS（默认安装并设为全局默认）
# Node.js latest LTS (installed and set as the global default by default)
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    Write-Step "Node.js 最新 LTS / Node.js latest LTS"
    if (Confirm-YesNo -Prompt "是否安装最新 LTS 版 Node.js？(Y/n) / Install latest LTS Node.js? (Y/n)" -DefaultYes) {
        if (Test-DryRun) {
            Write-Note "[dry-run] 将通过 fnm 安装最新 LTS 版 Node.js 并设为默认 / would install latest LTS Node.js via fnm and set default"
        }
        else {
            Write-Step "通过 fnm 安装最新 LTS 版 Node.js / Installing latest LTS Node.js via fnm"
            # 同版本已安装时 fnm 可能返回非零，故结果统一由 fnm list 判定
            $null = Invoke-NativeQuiet -FilePath 'fnm' -Arguments @('install', '--lts')
            $ltsLine = Invoke-NativeQuiet -FilePath 'fnm' -Arguments @('list') | Where-Object { $_ -match 'lts-latest' } | Select-Object -First 1
            $ltsVersion = [regex]::Match([string]$ltsLine, 'v?\d+\.\d+\.\d+').Value
            if ($ltsVersion) {
                Write-Ok "最新 LTS 版 Node.js $ltsVersion 安装完成 / Latest LTS Node.js $ltsVersion installed"
                # lts-latest 别名随 fnm install --lts 自动指向新版本，比固定版本号更稳；
                # 个别环境无法创建别名时退回写具体版本号
                $null = Invoke-NativeQuiet -FilePath 'fnm' -Arguments @('default', 'lts-latest')
                $defaultOk = ($LASTEXITCODE -eq 0)
                if (-not $defaultOk) {
                    $null = Invoke-NativeQuiet -FilePath 'fnm' -Arguments @('default', $ltsVersion)
                    $defaultOk = ($LASTEXITCODE -eq 0)
                }
                if ($defaultOk) {
                    Write-Ok "已将 Node.js $ltsVersion 设为全局默认 / Node.js $ltsVersion set as global default"
                }
                else {
                    Write-Err "设置全局默认失败 / Failed to set global default"
                    Add-Failure "fnm default ($ltsVersion)"
                }
            }
            else {
                Write-Err "最新 LTS 版 Node.js 安装失败 / Latest LTS Node.js installation failed"
                Add-Failure "Node.js LTS (fnm)"
            }
        }
    }
    else {
        Write-Note "跳过 Node.js 安装 / Skipping Node.js installation"
    }
}
else {
    Write-Warn "fnm 不可用，跳过 Node.js LTS 安装 / fnm unavailable, skipping Node.js LTS installation"
}

# 2. Node 包管理器（pnpm，独立二进制；运行 JS 项目仍需 Node）
# Node package manager (pnpm, standalone binary; running JS projects still needs Node)
Write-Step "Node 包管理器 / Node Package Manager (pnpm)"
Install-ScoopPackages (Get-PackageSection 'dev.nodePkg')

# 2.1 DSH（DeepSeek Harness）CLI 与 TUI（pnpm 全局安装，需 Node 运行）
# DSH (DeepSeek Harness) CLI & TUI (installed globally via pnpm; needs Node to run)
if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    Write-Step "DSH CLI 与 TUI / DSH CLI & TUI (pnpm global)"
    if (Confirm-YesNo -Prompt "是否通过 pnpm 全局安装 DSH（@deepseek-ai/dsh）与 TUI（@deepseek-harness-tui/dsh-tui）？(Y/n) / Install DSH CLI & TUI globally via pnpm? (Y/n)" -DefaultYes) {
        if (Test-DryRun) {
            Write-Note "[dry-run] 将初始化 PNPM_HOME / fnm 环境并执行: pnpm add -g @deepseek-ai/dsh @deepseek-harness-tui/dsh-tui / would init PNPM_HOME & fnm env and run pnpm add -g"
        }
        else {
            try {
                # 干净机器上需先激活 fnm 与 PNPM_HOME，避免 pnpm add -g 因缺少全局 bin 目录或 Node 而失败
                if (Get-Command fnm -ErrorAction SilentlyContinue) {
                    $fnmEnvLines = @(Invoke-NativeQuiet -FilePath 'fnm' -Arguments @('env', '--shell', 'powershell'))
                    foreach ($line in $fnmEnvLines) {
                        if ($line -match '^\$env:([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]*)"$') {
                            Set-Item -Path "Env:$($Matches[1])" -Value $Matches[2]
                        }
                    }
                }
                if ([string]::IsNullOrWhiteSpace($env:PNPM_HOME)) {
                    $env:PNPM_HOME = Join-Path $env:LOCALAPPDATA 'pnpm'
                }
                if (-not (Test-Path -LiteralPath $env:PNPM_HOME)) {
                    New-Item -ItemType Directory -Path $env:PNPM_HOME -Force | Out-Null
                }
                $currentPathItems = @($env:Path -split ';' | Where-Object { $_ })
                if ($currentPathItems -notcontains $env:PNPM_HOME) {
                    $env:Path = "$($env:PNPM_HOME);$($env:Path)"
                }

                $global:LASTEXITCODE = 0
                & pnpm @('add', '-g', '@deepseek-ai/dsh', '@deepseek-harness-tui/dsh-tui')
                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "DSH CLI 与 TUI 安装完成 / DSH CLI & TUI installed"
                }
                else {
                    Write-Err "DSH 安装失败（退出码 $LASTEXITCODE）/ Installing DSH failed (exit $LASTEXITCODE)"
                    Add-Failure "DSH CLI & TUI (pnpm)"
                }
            }
            catch {
                Write-Err "DSH 安装失败 / Installing DSH failed: $($_.Exception.Message)"
                Add-Failure "DSH CLI & TUI (pnpm)"
            }
        }
    }
    else {
        Write-Note "跳过 DSH 安装 / Skipping DSH installation"
    }
}
else {
    Write-Warn "pnpm 不可用，跳过 DSH 安装 / pnpm unavailable, skipping DSH installation"
}

# 3. Python 包管理器 (可选一个或都安装，默认 uv / Optional, can install one or both, default uv)
Write-Step "Python 包管理器 / Python Package Manager (Optional)"
Write-Note "可以选择安装 uv、miniconda3 或两者都装 / Can install uv, miniconda3, or both"

Install-ScoopPackages (Get-PackageSection 'dev.pythonPkg')

# uv 工具 (copyparty, ruff / uv tools)
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Write-Step "uv 工具 / uv Tools (copyparty, ruff)"
    if (Confirm-YesNo -Prompt "安装 uv 工具 copyparty、ruff？(Y/n) / Install uv tools copyparty, ruff? (Y/n)" -DefaultYes) {
        foreach ($uvTool in @('copyparty', 'ruff')) {
            if (Test-DryRun) {
                Write-Note "[dry-run] 将执行 / would run: uv tool install $uvTool"
                continue
            }
            Write-Step "安装 uv 工具 $uvTool / Installing uv tool $uvTool"
            $global:LASTEXITCODE = 0
            & uv @('tool', 'install', $uvTool)
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "uv 工具 $uvTool 安装完成 / uv tool $uvTool installed"
            }
            else {
                Write-Err "uv 工具 $uvTool 安装失败（退出码 $LASTEXITCODE）/ uv tool $uvTool failed (exit $LASTEXITCODE)"
                Add-Failure "$uvTool (uv tool)"
            }
        }
    }
    else {
        Write-Note "跳过 uv 工具 / Skipping uv tools"
    }
}
else {
    Write-Note "uv 未安装，跳过 uv 工具 / uv not installed, skipping uv tools"
}

# .NET 运行时和 SDK
Write-Header ".NET 运行时和 SDK / .NET Runtime and SDK"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过 .NET 安装 / winget not installed, skipping .NET installation"
}
else {
    $dotnetVersions = @(5, 6, 7, 8, 9, 10)
    $eolDotnetVersions = @(5, 6, 7)

    foreach ($version in $dotnetVersions) {
        $eolHint = if ($version -in $eolDotnetVersions) { ' [EOL]' } else { '' }
        # 均为默认否 (y/N)，-AutoYes 模式下自动跳过
        if (-not (Confirm-YesNo -Prompt "是否安装 .NET $version.0$eolHint？(y/N) / Install .NET $version.0$eolHint? (y/N)")) { continue }

        Write-Step "选择 .NET $version.0 安装类型 / Choosing .NET $version.0 install type"
        Write-Note "1. 仅 SDK (包含运行时) / SDK only (includes runtime) (默认 / default)"
        Write-Note "2. 仅运行时 / Runtime only"

        $choice = Read-Choice -Prompt "请输入选项 (1/2，默认 1) / Enter option (1/2, default 1)" -Default "1"

        # 组装包 ID，交由 Install-WingetApp 处理（内置已安装检测、日志与退出码）
        $appId = switch ($choice) {
            "1" { "Microsoft.DotNet.SDK.$version" }
            "2" { "Microsoft.DotNet.Runtime.$version" }
            default { $null }
        }
        if (-not $appId) {
            Write-Warn "无效选项，跳过 .NET $version.0 安装 / Invalid option, skipping .NET $version.0 installation"
            continue
        }
        $kindLabel = if ($choice -eq "1") { "SDK (含运行时) / SDK (includes runtime)" } else { "运行时 / Runtime" }
        Install-WingetApp -Id $appId -Desc ".NET $version.0 $kindLabel" -Force
    }
}

# C/C++ 构建工具（Visual Studio BuildTools，跟随 winget 源最新版）
# C/C++ build tools (Visual Studio BuildTools, tracks the latest version on the winget source)
Write-Header "C/C++ 构建工具 / C/C++ Build Tools (Visual Studio BuildTools)"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "winget 未安装，跳过 VS BuildTools 安装 / winget not installed, skipping VS BuildTools installation"
}
else {
    # BuildTools 体积大且非必需：交互与 -AutoYes 模式下均默认跳过 (y/N)
    # BuildTools is large and optional: skipped by default both interactively and in -AutoYes mode (y/N)
    if (Confirm-YesNo -Prompt "是否安装 Visual Studio BuildTools（含 C++ 桌面开发工作负载）？(y/N) / Install Visual Studio BuildTools (with C++ desktop workload)? (y/N)") {
        Write-Step "检查 VS BuildTools 安装状态 / Checking VS BuildTools installation status"
        if (-not (Test-WingetInstalled -Id "Microsoft.VisualStudio.BuildTools")) {
            Write-Step "通过 winget 安装 VS BuildTools（VCTools workload）/ Installing VS BuildTools (VCTools workload) via winget"
            Invoke-WingetInstall -Id "Microsoft.VisualStudio.BuildTools" -InstallArgs @("--exact", "--override", "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive --norestart")
            if (-not (Test-DryRun)) {
                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "VS BuildTools 安装完成 / VS BuildTools installation completed"
                }
                elseif ($LASTEXITCODE -eq 3010) {
                    Write-Warn "VS BuildTools 安装完成，但需要重启系统以生效（退出码 3010）/ VS BuildTools installed, reboot required (exit 3010)"
                }
                else {
                    Write-Err "VS BuildTools 安装失败（退出码 $LASTEXITCODE），请稍后手动运行 winget 命令重试 / VS BuildTools installation failed (exit $LASTEXITCODE); retry manually later"
                    Add-Failure "Microsoft.VisualStudio.BuildTools (winget)"
                }
            }
        }
        else {
            Write-Ok "VS BuildTools 已安装 / VS BuildTools is already installed"
        }
    }
    else {
        Write-Note "跳过 VS BuildTools 安装 / Skipping VS BuildTools installation"
    }
}

# API 开发工具
Write-Header "API 开发工具 / API Development Tools"

Install-ScoopPackages (Get-PackageSection 'dev.api')

# 数据库工具
Write-Header "数据库工具 / Database Tools"

Install-ScoopPackages (Get-PackageSection 'dev.db')

# 其他开发工具
Write-Header "其他开发工具 / Other Development Tools"

Install-ScoopPackages (Get-PackageSection 'dev.misc')

# Android 工具 / Android tools
Write-Header "Android 工具 / Android Tools"

# 默认只装 adb：scoop 的 adb 包就是 platform-tools，含 adb 与 fastboot，全局可用且不需要 Android SDK。
# 全选 Y / -AutoYes（整机全量装机）时改装 Android Studio，并用 cmdline-tools 以 --sdk_root 把 SDK
# 引导到 Studio 的默认根（%LOCALAPPDATA%\Android\Sdk），使 adb / fastboot / sdkmanager 全局可用。
$androidSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"

if ($Script:AutoYes) {
    $sdkManager = Join-Path $androidSdk "cmdline-tools\latest\bin\sdkmanager.bat"
    $androidTools = [ordered]@{
        "android-studio" = @{ Desc = "Android Studio"; Global = $false }
    }
    $needBootstrapClt = -not (Test-Path -LiteralPath $sdkManager)
    if ($needBootstrapClt) {
        $androidTools["android-clt"] = @{
            Desc     = "Android Command Line Tools（仅作 SDK 引导，本步骤末尾卸载）"
            Global   = $false
            PostNote = @("仅用于引导 SDK，本步骤结束后会自动卸载 / bootstrap only, removed at the end of this step")
        }
    }
    Install-ScoopPackages $androidTools

    # Android Studio 不设环境变量、无人值守时也不装组件；仅当 SDK 根尚无 sdkmanager 时才用 android-clt 引导
    if ($needBootstrapClt) {
        if (Test-DryRun) {
            Write-Note "[dry-run] 将通过 android-clt 引导 cmdline-tools;latest 到 $androidSdk / would bootstrap cmdline-tools;latest into $androidSdk"
        }
        else {
            $bootstrapSdkManager = Join-Path $scoopRoot "apps\android-clt\current\cmdline-tools\latest\bin\sdkmanager.bat"
            if (Test-Path -LiteralPath $bootstrapSdkManager) {
                Write-Step "把 cmdline-tools 装进 SDK 根 / Installing cmdline-tools into the SDK root"
                $global:LASTEXITCODE = 0
                & $bootstrapSdkManager "--sdk_root=$androidSdk" "cmdline-tools;latest"
                if ($LASTEXITCODE -ne 0) {
                    Write-Err "cmdline-tools 引导失败（退出码 $LASTEXITCODE）/ cmdline-tools bootstrap failed (exit $LASTEXITCODE)"
                    Add-Failure "android cmdline-tools"
                }
            }
            else {
                Write-Warn "未找到引导用 sdkmanager（$bootstrapSdkManager）/ Bootstrap sdkmanager not found"
                Add-Failure "android-clt bootstrap"
            }
        }
    }

    if (Test-DryRun) {
        Write-Note "[dry-run] 将通过 sdkmanager 安装 platform-tools 并接受许可证 / would install platform-tools and accept SDK licenses"
        if ($needBootstrapClt) {
            Write-Note "[dry-run] 将卸载临时的 android-clt / would uninstall temporary android-clt"
        }
        Write-Note "[dry-run] 将写入用户环境变量 ANDROID_HOME=$androidSdk 并追加 SDK 路径到 User Path / would configure User ANDROID_HOME and Path"
    }
    else {
        if (Test-Path -LiteralPath $sdkManager) {
            Write-Step "安装 platform-tools（adb / fastboot）/ Installing platform-tools"
            $global:LASTEXITCODE = 0
            & $sdkManager "platform-tools"
            if ($LASTEXITCODE -ne 0) {
                Write-Err "platform-tools 安装失败（退出码 $LASTEXITCODE）/ platform-tools installation failed (exit $LASTEXITCODE)"
                Add-Failure "android platform-tools"
            }

            Write-Step "接受 SDK 许可证 / Accepting SDK licenses"
            $global:LASTEXITCODE = 0
            "y`ny`ny`ny`ny`ny`ny`ny`n" | & $sdkManager --licenses
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "接受 SDK 许可证返回非零（退出码 $LASTEXITCODE）/ Accepting SDK licenses returned exit $LASTEXITCODE"
                Add-Failure "android sdk licenses"
            }
        }
        else {
            Write-Warn "未找到 sdkmanager（$sdkManager），跳过 SDK 引导 / sdkmanager not found, skipping SDK bootstrap"
            Add-Failure "android sdkmanager"
        }

        # 仅在本次引导装过且仍存在时卸载临时的 android-clt（scoop 卸载会清掉其 env，故环境变量在之后设置）
        if ($needBootstrapClt -and (Test-ScoopInstalled "android-clt")) {
            Write-Step "卸载临时的 android-clt / Removing the temporary android-clt"
            $global:LASTEXITCODE = 0
            & scoop @('uninstall', 'android-clt')
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "卸载临时 android-clt 失败（退出码 $LASTEXITCODE）/ Failed to remove temporary android-clt (exit $LASTEXITCODE)"
                Add-Failure "scoop uninstall android-clt"
            }
            Reset-ScoopCache
        }

        $androidSdkPaths = @(
            (Join-Path $androidSdk "platform-tools")
            (Join-Path $androidSdk "cmdline-tools\latest\bin")
        )
        # 通过注册表 DoNotExpandEnvironmentNames 读写 User Path，避免把 REG_EXPAND_SZ 里的 %VAR% 展开扁平化
        $envKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
        try {
            if ($null -ne $envKey) {
                $rawUserPath = [string]$envKey.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $userPathEntries = @($rawUserPath -split ';' | Where-Object { $_ })
                $pathChanged = $false
                foreach ($entry in $androidSdkPaths) {
                    if ($userPathEntries -notcontains $entry) {
                        $userPathEntries += $entry
                        $pathChanged = $true
                    }
                }
                if ($pathChanged) {
                    $valueKind = if ($rawUserPath -match '%[^%]+%') {
                        [Microsoft.Win32.RegistryValueKind]::ExpandString
                    }
                    else {
                        [Microsoft.Win32.RegistryValueKind]::String
                    }
                    $envKey.SetValue('Path', ($userPathEntries -join ';'), $valueKind)
                }
            }
        }
        finally {
            if ($null -ne $envKey) { $envKey.Close() }
        }
        # 通过 SetEnvironmentVariable 写入 ANDROID_HOME 同时触发 WM_SETTINGCHANGE 广播
        [Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidSdk, "User")

        # 当前会话也立即生效（后续步骤、同窗口验证不必新开终端）
        $sessionPathEntries = @($env:Path -split ';' | Where-Object { $_ })
        foreach ($entry in $androidSdkPaths) {
            if ($sessionPathEntries -notcontains $entry) {
                $env:Path = "$entry;$($env:Path)"
                $sessionPathEntries = @($entry) + $sessionPathEntries
            }
        }
        $env:ANDROID_HOME = $androidSdk
        Write-Ok "ANDROID_HOME = $androidSdk（adb / fastboot / sdkmanager 已全局可用）"
    }
}
else {
    # 默认分支只装 scoop 的 adb；若这台机器已有 SDK 自带的 adb，先提醒别装重
    if (Test-Path -LiteralPath (Join-Path $androidSdk "platform-tools\adb.exe")) {
        Write-Warn "检测到已有 Android SDK 自带的 adb（$androidSdk\platform-tools）；再装 scoop 的 adb 会有两份不同版本 → 'adb server version mismatch'，建议只留一份 / an SDK-provided adb already exists; a second version triggers 'adb server version mismatch' — keep only one"
    }
    $androidTools = [ordered]@{
        "adb" = @{
            Desc     = "adb / fastboot (platform-tools)"
            Global   = $false
            PostNote = @(
                "adb / fastboot 已全局可用，不需要 Android SDK / adb and fastboot are globally available; no SDK required"
                "以后若要在本机做 Android 开发，请先 scoop uninstall adb 再装 Android Studio——两份 platform-tools 版本不同会报 'adb server version mismatch' / For Android development later, remove this package first: two platform-tools versions cause 'adb server version mismatch'"
            )
        }
    }
    Install-ScoopPackages $androidTools
}

# AI 开发工具
Write-Header "AI 开发工具 / AI Development Tools"

Install-ScoopPackages (Get-PackageSection 'dev.ai')

# WSL2 + Debian
Write-Header "WSL2 / Debian 安装 / WSL2 / Debian setup"

if (Confirm-YesNo -Prompt "是否安装 WSL2、Debian 发行版并配置默认开发环境？(Y/n) / Install WSL2, Debian distro and configure the default dev environment? (Y/n)" -DefaultYes) {
    Write-Step "检查并安装 WSL2 / Checking and installing WSL2"

    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        Write-Warn "当前系统未检测到 wsl.exe，尝试通过 winget 安装 WSL / wsl.exe not found, attempting to install WSL via winget"
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Invoke-WingetInstall -Id "Microsoft.WSL" -InstallArgs @("--exact", "--silent")
            if (-not (Test-DryRun)) {
                if ($LASTEXITCODE -eq 3010) {
                    Write-Warn "WSL 安装完成，需要重启系统以生效（退出码 3010）/ WSL installed, reboot required (exit 3010)"
                }
                elseif ($LASTEXITCODE -ne 0) {
                    Write-Err "WSL 安装失败（退出码 $LASTEXITCODE）/ WSL installation failed (exit $LASTEXITCODE)"
                    Add-Failure "Microsoft.WSL (winget)"
                }
            }
        }
        else {
            Write-Err "winget 不可用，无法自动安装 WSL / winget unavailable, cannot auto-install WSL"
            Add-Failure "Microsoft.WSL"
        }
    }

    if (Test-DryRun) {
        Write-Note "[dry-run] 将启用 WSL 相关 Windows 功能（dism）、设置 WSL2、安装 Debian (--no-launch) 并配置系统更新 / would enable WSL Windows features, set WSL2, install Debian (--no-launch), and initialize Debian"
    }
    elseif (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
        Write-Step "启用 Windows 的 WSL 相关功能 / Enabling Windows features required for WSL"
        $wslFeatures = @(
            "Microsoft-Windows-Subsystem-Linux",
            "VirtualMachinePlatform",
            "Microsoft-Hyper-V-All"
        )
        foreach ($feature in $wslFeatures) {
            try {
                $null = Invoke-NativeQuiet -FilePath 'dism.exe' -Arguments @('/online', '/enable-feature', "/featurename:$feature", '/all', '/norestart')
                if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
                    Write-Warn "启用 Windows 功能 $feature 返回非零（退出码 $LASTEXITCODE），后续继续尝试 / Enabling Windows feature $feature returned exit $LASTEXITCODE; continuing"
                    Add-Failure "dism $feature"
                }
            }
            catch {
                Write-Warn "启用 Windows 功能 $feature 失败，后续继续尝试 / Enabling Windows feature $feature failed; continuing"
                Add-Failure "dism $feature"
            }
        }

        Write-Step "设置 WSL 默认版本为 2 / Setting WSL default version to 2"
        $null = Invoke-NativeQuiet -FilePath 'wsl.exe' -Arguments @('--set-default-version', '2')
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "设置 WSL 2 版本失败（退出码 $LASTEXITCODE），后续仍尝试安装发行版 / Failed to set WSL 2 version (exit $LASTEXITCODE), will still try installing the distro"
        }

        # wsl.exe --list 在部分环境下输出 UTF-16LE（含 NUL 字节），先清洗再精确匹配
        $distroList = @(
            Invoke-NativeQuiet -FilePath 'wsl.exe' -Arguments @('--list', '--quiet') |
                ForEach-Object { ([string]$_ -replace "\0", "").Trim() } |
                Where-Object { $_ }
        )
        if ($distroList -notcontains "Debian") {
            Write-Step "安装 Debian 发行版 / Installing Debian distro"
            $global:LASTEXITCODE = 0
            & wsl.exe @('--install', '-d', 'Debian', '--no-launch')
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "Debian 安装命令返回非零状态（退出码 $LASTEXITCODE），可能需要重启系统后再继续 / Debian install returned exit $LASTEXITCODE; a reboot may be required"
                Add-Failure "WSL Debian install"
            }
        }

        $null = Invoke-NativeQuiet -FilePath 'wsl.exe' -Arguments @('--set-default', 'Debian')
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "设置 Debian 为默认发行版失败（退出码 $LASTEXITCODE）/ Failed to set Debian as the default distro (exit $LASTEXITCODE)"
        }

        # 用户与凭据配置：严禁硬编码用户名/密码；用户名按 POSIX 规则校验；密码走 SecureString + stdin（仅新建用户时设置）
        $configureUser = $false
        $defaultUser = ''
        $defaultSecret = $null
        $userAlreadyExists = $false

        try {
            if ($Script:AutoYes) {
                if ([string]::IsNullOrWhiteSpace($env:WSL_DEFAULT_USER)) {
                    Write-Note "自动确认模式未设置 WSL_DEFAULT_USER，跳过非 root 用户与密码配置（仅执行系统更新与基础包安装）/ Auto-yes mode without WSL_DEFAULT_USER: skipping non-root user/password setup"
                }
                else {
                    $candidateUser = $env:WSL_DEFAULT_USER.Trim()
                    if ($candidateUser -cnotmatch '^[a-z_][a-z0-9_-]*$') {
                        Write-Err "WSL_DEFAULT_USER '$candidateUser' 格式非法（需匹配 ^[a-z_][a-z0-9_-]*$），跳过非 root 用户配置 / Invalid WSL_DEFAULT_USER format, skipping user setup"
                        Add-Failure "WSL user config"
                    }
                    else {
                        $null = Invoke-NativeQuiet -FilePath 'wsl.exe' -Arguments @('-d', 'Debian', '--user', 'root', '--', 'id', '-u', $candidateUser)
                        $userAlreadyExists = ($LASTEXITCODE -eq 0)
                        if (-not $userAlreadyExists -and [string]::IsNullOrEmpty($env:WSL_DEFAULT_PASSWORD)) {
                            Write-Note "自动确认模式创建新用户 '$candidateUser' 需要同时设置 WSL_DEFAULT_PASSWORD；未提供，跳过非 root 用户与密码配置 / Auto-yes mode requires WSL_DEFAULT_PASSWORD to create new user '$candidateUser'; skipping non-root user/password setup"
                        }
                        else {
                            $defaultUser = $candidateUser
                            $defaultSecret = $env:WSL_DEFAULT_PASSWORD
                            $configureUser = $true
                        }
                    }
                }
            }
            else {
                $useRoot = Confirm-YesNo -Prompt "是否直接使用 root 账户（跳过非 root 用户配置）？(y/N) / Use root account directly (skip non-root user setup)? (y/N)"
                if ($useRoot) {
                    Write-Note "将直接使用 root 账户完成 Debian 初始化 / Will initialize Debian directly with the root account"
                }
                else {
                    $enteredUser = Read-Host "请输入 Debian 默认用户名（匹配 ^[a-z_][a-z0-9_-]*$，留空跳过用户创建）/ Enter Debian default username (pattern ^[a-z_][a-z0-9_-]*$, blank to skip)"
                    $candidateUser = if ($null -eq $enteredUser) { '' } else { $enteredUser.Trim() }
                    if ([string]::IsNullOrEmpty($candidateUser)) {
                        Write-Note "未输入用户名，跳过非 root 用户配置 / No username entered, skipping non-root user setup"
                    }
                    elseif ($candidateUser -cnotmatch '^[a-z_][a-z0-9_-]*$') {
                        Write-Err "用户名 '$candidateUser' 格式非法（仅允许小写字母、数字、下划线、连字符，且以小写字母或下划线开头），跳过用户配置 / Invalid username format, skipping user setup"
                        Add-Failure "WSL user config"
                    }
                    else {
                        $null = Invoke-NativeQuiet -FilePath 'wsl.exe' -Arguments @('-d', 'Debian', '--user', 'root', '--', 'id', '-u', $candidateUser)
                        $userAlreadyExists = ($LASTEXITCODE -eq 0)
                        if ($userAlreadyExists) {
                            Write-Note "用户 '$candidateUser' 已存在，将保留现有密码并确保加入 sudo 组及写入 /etc/wsl.conf / User '$candidateUser' exists; keeping existing password"
                            $defaultUser = $candidateUser
                            $configureUser = $true
                        }
                        else {
                            $secureSecret = Read-Host -Prompt "请为新用户 '$candidateUser' 输入初始密码 / Enter initial password for new user '$candidateUser'" -AsSecureString
                            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret)
                            try {
                                $defaultSecret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
                            }
                            finally {
                                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
                            }
                            if ([string]::IsNullOrEmpty($defaultSecret) -or $defaultSecret -match '[\r\n]') {
                                Write-Err "新用户密码为空或包含非法换行符，跳过非 root 用户配置 / Password empty or contains newline, skipping user setup"
                                Add-Failure "WSL user config"
                                $defaultSecret = $null
                            }
                            else {
                                $defaultUser = $candidateUser
                                $configureUser = $true
                            }
                        }
                    }
                }
            }

            # 单引号 here-string 杜绝 PowerShell 变量插值；显式规范化 CRLF -> LF 并经 stdin 传给 sh -s
            $wslSetupScript = @'
set -eu
export DEBIAN_FRONTEND=noninteractive
target_user="${1:-}"
if [ -n "$target_user" ]; then
    if ! command -v sudo >/dev/null 2>&1; then
        apt-get update
        apt-get install -y sudo
    fi
    if id -u "$target_user" >/dev/null 2>&1; then
        echo "user exists: $target_user"
    else
        useradd -m -s /bin/bash -G sudo "$target_user"
    fi
    usermod -aG sudo "$target_user"
    if [ -f /etc/wsl.conf ]; then
        awk -v u="$target_user" '
            BEGIN { in_user=0; has_user=0; done_def=0 }
            /^\[user\][[:space:]]*$/ { in_user=1; has_user=1; print; next }
            /^\[.*\]/ {
                if (in_user && !done_def) { print "default=" u; done_def=1 }
                in_user=0; print; next
            }
            in_user && /^[[:space:]]*default[[:space:]]*=/ {
                print "default=" u; done_def=1; next
            }
            { print }
            END {
                if (in_user && !done_def) { print "default=" u }
                else if (!has_user) { print ""; print "[user]"; print "default=" u }
            }
        ' /etc/wsl.conf > /etc/wsl.conf.tmp && mv /etc/wsl.conf.tmp /etc/wsl.conf
    else
        printf '[user]\ndefault=%s\n' "$target_user" > /etc/wsl.conf
    fi
fi
apt-get update
apt-get full-upgrade -y
apt-get install -y git curl ca-certificates gnupg lsb-release
'@ -replace "\r\n", "\n"

            Write-Step "在 Debian 中初始化用户、完成系统更新并安装 Git / Initializing Debian user, applying system updates, and installing Git"
            $wslArgs = if ($configureUser) {
                @('-d', 'Debian', '--user', 'root', '--', 'sh', '-s', '--', $defaultUser)
            }
            else {
                @('-d', 'Debian', '--user', 'root', '--', 'sh', '-s')
            }
            Invoke-WslStdin -Arguments $wslArgs -InputText $wslSetupScript
            $setupExit = $LASTEXITCODE

            if ($setupExit -eq 0 -and $configureUser -and -not $userAlreadyExists -and -not [string]::IsNullOrEmpty($defaultSecret)) {
                # 仅在新建用户时通过 stdin 调用 chpasswd（凭据不进入命令行参数或脚本插值）
                Invoke-WslStdin -Arguments @('-d', 'Debian', '--user', 'root', '--', 'chpasswd') -InputText ("{0}:{1}`n" -f $defaultUser, $defaultSecret)
                if ($LASTEXITCODE -ne 0) {
                    Write-Err "设置 Debian 新用户密码失败（退出码 $LASTEXITCODE），请稍后手动在 WSL 中运行 passwd / Failed to set password for new Debian user (exit $LASTEXITCODE)"
                    Add-Failure "WSL Debian chpasswd"
                    $setupExit = $LASTEXITCODE
                }
            }

            if ($setupExit -eq 0) {
                Write-Ok "WSL2 / Debian 配置完成 / WSL2 / Debian setup completed"
            }
            else {
                Write-Err "WSL2 / Debian 配置命令返回非零状态（退出码 $setupExit），可能需要手动重试 / WSL2 / Debian setup returned exit $setupExit; manual retry may be needed"
                Add-Failure "WSL2 / Debian setup"
            }
        }
        finally {
            $defaultSecret = $null
        }
    }
    else {
        Write-Warn "当前环境无法调用 wsl.exe，跳过 WSL 配置 / Unable to invoke wsl.exe in this environment, skipping WSL setup"
    }
}
else {
    Write-Note "跳过 WSL2 / Debian 安装 / Skipping WSL2 / Debian installation"
}

Write-Header "开发工具安装完成 / Development tools installation completed"
if (-not (Test-DryRun) -and (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Note "当前已安装的开发工具 / Currently installed development tools:"
    & scoop @('list')
}

Write-FailureSummary
if ((Get-FailureCount) -gt 0) { exit 1 }
