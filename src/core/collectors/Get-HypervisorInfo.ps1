function Get-HypervisorInfo {
    $vmwareInstalled = $false
    $virtualBoxInstalled = $false
    $hyperVEnabled = $false
    $memoryIntegrityEnabled = $false
    $deviceGuardAvailable = $false

    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $apps = foreach ($root in $uninstallRoots) {
        foreach ($item in @(Get-SafeRegistryItemProperties -Path $root)) {
            $item
        }
    }

    foreach ($app in @($apps)) {
        if (-not $app) {
            continue
        }

        $displayNameProperty = $app.PSObject.Properties['DisplayName']
        if (-not $displayNameProperty) {
            continue
        }

        $name = [string]$displayNameProperty.Value
        if (-not $name) {
            continue
        }
        if ($name -match 'VMware Workstation') {
            $vmwareInstalled = $true
        }
        if ($name -match 'VirtualBox') {
            $virtualBoxInstalled = $true
        }
    }

    $vmwarePathCandidates = @(
        'C:\Program Files (x86)\VMware\VMware Workstation\vmware.exe',
        'C:\Program Files\VMware\VMware Workstation\vmware.exe'
    )
    $virtualBoxPathCandidates = @(
        'C:\Program Files\Oracle\VirtualBox\VirtualBox.exe'
    )

    if (-not $vmwareInstalled) {
        $vmwareInstalled = [bool](@($vmwarePathCandidates | Where-Object { Test-Path $_ }).Count -gt 0)
    }

    if (-not $virtualBoxInstalled) {
        $virtualBoxInstalled = [bool](@($virtualBoxPathCandidates | Where-Object { Test-Path $_ }).Count -gt 0)
    }

    $hyperVEnabled = (Get-SafeWindowsOptionalFeatureState -FeatureName 'Microsoft-Hyper-V-All') -eq 'Enabled'

    try {
        $dg = Get-SafeCimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName 'Win32_DeviceGuard' -First
        if ($dg) {
            $deviceGuardAvailable = $true
            $servicesRunning = @($dg.SecurityServicesRunning)
            if ($servicesRunning.Count -eq 0) {
                $servicesRunning = @($dg.SecurityServicesConfigured)
            }
            if ($servicesRunning -contains 2) {
                $memoryIntegrityEnabled = $true
            }
        }
    }
    catch {
        $deviceGuardAvailable = $false
        $memoryIntegrityEnabled = $false
    }

    if (-not $memoryIntegrityEnabled) {
        $memoryIntegrityRegistry = Get-SafeRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name 'Enabled'
        if ($memoryIntegrityRegistry -eq 1) {
            $memoryIntegrityEnabled = $true
            $deviceGuardAvailable = $true
        }
    }

    [pscustomobject]@{
        vmware_workstation_installed = $vmwareInstalled
        virtualbox_installed         = $virtualBoxInstalled
        hyperv_enabled               = $hyperVEnabled
        memory_integrity_enabled     = $memoryIntegrityEnabled
        device_guard_available       = $deviceGuardAvailable
    }
}
