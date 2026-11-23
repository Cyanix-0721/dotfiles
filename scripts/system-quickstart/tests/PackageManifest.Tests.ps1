# Pester 测试：Windows quickstart 包清单与 dry-run 辅助
# 运行: pwsh -Command "Invoke-Pester scripts/system-quickstart/tests/PackageManifest.Tests.ps1"
# 需 Pester 5+（CI 中安装）。

BeforeAll {
    $script:WindowsDir = Join-Path $PSScriptRoot '..' 'windows'
    $script:Common = Join-Path $script:WindowsDir '00-common.ps1'
    . $script:Common
}

Describe 'Package manifest' {
    It 'loads and has sections' {
        $manifest = Get-PackageManifest
        $manifest.Sections.Count | Should -BeGreaterThan 0
    }

    It 'every section is valid (installer scoop/winget, packages non-empty)' {
        $manifest = Get-PackageManifest
        foreach ($id in $manifest.Sections.Keys) {
            $section = $manifest.Sections[$id]
            $section.Installer | Should -BeIn @('scoop', 'winget')
            @($section.Packages).Count | Should -BeGreaterThan 0
        }
    }

    It 'Get-PackageSection returns expected counts' {
        (Get-PackageSection 'sys.term').Count | Should -Be 11
        (Get-PackageSection 'foundation.vcredist').Count | Should -Be 12
        (Get-PackageSection 'ess.games').Count | Should -Be 3
    }

    It 'Get-PackageSection keys are non-empty and unique' {
        $section = Get-PackageSection 'dev.gitTools'
        $keys = @($section.Keys)
        @($keys | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count | Should -Be 0
        ($keys | Sort-Object -Unique).Count | Should -Be $keys.Count
    }
}

Describe 'Windows script call sites' {
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

    It 'invokes Set-DryRun and Start-Log as standalone statements in 00-main.ps1' {
        $mainPath = Join-Path $script:WindowsDir '00-main.ps1'
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
    }
}

Describe 'Install helpers with Get-PackageSection (dry-run)' {
    BeforeEach {
        $Script:DryRun = $true
        $Script:Failures.Clear()
    }

    AfterEach {
        $Script:DryRun = $false
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
}

Describe 'Dry-run helpers' {
    It 'defaults to off' {
        (Test-DryRun) | Should -BeFalse
    }

    It 'enables via -DryRun switch' {
        Set-DryRun -DryRun | Out-Null
        (Test-DryRun) | Should -BeTrue
        $Script:DryRun = $false
    }
}
