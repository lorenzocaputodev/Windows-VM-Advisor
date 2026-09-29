[CmdletBinding()]
param()

# Regenerates the sample outputs in examples\ from the host data recorded in examples\Details.json,
# so the samples always reflect the current rules, catalog and formatters.
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$examplesRoot = Join-Path $projectRoot 'examples'
$detailsPath = Join-Path $examplesRoot 'Details.json'

foreach ($corePath in @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src\core') -Filter '*.ps1' -File -Recurse | Sort-Object -Property FullName)) {
    . $corePath.FullName
}

$recorded = Get-Content -Raw -Encoding UTF8 -Path $detailsPath | ConvertFrom-Json
$system = $recorded.system_information

$hostProfile = [pscustomobject]@{
    os       = $system.os
    cpu      = $system.cpu
    memory   = $system.memory
    storage  = $system.storage
    firmware = $system.firmware
    security = [pscustomobject]@{
        tpm_present = [bool]$system.tpm.present
        tpm_ready   = [bool]$system.tpm.ready
        tpm_version = [string]$system.tpm.version
    }
}

$hypervisorProfile = [pscustomobject]@{
    vmware_workstation_installed = [bool]$system.hypervisors.vmware_workstation_installed
    virtualbox_installed         = [bool]$system.hypervisors.virtualbox_installed
    hyperv_enabled               = [bool]$system.windows_features.hyperv_enabled
    memory_integrity_enabled     = [bool]$system.windows_features.memory_integrity_enabled
    device_guard_available       = [bool]$system.windows_features.device_guard_available
}

$assessment = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisorProfile -UserGoal $recorded.inputs

$report = [pscustomobject]@{
    tool_version       = Get-ToolVersion
    generated_at       = $recorded.generated_at
    inputs             = $recorded.inputs
    system_information = $system
    vm_readiness       = $assessment.vm_readiness
    recommendations    = @($assessment.recommendations)
}

ConvertTo-AdvisorJson -Report $report | Set-Content -Path $detailsPath -Encoding UTF8
ConvertTo-SystemInfoText -Report $report | Set-Content -Path (Join-Path $examplesRoot 'System-Info.txt') -Encoding UTF8
ConvertTo-VMReadinessText -Report $report | Set-Content -Path (Join-Path $examplesRoot 'VM-Readiness.txt') -Encoding UTF8
ConvertTo-IsoRecommendationsText -Report $report | Set-Content -Path (Join-Path $examplesRoot 'ISO-Recommendations.txt') -Encoding UTF8
ConvertTo-VMProfilesText -Report $report | Set-Content -Path (Join-Path $examplesRoot 'VM-Profiles.txt') -Encoding UTF8

Write-Host 'Sample outputs regenerated in examples\.'
