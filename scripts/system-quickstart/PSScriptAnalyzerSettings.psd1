@{
    # Interactive CLI menus and colored terminal loggers (Write-Header / Write-Step / Write-Ok, etc.)
    # intentionally use Write-Host for colored console output rather than pipeline data.
    # Only PSAvoidUsingWriteHost is excluded; all other rules (including ParseError, Warning, and Information) remain enforced.
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
    )
}
