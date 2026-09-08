
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

#region flutter 命令适配(跨平台统一)
# 背景:mise 在 Windows 上无法为 flutter 生成可用 shim(backend 元数据把可执行
# 声明为无扩展名 bin/flutter,Windows 不可执行);pwsh 命令解析也会误选该文档文件。
# 方案:统一敲 flutter —— Windows 转调 flutter.bat,Linux/macOS 直接调 flutter。
# mise 负责版本与 SDK 路径(动态解析,升级无忧),此处仅做入口适配。
function global:flutter {
    $sdk = mise where flutter 2>$null
    if (-not $sdk) {
        throw "flutter: 未找到 mise 管理的 Flutter SDK,请先执行 mise install flutter"
    }
    if (Test-Path -LiteralPath "$sdk\bin\flutter.bat") {
        & "$sdk\bin\flutter.bat" @args
    }
    elseif (Test-Path -LiteralPath "$sdk\bin\flutter") {
        & "$sdk\bin\flutter" @args
    }
    else {
        throw "flutter: SDK 中找不到入口,请检查 $sdk"
    }
}
#endregion

#region dart 命令适配(跨平台统一)
# 与 flutter 同理:SDK 真实安装在 mise http-tarballs 缓存,installs/ 下为 symlink;
# mise activate 会把解析后的真实 bin 注入 PATH,pwsh 会误选无扩展名 dart 文档文件。
function global:dart {
    $sdk = mise where flutter 2>$null
    if (-not $sdk) {
        throw "dart: 未找到 mise 管理的 Flutter SDK(dart 随 Flutter 捆绑),请先执行 mise install flutter"
    }
    if (Test-Path -LiteralPath "$sdk\bin\dart.bat") {
        & "$sdk\bin\dart.bat" @args
    }
    elseif (Test-Path -LiteralPath "$sdk\bin\dart") {
        & "$sdk\bin\dart" @args
    }
    else {
        throw "dart: SDK 中找不到入口,请检查 $sdk"
    }
}
#endregion
