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

# ---------------------------------------------------------------------------
# Auto-switch Python: vfox (global) vs conda (d:\work)
# When entering d:\work, activate conda base to use miniconda's Python.
# When leaving d:\work, deactivate conda to restore vfox-managed Python.
# ---------------------------------------------------------------------------
$script:PythonEnvLastDir = $null

# Save original prompt (set by starship) and wrap it
$script:OriginalPrompt = $function:prompt
function prompt {
    $dir = (Get-Location).Path
    if ($dir -ne $script:PythonEnvLastDir) {
        $script:PythonEnvLastDir = $dir
        if ($dir -like "D:\work*") {
            # Entering d:\work → use conda
            conda activate base 2>$null
        } else {
            # Leaving d:\work → restore vfox
            if (Test-Path env:CONDA_DEFAULT_ENV) {
                conda deactivate 2>$null
            }
        }
    }
    & $script:OriginalPrompt
}

# Apply on profile load
if ((Get-Location).Path -like "D:\work*") {
    conda activate base 2>$null
}

