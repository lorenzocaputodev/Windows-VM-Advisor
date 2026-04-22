[CmdletBinding()]
param(
    [ValidateSet('auto', 'windows', 'linux')]
    [string]$GuestPreference = 'auto',

    [ValidateSet('light', 'balanced', 'performance')]
    [string]$Mode = 'balanced',

    [ValidateSet('auto', 'vmware', 'virtualbox')]
    [string]$HypervisorPreference = 'auto',

    [string]$OutputDir = '.\Results\internal',

    [switch]$PassThru,

    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)

$paths = @(
    'src\core\util\Convert-ToRoundedGigabytes.ps1',
    'src\core\util\Test-CommandAvailable.ps1',
    'src\core\util\Write-Log.ps1',
    'src\core\util\Test-IsAdmin.ps1',
    'src\core\util\Get-SafeCimInstance.ps1',
    'src\core\util\Get-SafeCimAssociatedInstance.ps1',
    'src\core\util\Get-SafeRegistryValue.ps1',
    'src\core\util\Get-SafeRegistryItemProperties.ps1',
    'src\core\util\Get-SafeWindowsOptionalFeatureState.ps1',
    'src\core\util\Invoke-SafeNativeCommand.ps1',
    'src\core\util\Resolve-BootMode.ps1',
    'src\core\catalog\Get-IsoCatalog.ps1',
    'src\core\collectors\Get-WindowsHostInfo.ps1',
    'src\core\collectors\Get-CPUInfo.ps1',
    'src\core\collectors\Get-RAMInfo.ps1',
    'src\core\collectors\Get-DiskInfo.ps1',
    'src\core\collectors\Get-FirmwareInfo.ps1',
    'src\core\collectors\Get-TPMInfo.ps1',
    'src\core\collectors\Get-VirtualizationInfo.ps1',
    'src\core\collectors\Get-HypervisorInfo.ps1',
    'src\core\rules\Test-Windows11Suitability.ps1',
    'src\core\rules\Test-VirtualBoxSuitability.ps1',
    'src\core\rules\Test-VMwareSuitability.ps1',
    'src\core\rules\Get-AdvisorThresholds.ps1',
    'src\core\rules\Get-PreferredVMStorage.ps1',
    'src\core\rules\Get-StorageProfile.ps1',
    'src\core\rules\Get-VMReadiness.ps1',
    'src\core\rules\Get-IsoRecommendations.ps1',
    'src\core\rules\Get-Recommendation.ps1',
    'src\core\output\ConvertTo-AdvisorJson.ps1',
    'src\core\output\ConvertTo-SystemInfoText.ps1',
    'src\core\output\ConvertTo-VMReadinessText.ps1',
    'src\core\output\ConvertTo-IsoRecommendationsText.ps1',
    'src\core\output\ConvertTo-VMProfilesText.ps1',
    'src\core\output\Get-BestFitGuidance.ps1',
    'src\core\output\ConvertTo-UserConsoleSummary.ps1'
)

foreach ($relativePath in $paths) {
    . (Join-Path $projectRoot $relativePath)
}

function Write-InternalLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    if (-not $Quiet) {
        Write-Log -Message $Message -Level $Level
    }
}

Write-InternalLog -Message 'Collecting host data...'

$osInfo = Get-WindowsHostInfo
$cpuInfo = Get-CPUInfo
$ramInfo = Get-RAMInfo
$diskInfo = Get-DiskInfo
$diskInfo = Get-StorageProfile -Storage $diskInfo
$firmwareInfo = Get-FirmwareInfo
$tpmInfo = Get-TPMInfo
$virtInfo = Get-VirtualizationInfo -CPUInfo $cpuInfo
$hypervisorInfo = Get-HypervisorInfo

$hostProfile = [pscustomobject]@{
    os       = $osInfo
    cpu      = [pscustomobject]@{
        model                              = $cpuInfo.model
        manufacturer                       = $cpuInfo.manufacturer
        cores                              = $cpuInfo.cores
        threads                            = $cpuInfo.threads
        max_clock_mhz                      = $cpuInfo.max_clock_mhz
        virtualization_supported           = $virtInfo.virtualization_supported
        virtualization_enabled_in_firmware = $virtInfo.virtualization_enabled_in_firmware
        slat_supported                     = $virtInfo.slat_supported
    }
    memory   = $ramInfo
    storage  = $diskInfo
    firmware = $firmwareInfo
    security = $tpmInfo
}

$userGoal = [pscustomobject]@{
    guest_preference      = $GuestPreference
    mode                  = $Mode
    usage                 = 'general_testing'
    hypervisor_preference = $HypervisorPreference
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$resolvedOutputDir = (Resolve-Path $OutputDir).Path
$systemNotes = New-Object System.Collections.Generic.List[string]
if (-not (Test-IsAdmin)) {
    $systemNotes.Add('This run was not elevated, so some Windows feature checks may be incomplete.')
}

$systemInformation = [pscustomobject]@{
    os               = $hostProfile.os
    cpu              = $hostProfile.cpu
    memory           = $hostProfile.memory
    storage          = $hostProfile.storage
    firmware         = $hostProfile.firmware
    tpm              = [pscustomobject]@{
        present = [bool]$tpmInfo.tpm_present
        ready   = [bool]$tpmInfo.tpm_ready
        version = [string]$tpmInfo.tpm_version
    }
    hypervisors      = [pscustomobject]@{
        vmware_workstation_installed = [bool]$hypervisorInfo.vmware_workstation_installed
        virtualbox_installed         = [bool]$hypervisorInfo.virtualbox_installed
    }
    windows_features = [pscustomobject]@{
        hyperv_enabled           = [bool]$hypervisorInfo.hyperv_enabled
        memory_integrity_enabled = [bool]$hypervisorInfo.memory_integrity_enabled
        device_guard_available   = [bool]$hypervisorInfo.device_guard_available
    }
    notes            = @($systemNotes)
}

$assessment = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisorInfo -UserGoal $userGoal
$toolVersion = '1.0.0'

$report = [pscustomobject]@{
    tool_version       = $toolVersion
    generated_at       = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
    inputs             = [pscustomobject]@{
        guest_preference      = $GuestPreference
        mode                  = $Mode
        usage                 = 'general_testing'
        hypervisor_preference = $HypervisorPreference
    }
    system_information = $systemInformation
    vm_readiness       = $assessment.vm_readiness
    recommendations    = @($assessment.recommendations)
}

$detailsPath = Join-Path $resolvedOutputDir 'Details.json'
$systemInfoPath = Join-Path $resolvedOutputDir 'System-Info.txt'
$readinessPath = Join-Path $resolvedOutputDir 'VM-Readiness.txt'
$recommendationsPath = Join-Path $resolvedOutputDir 'ISO-Recommendations.txt'
$profilesPath = Join-Path $resolvedOutputDir 'VM-Profiles.txt'

$detailsText = ConvertTo-AdvisorJson -Report $report
$systemInfoText = ConvertTo-SystemInfoText -Report $report
$readinessText = ConvertTo-VMReadinessText -Report $report
$recommendationsText = ConvertTo-IsoRecommendationsText -Report $report
$profilesText = ConvertTo-VMProfilesText -Report $report

$detailsText | Set-Content -Path $detailsPath -Encoding UTF8
$systemInfoText | Set-Content -Path $systemInfoPath -Encoding UTF8
$readinessText | Set-Content -Path $readinessPath -Encoding UTF8
$recommendationsText | Set-Content -Path $recommendationsPath -Encoding UTF8
$profilesText | Set-Content -Path $profilesPath -Encoding UTF8

Write-InternalLog -Message ('Details written to {0}' -f $detailsPath)
Write-InternalLog -Message ('System information written to {0}' -f $systemInfoPath)
Write-InternalLog -Message ('VM readiness written to {0}' -f $readinessPath)
Write-InternalLog -Message ('ISO recommendations written to {0}' -f $recommendationsPath)
Write-InternalLog -Message ('VM profiles written to {0}' -f $profilesPath)

if ($PassThru) {
    return [pscustomobject]@{
        Report                  = $report
        OutputDir               = $resolvedOutputDir
        DetailsPath             = $detailsPath
        SystemInfoPath          = $systemInfoPath
        VMReadinessPath         = $readinessPath
        ISORecommendationsPath  = $recommendationsPath
        VMProfilesPath          = $profilesPath
    }
}

if (-not $Quiet) {
    return (ConvertTo-UserConsoleSummary -Report $report -ResultsPath $resolvedOutputDir)
}
