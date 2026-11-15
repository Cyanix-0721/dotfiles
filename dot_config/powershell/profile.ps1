
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

#region fastfetch
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    fastfetch
    Set-Alias -Name ff -Value fastfetch
}
#endregion

#region aliases
Set-Alias -Name c -Value Clear-Host
#endregion

#region zoxide init
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
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
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}
#endregion

#region mise init
if (Get-Command mise -ErrorAction SilentlyContinue) {
    (&mise activate pwsh) | Out-String | Invoke-Expression
}
#endregion

#region uv autocompletion
if (Get-Command uv -ErrorAction SilentlyContinue) {
    (& uv generate-shell-completion powershell) | Out-String | Invoke-Expression
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
