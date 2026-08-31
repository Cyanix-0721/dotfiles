
#region conda lazy initialize
# 懒加载：仅在首次调用 conda/activate/deactivate 时才执行完整初始化，
# 避免每次启动 pwsh 都运行 conda hook（约 0.5s）拖慢启动。
If (Test-Path "C:\Users\Administrator\scoop\apps\miniconda3\current\Scripts\conda.exe") {
    $script:__CondaExe = "C:\Users\Administrator\scoop\apps\miniconda3\current\Scripts\conda.exe"
    $script:__CondaInitDone = $false

    function Initialize-Conda {
        If (-not $script:__CondaInitDone) {
            $script:__CondaInitDone = $true
            (& $script:__CondaExe "shell.powershell" "hook") | Out-String | ?{ $_ } | Invoke-Expression
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
}
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

#region vfox init
if (Get-Command vfox -ErrorAction SilentlyContinue) {
    Invoke-Expression "$(vfox activate pwsh)"
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
