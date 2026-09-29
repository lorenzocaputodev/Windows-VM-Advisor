@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Console tool: Write-Host is the intended output channel for Write-Log.
        'PSAvoidUsingWriteHost',
        # Internal helper names follow the project's own convention.
        'PSUseSingularNouns',
        'PSUseShouldProcessForStateChangingFunctions',
        # WMI cmdlets are an intentional fallback when CIM is unavailable.
        'PSAvoidUsingWMICmdlet'
    )
}
