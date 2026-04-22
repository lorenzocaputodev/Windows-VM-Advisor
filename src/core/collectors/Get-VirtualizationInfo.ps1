function Get-VirtualizationInfo {
    param(
        [pscustomobject]$CPUInfo
    )

    $cpu = if ($CPUInfo) { $CPUInfo } else { Get-CPUInfo }
    $computerInfo = $null
    $computerSystem = $null
    $systemInfoText = $null

    function Get-ExplicitTrue {
        param($Value)

        if ($Value -is [bool]) {
            return [bool]$Value
        }

        if ($null -eq $Value) {
            return $false
        }

        $text = [string]$Value
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $false
        }

        return ($text.Trim() -match '^(?i:true|yes|enabled|present)$')
    }

    function Get-PropertyValue {
        param(
            $Object,

            [string]$Name
        )

        if ($Object -and (@($Object.PSObject.Properties.Name) -contains $Name)) {
            return $Object.$Name
        }

        return $null
    }

    function Get-MergedSignal {
        param(
            $PrimaryValue,
            $FallbackValue
        )

        if (Get-ExplicitTrue -Value $PrimaryValue) {
            return $true
        }

        if (Get-ExplicitTrue -Value $FallbackValue) {
            return $true
        }

        return $false
    }

    function Get-ActiveHypervisorEvidence {
        param(
            $ComputerSystem,
            [string]$SystemInfoText
        )

        if (Get-ExplicitTrue -Value (Get-PropertyValue -Object $ComputerSystem -Name 'HypervisorPresent')) {
            return $true
        }

        if ($SystemInfoText -and ($SystemInfoText -match '(?i)A hypervisor has been detected\.\s*Features required for Hyper-V will not be displayed\.?')) {
            return $true
        }

        return $false
    }

    $needsFallback = -not (
        (Get-ExplicitTrue -Value $cpu.virtualization_supported) -and
        (Get-ExplicitTrue -Value $cpu.virtualization_enabled_in_firmware) -and
        (Get-ExplicitTrue -Value $cpu.slat_supported)
    )

    if ($needsFallback -and (Test-CommandAvailable -Name 'Get-ComputerInfo')) {
        try {
            $computerInfo = Get-ComputerInfo -Property @(
                'HyperVRequirementVMMonitorModeExtensions',
                'HyperVRequirementVirtualizationFirmwareEnabled',
                'HyperVRequirementSecondLevelAddressTranslation'
            ) -ErrorAction Stop
        }
        catch {
            $computerInfo = $null
        }
    }

    $fallbackVmMonitorMode = Get-PropertyValue -Object $computerInfo -Name 'HyperVRequirementVMMonitorModeExtensions'
    $fallbackFirmwareEnabled = Get-PropertyValue -Object $computerInfo -Name 'HyperVRequirementVirtualizationFirmwareEnabled'
    $fallbackSlat = Get-PropertyValue -Object $computerInfo -Name 'HyperVRequirementSecondLevelAddressTranslation'

    $needsActiveHypervisorFallback = -not (
        (Get-ExplicitTrue -Value $cpu.virtualization_supported) -or
        (Get-ExplicitTrue -Value $fallbackVmMonitorMode)
    ) -or -not (
        (Get-ExplicitTrue -Value $cpu.virtualization_enabled_in_firmware) -or
        (Get-ExplicitTrue -Value $fallbackFirmwareEnabled)
    )

    if ($needsActiveHypervisorFallback) {
        $computerSystem = Get-SafeCimInstance -ClassName 'Win32_ComputerSystem' -First
        if (-not (Get-ExplicitTrue -Value (Get-PropertyValue -Object $computerSystem -Name 'HypervisorPresent'))) {
            $systemInfoText = Invoke-SafeNativeCommand -FilePath 'systeminfo'
        }
    }

    $activeHypervisorDetected = Get-ActiveHypervisorEvidence -ComputerSystem $computerSystem -SystemInfoText $systemInfoText

    [pscustomobject]@{
        virtualization_supported           = (Get-MergedSignal -PrimaryValue $cpu.virtualization_supported -FallbackValue $fallbackVmMonitorMode) -or $activeHypervisorDetected
        virtualization_enabled_in_firmware = (Get-MergedSignal -PrimaryValue $cpu.virtualization_enabled_in_firmware -FallbackValue $fallbackFirmwareEnabled) -or $activeHypervisorDetected
        slat_supported                     = Get-MergedSignal -PrimaryValue $cpu.slat_supported -FallbackValue $fallbackSlat
    }
}
