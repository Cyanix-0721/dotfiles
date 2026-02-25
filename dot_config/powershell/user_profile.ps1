# starship
Invoke-Expression (&starship init powershell)
# vfox
Invoke-Expression "$(vfox activate pwsh)"
# zoxide
Invoke-Expression (& { (zoxide init powershell | Out-String) })
# yazi
$env:YAZI_CONFIG_HOME = "$HOME\.config\yazi"
function y {
    $tmp = (New-TemporaryFile).FullName
    yazi $args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -Encoding UTF8
    if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
        Set-Location -LiteralPath (Resolve-Path -LiteralPath $cwd).Path
    }
    Remove-Item -Path $tmp
}

# gsudo
Import-Module gsudoModule -Force

#region conda initialize
# !! Contents within this block are managed by 'conda init' !!
If (Test-Path "C:\Users\Administrator\scoop\apps\miniconda3\current\Scripts\conda.exe") {
    (& "C:\Users\Administrator\scoop\apps\miniconda3\current\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression
}
#endregion

