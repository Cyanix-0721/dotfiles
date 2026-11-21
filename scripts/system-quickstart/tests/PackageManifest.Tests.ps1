# Pester 测试：Windows quickstart 包清单与 dry-run 辅助
# 运行: pwsh -Command "Invoke-Pester scripts/system-quickstart/tests/PackageManifest.Tests.ps1"
# 需 Pester 5+（CI 中安装）。

BeforeAll {
    $script:Common = Join-Path $PSScriptRoot '..' 'windows' '00-common.ps1'
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
