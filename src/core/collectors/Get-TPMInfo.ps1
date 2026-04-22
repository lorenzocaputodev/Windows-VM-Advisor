function Get-TPMInfo {
    $present = $false
    $ready = $false
    $version = 'Unknown'

    function Get-NormalizedTpmVersion {
        param(
            [string]$Value
        )

        if (-not $Value) {
            return 'Unknown'
        }

        $normalizedValue = $Value.Trim()
        if ($normalizedValue -match '2\.0') {
            return '2.0'
        }
        if ($normalizedValue -match '1\.2') {
            return '1.2'
        }

        return $normalizedValue
    }

    if (Test-CommandAvailable -Name 'Get-Tpm') {
        try {
            $tpm = Get-Tpm -ErrorAction Stop
            if ($null -ne $tpm) {
                $present = [bool]$tpm.TpmPresent
                $ready = [bool]$tpm.TpmReady

                $version = Get-NormalizedTpmVersion -Value ([string]$tpm.SpecVersion)
                if ($version -eq 'Unknown' -and $tpm.ManufacturerVersionFull20) {
                    $version = '2.0'
                }
            }
        }
        catch {
        }
    }

    if (-not $present -or $version -eq 'Unknown' -or (-not $ready)) {
        $tpm = Get-SafeCimInstance -Namespace 'root\CIMV2\Security\MicrosoftTpm' -ClassName 'Win32_Tpm' -First
        if ($tpm) {
            $present = $true
            $enabledInitialProperty = $tpm.PSObject.Properties['IsEnabled_InitialValue']
            $enabledProperty = $tpm.PSObject.Properties['IsEnabled']
            $activatedInitialProperty = $tpm.PSObject.Properties['IsActivated_InitialValue']
            $activatedProperty = $tpm.PSObject.Properties['IsActivated']

            $isEnabled = [bool](
                $(if ($enabledInitialProperty) { $enabledInitialProperty.Value } else { $false }) -or
                $(if ($enabledProperty) { $enabledProperty.Value } else { $false })
            )
            $isActivated = [bool](
                $(if ($activatedInitialProperty) { $activatedInitialProperty.Value } else { $false }) -or
                $(if ($activatedProperty) { $activatedProperty.Value } else { $false })
            )
            if ($isEnabled -and $isActivated) {
                $ready = $true
            }

            $normalizedFallbackVersion = Get-NormalizedTpmVersion -Value ([string]$tpm.SpecVersion)
            if ($version -eq 'Unknown' -and $normalizedFallbackVersion -ne 'Unknown') {
                $version = $normalizedFallbackVersion
            }
        }
    }

    [pscustomobject]@{
        tpm_present = $present
        tpm_ready   = $ready
        tpm_version = $version
    }
}
