$script:ProjectRoot = Split-Path -Parent $PSScriptRoot

function Get-AdvisorRulePaths {
    return @(
        'src\core\catalog\Get-IsoCatalog.ps1',
        'src\core\rules\Get-AdvisorThresholds.ps1',
        'src\core\rules\Get-PreferredVMStorage.ps1',
        'src\core\rules\Get-StorageProfile.ps1',
        'src\core\rules\Test-Windows11Suitability.ps1',
        'src\core\rules\Test-VirtualBoxSuitability.ps1',
        'src\core\rules\Test-VMwareSuitability.ps1',
        'src\core\util\Resolve-BootMode.ps1',
        'src\core\rules\Get-VMReadiness.ps1',
        'src\core\rules\Get-IsoRecommendations.ps1',
        'src\core\rules\Get-Recommendation.ps1'
    )
}

function Get-HostFixture {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $path = Join-Path $PSScriptRoot ('fixtures\{0}.json' -f $Name)
    return (Get-Content -Raw $path | ConvertFrom-Json)
}

function New-HypervisorProfile {
    param(
        [bool]$VmwareInstalled = $false,
        [bool]$VirtualBoxInstalled = $false,
        [bool]$HyperVEnabled = $false,
        [bool]$MemoryIntegrityEnabled = $false,
        [bool]$DeviceGuardAvailable = $true
    )

    return [pscustomobject]@{
        vmware_workstation_installed = $VmwareInstalled
        virtualbox_installed         = $VirtualBoxInstalled
        hyperv_enabled               = $HyperVEnabled
        memory_integrity_enabled     = $MemoryIntegrityEnabled
        device_guard_available       = $DeviceGuardAvailable
    }
}

function New-UserGoal {
    param(
        [ValidateSet('auto', 'windows', 'linux')]
        [string]$GuestPreference = 'auto',

        [ValidateSet('light', 'balanced', 'performance')]
        [string]$Mode = 'balanced',

        [ValidateSet('auto', 'vmware', 'virtualbox')]
        [string]$HypervisorPreference = 'auto'
    )

    return [pscustomobject]@{
        guest_preference      = $GuestPreference
        mode                  = $Mode
        usage                 = 'general_testing'
        hypervisor_preference = $HypervisorPreference
    }
}
