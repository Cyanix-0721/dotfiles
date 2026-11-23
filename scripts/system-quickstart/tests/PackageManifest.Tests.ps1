# Pester 测试：Windows quickstart 包清单、公共函数与脚本健壮性
# 运行: pwsh -Command "Import-Module Pester -MinimumVersion 5.0.0; Invoke-Pester -Path scripts/system-quickstart/tests/PackageManifest.Tests.ps1 -PassThru -Output Detailed"
# 需 Pester 5+（CI 中安装）。

BeforeAll {
    $script:WindowsDir = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'windows'
    $script:Common = Join-Path -Path $script:WindowsDir -ChildPath '00-common.ps1'
    . $script:Common
}

Describe 'Package manifest' {
    It 'loads and has all 33 sections' {
        $manifest = Get-PackageManifest
        $manifest.Sections.Count | Should -Be 33
    }

    It 'every section is valid (installer scoop/winget, non-empty unique keys, valid schema)' {
        $manifest = Get-PackageManifest
        foreach ($id in $manifest.Sections.Keys) {
            $section = $manifest.Sections[$id]
            $section.Installer | Should -BeIn @('scoop', 'winget')
            @($section.Packages).Count | Should -BeGreaterThan 0

            $resolved = Get-PackageSection -Id $id
            $keys = @($resolved.Keys)
            $keys.Count | Should -Be @($section.Packages).Count
            @($keys | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count | Should -Be 0
            ($keys | Sort-Object -Unique).Count | Should -Be $keys.Count
            foreach ($k in $keys) {
                [string]::IsNullOrWhiteSpace($resolved[$k].Desc) | Should -BeFalse -Because "section '$id' entry '$k' must have a non-empty Desc"
            }
        }
    }

    It 'Get-PackageSection returns expected counts' {
        (Get-PackageSection 'sys.term').Count | Should -Be 11
        (Get-PackageSection 'foundation.vcredist').Count | Should -Be 12
        (Get-PackageSection 'ess.games').Count | Should -Be 3
    }

    It 'marks ess.games entries as Default = $false' {
        $games = Get-PackageSection 'ess.games'
        foreach ($entry in $games.GetEnumerator()) {
            $entry.Value.ContainsKey('Default') | Should -BeTrue
            $entry.Value.Default | Should -BeFalse
        }
    }

    It 'rejects duplicate keys, rejects unknown keys, and defaults missing Desc to key' {
        $savedManifest = $Script:PackageManifest
        try {
            $Script:PackageManifest = @{
                Sections = @{
                    'test.dup'     = @{
                        Installer = 'scoop'
                        Packages  = @(
                            @{ Name = 'git'; Desc = 'Git' }
                            @{ Name = 'git'; Desc = 'Git dup' }
                        )
                    }
                    'test.unknown' = @{
                        Installer = 'scoop'
                        Packages  = @(
                            @{ Name = 'git'; Desc = 'Git'; BogusField = 123 }
                        )
                    }
                    'test.nodesc'  = @{
                        Installer = 'winget'
                        Packages  = @(
                            @{ Id = 'Vendor.App' }
                        )
                    }
                }
            }

            { Get-PackageSection 'test.dup' } | Should -Throw '*Duplicate*'
            { Get-PackageSection 'test.unknown' } | Should -Throw '*Unknown*'

            $noDesc = Get-PackageSection 'test.nodesc'
            $noDesc['Vendor.App'].Desc | Should -Be 'Vendor.App'
        }
        finally {
            $Script:PackageManifest = $savedManifest
        }
    }
}

Describe 'CommonLoaded re-sourcing guard' {
    It 'does not reset state when 00-common.ps1 is dot-sourced again' {
        $prevDryRun = $Script:DryRun
        try {
            $Script:DryRun = $true
            $Script:Failures.Clear()
            Add-Failure 'keep-me'

            . $script:Common

            (Test-DryRun) | Should -BeTrue
            (Get-FailureCount) | Should -Be 1
        }
        finally {
            $Script:DryRun = $prevDryRun
            $Script:Failures.Clear()
        }
    }
}

Describe 'Confirm-YesNo / Confirm-Install / Read-Choice / Initialize-AutoYes' {
    BeforeEach {
        $Script:AutoYes = $false
        $script:SavedEnvQuickAutoYes = $env:QUICKSTART_AUTO_YES
        $script:SavedEnvAutoYes = $env:AUTO_YES
        $script:SavedEnvNoPrompt = $env:QUICKSTART_NO_AUTO_YES_PROMPT
        $env:QUICKSTART_AUTO_YES = $null
        $env:AUTO_YES = $null
        $env:QUICKSTART_NO_AUTO_YES_PROMPT = $null
    }

    AfterEach {
        $Script:AutoYes = $false
        $env:QUICKSTART_AUTO_YES = $script:SavedEnvQuickAutoYes
        $env:AUTO_YES = $script:SavedEnvAutoYes
        $env:QUICKSTART_NO_AUTO_YES_PROMPT = $script:SavedEnvNoPrompt
    }

    It 'auto-confirms DefaultYes=$true and skips DefaultYes=$false under $Script:AutoYes' {
        $Script:AutoYes = $true
        Confirm-Install -Prompt 'Install foo?' -DefaultYes | Should -Be 'Y'
        Confirm-Install -Prompt 'Install bar?' | Should -Be 'N'
        Confirm-YesNo -Prompt 'Install foo?' -DefaultYes | Should -BeTrue
        Confirm-YesNo -Prompt 'Install bar?' | Should -BeFalse
    }

    It 'parses yes/no/empty consistently in interactive mode' {
        Mock Read-Host { 'no' }
        Confirm-YesNo -Prompt 'Install foo? (Y/n)' -DefaultYes | Should -BeFalse

        Mock Read-Host { 'yes' }
        Confirm-YesNo -Prompt 'Install bar? (y/N)' | Should -BeTrue

        Mock Read-Host { '' }
        Confirm-YesNo -Prompt 'Install foo? (Y/n)' -DefaultYes | Should -BeTrue
        Confirm-YesNo -Prompt 'Install bar? (y/N)' | Should -BeFalse
    }

    It 'Read-Choice returns default under $Script:AutoYes without calling Read-Host' {
        $Script:AutoYes = $true
        Mock Read-Host { throw 'Read-Host should not be called' }
        Read-Choice -Prompt 'Pick one' -Default '1' | Should -Be '1'
        Should -Invoke Read-Host -Times 0
    }

    It 'Initialize-AutoYes honors QUICKSTART_AUTO_YES, AUTO_YES, and -NoPrompt' {
        Mock Write-Note {}
        Mock Read-Host { throw 'Read-Host should not be called' }

        $env:QUICKSTART_AUTO_YES = '1'
        Initialize-AutoYes
        $Script:AutoYes | Should -BeTrue

        $Script:AutoYes = $false
        $env:QUICKSTART_AUTO_YES = $null
        $env:AUTO_YES = '1'
        Initialize-AutoYes
        $Script:AutoYes | Should -BeTrue

        $Script:AutoYes = $false
        $env:AUTO_YES = $null
        Initialize-AutoYes -NoPrompt
        $Script:AutoYes | Should -BeFalse
        Should -Invoke Read-Host -Times 0
    }
}

Describe 'Failure tracking helpers' {
    BeforeEach {
        $Script:Failures.Clear()
    }

    AfterEach {
        $Script:Failures.Clear()
    }

    It 'deduplicates failures and summarizes both empty and non-empty states' {
        Mock Write-Ok {}
        Mock Write-Warn {}
        Mock Write-Note {}

        Get-FailureCount | Should -Be 0
        Write-FailureSummary
        Should -Invoke Write-Ok -Times 1

        Add-Failure 'pkg-a'
        Add-Failure 'pkg-a'
        Add-Failure 'pkg-b'
        Get-FailureCount | Should -Be 2

        Write-FailureSummary
        Should -Invoke Write-Warn -Times 1
        Should -Invoke Write-Note -Times 2
    }
}

Describe 'Dry-run and logging helpers' {
    BeforeEach {
        $Script:DryRun = $false
        $Script:LogFile = $null
        $script:SavedEnvDryRun = $env:QUICKSTART_DRY_RUN
        $script:SavedEnvLogFile = $env:QUICKSTART_LOG_FILE
        $env:QUICKSTART_DRY_RUN = $null
        $env:QUICKSTART_LOG_FILE = $null
    }

    AfterEach {
        $Script:DryRun = $false
        $Script:LogFile = $null
        $env:QUICKSTART_DRY_RUN = $script:SavedEnvDryRun
        $env:QUICKSTART_LOG_FILE = $script:SavedEnvLogFile
    }

    It 'defaults to off' {
        (Test-DryRun) | Should -BeFalse
    }

    It 'enables via -DryRun switch and QUICKSTART_DRY_RUN=1' {
        Set-DryRun -DryRun | Out-Null
        (Test-DryRun) | Should -BeTrue

        $Script:DryRun = $false
        $env:QUICKSTART_DRY_RUN = '1'
        Set-DryRun | Out-Null
        (Test-DryRun) | Should -BeTrue
    }

    It 'Start-Log skips creating log file in dry-run' {
        Mock Write-Note {}
        $tmpLog = Join-Path ([System.IO.Path]::GetTempPath()) ("quickstart-test-dryrun-{0}.log" -f [guid]::NewGuid().ToString('N'))
        try {
            Set-DryRun -DryRun | Out-Null
            Start-Log -Path $tmpLog
            Test-Path -LiteralPath $tmpLog | Should -BeFalse
            $Script:LogFile | Should -BeNullOrEmpty
        }
        finally {
            if (Test-Path -LiteralPath $tmpLog) { Remove-Item -LiteralPath $tmpLog -Force }
        }
    }

    It 'Start-Log creates and reuses existing log file without overwriting' {
        Mock Write-Note {}
        $tmpLog = Join-Path ([System.IO.Path]::GetTempPath()) ("quickstart-test-reuse-{0}.log" -f [guid]::NewGuid().ToString('N'))
        try {
            Start-Log -Path $tmpLog
            Test-Path -LiteralPath $tmpLog | Should -BeTrue
            Write-LogLine 'parent-entry'

            $env:QUICKSTART_LOG_FILE = $tmpLog
            $Script:LogFile = $null
            Start-Log
            Write-LogLine 'child-entry'

            $content = Get-Content -LiteralPath $tmpLog -Raw
            $content | Should -Match 'parent-entry'
            $content | Should -Match 'child-entry'
        }
        finally {
            if (Test-Path -LiteralPath $tmpLog) { Remove-Item -LiteralPath $tmpLog -Force }
        }
    }

    It 'Invoke-External and Invoke-WingetInstall do not run commands in dry-run' {
        Mock Write-Note {}
        Set-DryRun -DryRun | Out-Null

        { Invoke-External -FilePath 'nonexistent-binary-for-dryrun-test' -Arguments @('--version') -Description 'test' } | Should -Not -Throw
        { Invoke-WingetInstall -Id 'Vendor.NonexistentApp' } | Should -Not -Throw
        Should -Invoke Write-Note -Times 2 -ParameterFilter { $Message.StartsWith('[dry-run]') }
    }
}

Describe 'Install helpers with Get-PackageSection (dry-run & exit handling)' {
    BeforeEach {
        $Script:DryRun = $true
        $Script:AutoYes = $false
        $Script:Failures.Clear()
    }

    AfterEach {
        $Script:DryRun = $false
        $Script:AutoYes = $false
        $Script:Failures.Clear()
    }

    It 'Install-ScoopPackages accepts Get-PackageSection directly in dry-run' {
        Mock Test-ScoopInstalled { $false }
        Mock Confirm-Install { 'Y' }
        Mock Write-Note {}

        $section = Get-PackageSection 'dev.editors'
        { Install-ScoopPackages $section } | Should -Not -Throw
        Should -Invoke Write-Note -Times $section.Count -ParameterFilter { $Message.StartsWith('[dry-run]') }
    }

    It 'Install-WingetApps accepts Get-PackageSection directly in dry-run' {
        Mock Test-WingetInstalled { $false }
        Mock Write-Note {}

        $section = Get-PackageSection 'foundation.webview2'
        { Install-WingetApps $section -Force } | Should -Not -Throw
        Should -Invoke Write-Note -Times $section.Count -ParameterFilter { $Message.StartsWith('[dry-run]') }
    }

    It 'Install-WingetApps skips ess.games under $Script:AutoYes without -Force' {
        $Script:AutoYes = $true
        Mock Test-WingetInstalled { $false }
        Mock Write-Note {}

        $section = Get-PackageSection 'ess.games'
        { Install-WingetApps $section } | Should -Not -Throw
        Should -Invoke Write-Note -Times 0 -ParameterFilter { $Message.StartsWith('[dry-run]') }
    }

    It 'Install-WingetApp treats exit code 3010 as reboot warning, not failure' {
        $Script:DryRun = $false
        Mock Test-WingetInstalled { $false }
        Mock Write-Step {}
        Mock Write-Warn {}
        Mock Write-Err {}
        Mock Invoke-WingetInstall { $global:LASTEXITCODE = 3010 }

        Install-WingetApp -Id 'Vendor.RebootApp' -Desc 'Reboot App' -Force
        (Get-FailureCount) | Should -Be 0
        Should -Invoke Write-Warn -Times 1 -ParameterFilter { $Message -match '3010' }
        Should -Invoke Write-Err -Times 0
    }

    It 'Install-ScoopPackage emits PostNote only on exit code 0' {
        $Script:DryRun = $false
        Mock Test-ScoopInstalled { $false }
        Mock Confirm-YesNo { $true }
        Mock Reset-ScoopCache {}
        Mock Write-Ok {}
        Mock Write-Err {}
        Mock Write-Note {}
        function scoop { $global:LASTEXITCODE = 1 }
        try {
            Install-ScoopPackage -Name 'fake-pkg' -Desc 'Fake Pkg' -DefaultYes -PostNote @('should-not-appear')
            (Get-FailureCount) | Should -Be 1
            Should -Invoke Write-Note -Times 0 -ParameterFilter { $Message -eq 'should-not-appear' }
        }
        finally {
            Remove-Item -Path Function:\scoop -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Windows script AST and static safety checks' {
    It 'all Windows scripts parse with zero syntax errors' {
        $scripts = Get-ChildItem -Path $script:WindowsDir -Filter '*.ps1'
        $scripts.Count | Should -BeGreaterThan 0
        foreach ($file in $scripts) {
            $tokens = $null
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
            $errors.Count | Should -Be 0 -Because "$($file.Name) must have zero syntax errors"
        }
    }

    It 'never accesses .Packages on Get-PackageSection return value' {
        $scripts = Get-ChildItem -Path (Join-Path $script:WindowsDir '0[1-4]-*.ps1')
        $scripts.Count | Should -BeGreaterThan 0

        $badCalls = @()
        foreach ($file in $scripts) {
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
            $errors.Count | Should -Be 0

            $memberAccesses = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.MemberExpressionAst] -and
                $node.Expression.Extent.Text -match '\bGet-PackageSection\b'
            }, $true)

            foreach ($m in $memberAccesses) {
                $badCalls += "$($file.Name):$($m.Extent.StartLineNumber) -> $($m.Extent.Text)"
            }
        }
        $badCalls | Should -BeNullOrEmpty
    }

    It 'uses valid section IDs matching Install-ScoopPackages / Install-WingetApps' {
        $manifest = Get-PackageManifest
        $scripts = Get-ChildItem -Path (Join-Path $script:WindowsDir '0[1-4]-*.ps1')
        $matchedCalls = 0

        foreach ($file in $scripts) {
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)

            $installCalls = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -in @('Install-ScoopPackages', 'Install-WingetApps')
            }, $true)

            foreach ($call in $installCalls) {
                $getSectionCmd = $call.Find({
                    param($n)
                    $n -is [System.Management.Automation.Language.CommandAst] -and
                    $n.GetCommandName() -eq 'Get-PackageSection'
                }, $true)
                if (-not $getSectionCmd) { continue }

                $matchedCalls++
                $sectionId = $getSectionCmd.CommandElements[1].Value
                $manifest.Sections.ContainsKey($sectionId) | Should -BeTrue -Because "$($file.Name):$($call.Extent.StartLineNumber) references '$sectionId'"

                $expectedInstaller = if ($call.GetCommandName() -eq 'Install-ScoopPackages') { 'scoop' } else { 'winget' }
                $manifest.Sections[$sectionId].Installer | Should -Be $expectedInstaller -Because "$($file.Name):$($call.Extent.StartLineNumber) uses $($call.GetCommandName()) for '$sectionId'"
            }
        }
        $matchedCalls | Should -BeGreaterThan 0
    }

    It '00-main.ps1 invokes Set-DryRun/Start-Log, has -AutoYes, avoids hardcoded glob, and accepts empty input' {
        $mainPath = Join-Path $script:WindowsDir '00-main.ps1'
        $raw = Get-Content -LiteralPath $mainPath -Raw
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($mainPath, [ref]$tokens, [ref]$errors)
        $errors.Count | Should -Be 0

        $dotSourceCmd = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Dot
        }, $true)
        $dotSourceCmd | Should -Not -BeNullOrEmpty
        $dotSourceCmd.CommandElements.Count | Should -Be 1

        $commandNames = @(
            $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst]
            }, $true) | ForEach-Object { $_.GetCommandName() }
        )
        $commandNames | Should -Contain 'Set-DryRun'
        $commandNames | Should -Contain 'Start-Log'

        $paramNames = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
        $paramNames | Should -Contain 'DryRun'
        $paramNames | Should -Contain 'AutoYes'

        $raw | Should -Not -Match '0\[1-5\]-\*\.ps1'
        $raw | Should -Match 'AllowEmptyString'
        $raw | Should -Match 'finally\s*\{'
        $raw | Should -Match '\$LASTEXITCODE'
    }

    It '02-development-tools.ps1 has no hardcoded credentials, normalizes LF, and avoids multi-arg uv tool install' {
        $devPath = Join-Path $script:WindowsDir '02-development-tools.ps1'
        $raw = Get-Content -LiteralPath $devPath -Raw

        $raw | Should -Not -Match '\bslayer\b'
        $raw | Should -Not -Match '114514'
        $raw | Should -Match '-AsSecureString'
        $raw | Should -Match '\\r\\n'
        $raw | Should -Match 'DoNotExpandEnvironmentNames'
        $raw | Should -Not -Match 'uv\s+tool\s+install\s+copyparty\s+ruff'
    }

    It '01-system-foundation.ps1 does not use Invoke-Expression and supports Scoop -RunAsAdmin' {
        $fndPath = Join-Path $script:WindowsDir '01-system-foundation.ps1'
        $raw = Get-Content -LiteralPath $fndPath -Raw
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($fndPath, [ref]$tokens, [ref]$errors)
        $errors.Count | Should -Be 0

        $iexCmds = @(
            $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -in @('Invoke-Expression', 'iex')
            }, $true)
        )
        $iexCmds.Count | Should -Be 0
        $raw | Should -Match '-RunAsAdmin'
    }

    It '03-system-tools.ps1 and 04-essential-packages.ps1 do not pass -Force on OpenHashTab, OpenSSH, or ess.games' {
        $sysRaw = Get-Content -LiteralPath (Join-Path $script:WindowsDir '03-system-tools.ps1') -Raw
        $essRaw = Get-Content -LiteralPath (Join-Path $script:WindowsDir '04-essential-packages.ps1') -Raw

        $sysRaw | Should -Not -Match "Get-PackageSection 'sys\.openHashTab'\)\s*-Force"
        $sysRaw | Should -Not -Match "Get-PackageSection 'sys\.openSsh'\)\s*-Force"
        $essRaw | Should -Not -Match "Get-PackageSection 'ess\.games'\)\s*-Force"
    }
}
