function Get-SafeWindowsOptionalFeatureState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName
    )

    if (Test-CommandAvailable -Name 'Get-WindowsOptionalFeature') {
        try {
            $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
        }
        catch {
            $feature = $null
        }

        if ($feature -and $feature.State) {
            return [string]$feature.State
        }
    }

    $dismOutput = Invoke-SafeNativeCommand -FilePath 'dism.exe' -Arguments @('/Online', '/Get-FeatureInfo', ("/FeatureName:{0}" -f $FeatureName))
    if ($dismOutput) {
        $stateMatch = [regex]::Match($dismOutput, '(?im)^\s*State\s*:\s*(.+?)\s*$')
        if ($stateMatch.Success) {
            $state = $stateMatch.Groups[1].Value.Trim()
            switch -Regex ($state) {
                '^Enabled' { return 'Enabled' }
                '^Disabled' { return 'Disabled' }
                '^Disable Pending' { return 'Disabled' }
                '^Enable Pending' { return 'Enabled' }
            }
        }
    }

    return 'Unknown'
}
