
#region conda lazy initialize
# 懒加载：仅在首次调用 conda/activate/deactivate 时才执行完整初始化，
# 避免每次启动 pwsh 都运行 conda hook（约 0.5s）拖慢启动。
If (Test-Path "C:\Users\Administrator\scoop\apps\miniconda3\current\Scripts\conda.exe") {
    $script:__CondaExe = "C:\Users\Administrator\scoop\apps\miniconda3\current\Scripts\conda.exe"
    $script:__CondaInitDone = $false

    function Initialize-Conda {
        If (-not $script:__CondaInitDone) {
            $script:__CondaInitDone = $true
            (& $script:__CondaExe "shell.powershell" "hook") | Out-String | ? { $_ } | Invoke-Expression
        }
    }

    function conda {
        Initialize-Conda
        conda @args
    }

    function activate {
        Initialize-Conda
        activate @args
    }

    function deactivate {
        Initialize-Conda
        deactivate @args
    }
}
#endregion

#region init script cache
# 静态缓存外部工具的 init / completion 脚本，避免每次启动反复拉起子进程与 IEX 解析。
# 通过解析 scoop .shim 拿到真实 exe 的路径、大小与修改时间作为缓存键，升级/降级自动重建。
$script:__PwshInitCacheDir = if ($env:LOCALAPPDATA) {
    Join-Path $env:LOCALAPPDATA 'pwsh-cache'
} else {
    Join-Path ([System.IO.Path]::GetTempPath()) 'pwsh-cache'
}

function Resolve-RealCommandPath {
    param([Parameter(Mandatory)][string]$Name)
    $cmd = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { return $null }

    $exePath = $cmd.Source
    $shimPath = [System.IO.Path]::ChangeExtension($exePath, '.shim')
    if ([System.IO.File]::Exists($shimPath)) {
        foreach ($line in [System.IO.File]::ReadLines($shimPath)) {
            if ($line -match '^\s*path\s*=\s*"?([^"\r\n]+)"?\s*$') {
                $target = $Matches[1].Trim()
                if ([System.IO.File]::Exists($target)) {
                    $exePath = $target
                }
                break
            }
        }
    }
    return $exePath
}

function Get-CachedInitScript {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$ExePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$ExtraKey = '',
        [scriptblock]$Transform
    )
    if (-not [System.IO.File]::Exists($ExePath)) { return $null }

    $fi = [System.IO.FileInfo]::new($ExePath)
    $linkTarget = $fi.ResolveLinkTarget($true)
    if ($linkTarget -is [System.IO.FileInfo]) {
        $fi = $linkTarget
    }

    $cacheKey = "# cache-key: $($fi.FullName)|$($fi.Length)|$($fi.LastWriteTimeUtc.Ticks)|$($Arguments -join ' ')"
    if ($ExtraKey) {
        $cacheKey = "$cacheKey|$ExtraKey"
    }
    $cacheFile = Join-Path $script:__PwshInitCacheDir "$Name.ps1"

    if ([System.IO.File]::Exists($cacheFile)) {
        $sr = [System.IO.StreamReader]::new($cacheFile, [System.Text.Encoding]::UTF8)
        try { $firstLine = $sr.ReadLine() } finally { $sr.Dispose() }
        if ($firstLine -eq $cacheKey) {
            return $cacheFile
        }
    }

    if (-not [System.IO.Directory]::Exists($script:__PwshInitCacheDir)) {
        [void][System.IO.Directory]::CreateDirectory($script:__PwshInitCacheDir)
    }

    $content = (& $ExePath @Arguments | Out-String)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($content)) {
        return $null
    }

    if ($Transform) {
        $content = & $Transform $content $ExePath
        if ([string]::IsNullOrWhiteSpace($content)) {
            return $null
        }
    }

    $tmpFile = Join-Path $script:__PwshInitCacheDir "$Name.$PID.$([System.Guid]::NewGuid().ToString('N')).tmp"
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($tmpFile, "$cacheKey`r`n$content", $utf8NoBom)
    try {
        [System.IO.File]::Move($tmpFile, $cacheFile, $true)
    } catch {
        Remove-Item -LiteralPath $tmpFile -ErrorAction SilentlyContinue
    }
    return $cacheFile
}
#endregion

#region fastfetch
# 不在启动时自动运行 fastfetch，仅保留 ff 别名按需调用（直指真实 exe，跳过 scoop shim）
$__ffExe = Resolve-RealCommandPath 'fastfetch'
if ($__ffExe) {
    Set-Alias -Name ff -Value $__ffExe
}
Remove-Variable -Name __ffExe -ErrorAction SilentlyContinue
#endregion

#region aliases
Set-Alias -Name c -Value Clear-Host
#endregion

#region scoop 清理
#   scc    只清下载缓存              -> scoop cache rm --all
#   scco   清缓存 + 旧版本            -> scoop cleanup --all
#   sccog  清缓存 + 旧版本（含全局）   -> scoop cleanup --all --global
# 注意：cache rm 只删下载缓存（可重新下载）；cleanup 会删除旧版本，删后无法回滚到该版本。
function Clear-ScoopCache {
    Write-Host '==> 清理 scoop 下载缓存 (scoop cache rm --all)' -ForegroundColor Cyan
    scoop cache rm --all
}
function Clear-ScoopCacheOld {
    Clear-ScoopCache
    Write-Host '==> 清理旧版本 (scoop cleanup --all)' -ForegroundColor Cyan
    scoop cleanup --all
}
function Clear-ScoopCacheOldGlobal {
    Clear-ScoopCache
    Write-Host '==> 清理旧版本 (scoop cleanup --all --global)' -ForegroundColor Cyan
    scoop cleanup --all --global
}
Set-Alias -Name scc   -Value Clear-ScoopCache
Set-Alias -Name scco  -Value Clear-ScoopCacheOld
Set-Alias -Name sccog -Value Clear-ScoopCacheOldGlobal
#endregion

#region zoxide init
$__zoxideExe = Resolve-RealCommandPath 'zoxide'
if ($__zoxideExe) {
    $__zoxideCache = Get-CachedInitScript -Name 'zoxide' -ExePath $__zoxideExe -Arguments @('init', 'powershell')
    if ($__zoxideCache) {
        . $__zoxideCache
    }
}
Remove-Variable -Name __zoxideExe, __zoxideCache -ErrorAction SilentlyContinue
#endregion

#region yazi init
function y {
    $tmp = [System.IO.Path]::GetTempFileName()
    yazi $args --cwd-file "$tmp"
    $cwd = Get-Content -Path $tmp -Encoding UTF8
    if (Test-Path -LiteralPath $cwd) {
        Set-Location -LiteralPath $cwd
    }
    Remove-Item -Path $tmp
}
#endregion

#region starship init
# 使用 --print-full-init 直接生成完整初始化脚本并静态缓存，消除默认 init 的二次进程拉起与双重 IEX；
# 同时预计算并内联 prompt --continuation（将 starship.toml 元信息并入缓存键，改配置自动刷新）。
$__starshipExe = Resolve-RealCommandPath 'starship'
if ($__starshipExe) {
    $__starshipCfgPath = if ($env:STARSHIP_CONFIG) {
        $env:STARSHIP_CONFIG
    } else {
        Join-Path $HOME '.config\starship.toml'
    }
    $__starshipExtraKey = if ([System.IO.File]::Exists($__starshipCfgPath)) {
        $__cfgFi = [System.IO.FileInfo]::new($__starshipCfgPath)
        "cont-v1|$($__cfgFi.FullName)|$($__cfgFi.Length)|$($__cfgFi.LastWriteTimeUtc.Ticks)"
    } else {
        'cont-v1|none'
    }
    $__starshipCache = Get-CachedInitScript -Name 'starship' -ExePath $__starshipExe -Arguments @('init', 'powershell', '--print-full-init') -ExtraKey $__starshipExtraKey -Transform {
        param($raw, $exePath)
        $contLines = @(& $exePath prompt --continuation 2>$null)
        if ($LASTEXITCODE -eq 0 -and $contLines.Count -gt 0) {
            $contText = [string]::Join("`n", $contLines)
            if ($contText.Length -gt 0) {
                $escaped = $contText.Replace("'", "''")
                $replacement = "Set-PSReadLineOption -ContinuationPrompt '$escaped'"
                $pattern = '(?s)Set-PSReadLineOption\s+-ContinuationPrompt\s+\(\s*Invoke-Native\s+-Executable\s+[^\r\n]+\s+-Arguments\s+@\(\s*"prompt",\s*"--continuation"\s*\)\s*\)'
                $evaluator = [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $null = $m; $replacement }
                return [regex]::Replace($raw, $pattern, $evaluator)
            }
        }
        return $raw
    }
    if ($__starshipCache) {
        . $__starshipCache
    }
}
Remove-Variable -Name __starshipExe, __starshipCfgPath, __starshipExtraKey, __cfgFi, __starshipCache -ErrorAction SilentlyContinue
#endregion

#region mise init
# 静态缓存 mise activate pwsh 的壳代码（剥离头部硬编码的当前 PATH 快照），
# 省去每次启动拉起第一次 mise.exe；保留末尾 _mise_hook 动态更新工具与环境变量。
$__miseExe = Resolve-RealCommandPath 'mise'
if ($__miseExe) {
    $__miseCache = Get-CachedInitScript -Name 'mise' -ExePath $__miseExe -Arguments @('activate', 'pwsh') -ExtraKey 'strip-preamble-v1' -Transform {
        param($raw, $exePath)
        $null = $exePath
        $anchor = '$env:MISE_SHELL = ''pwsh'''
        $idx = $raw.IndexOf($anchor, [System.StringComparison]::Ordinal)
        if ($idx -lt 0) { return $null }
        return $raw.Substring($idx)
    }
    if ($__miseCache) {
        . $__miseCache
    } else {
        (& $__miseExe activate pwsh) | Out-String | Invoke-Expression
    }
}
Remove-Variable -Name __miseExe, __miseCache -ErrorAction SilentlyContinue
#endregion

#region uv autocompletion
# 懒加载 + 静态缓存：避免每次启动生成并解析 766KB/4752 行补全脚本，首次对 uv 按 Tab 时再加载。
$script:__UvExe = Resolve-RealCommandPath 'uv'
$script:__UvCompletionLoaded = $false
if ($script:__UvExe) {
    Register-ArgumentCompleter -Native -CommandName 'uv' -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $null = $wordToComplete
        if ($script:__UvCompletionLoaded) { return }
        $script:__UvCompletionLoaded = $true

        $cacheFile = Get-CachedInitScript -Name 'uv' -ExePath $script:__UvExe -Arguments @('generate-shell-completion', 'powershell')
        if (-not $cacheFile) { return }

        . $cacheFile
        $relCursor = $cursorPosition - $commandAst.Extent.StartOffset
        ([System.Management.Automation.CommandCompletion]::CompleteInput($commandAst.Extent.Text, $relCursor, $null)).CompletionMatches
    }
}
#endregion

#region fnm init
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}
#endregion

#region dsh (npx) —— 仿 fish 的 abbr：基础 / w=web / wn=web --no-open；默认 / a=alpha / n=next 三通道
# 通道说明：不指定 tag 走 npm 的 latest 标签（当前 0.2.2-rc.1）；@next 才是眼下最高（0.2.2-rc.3）；@alpha 为 alpha 通道。
function dsh     { npx '@deepseek-ai/dsh' @args }
function dshw    { npx '@deepseek-ai/dsh' web @args }
function dshwn   { npx '@deepseek-ai/dsh' web --no-open @args }
function dsha    { npx '@deepseek-ai/dsh@alpha' @args }
function dshaw   { npx '@deepseek-ai/dsh@alpha' web @args }
function dshawn  { npx '@deepseek-ai/dsh@alpha' web --no-open @args }
function dshn    { npx '@deepseek-ai/dsh@next' @args }
function dshnw   { npx '@deepseek-ai/dsh@next' web @args }
function dshnwn  { npx '@deepseek-ai/dsh@next' web --no-open @args }
#endregion
