$ErrorActionPreference = 'Stop'

$projectRoot = Join-Path $PSScriptRoot '..'
$schemaPath = Join-Path $projectRoot 'schemas\advisor-report.schema.json'
$detailsPath = Join-Path $projectRoot 'examples\Details.json'
$requiredTextFiles = @(
    'System-Info.txt',
    'VM-Readiness.txt',
    'ISO-Recommendations.txt',
    'VM-Profiles.txt'
)

if (-not (Test-Path $schemaPath)) {
    throw 'Schema file not found.'
}

if (-not (Test-Path $detailsPath)) {
    throw 'Sample details report not found.'
}

foreach ($fileName in $requiredTextFiles) {
    $path = Join-Path $projectRoot ('examples\{0}' -f $fileName)
    if (-not (Test-Path $path)) {
        throw ('Expected example file was not found: {0}' -f $fileName)
    }
}

$content = Get-Content -Raw $detailsPath | ConvertFrom-Json

function Assert-HasProperties {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Object,

        [Parameter(Mandatory = $true)]
        [string[]]$Properties,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $available = @($Object.PSObject.Properties.Name)
    foreach ($property in $Properties) {
        if ($available -notcontains $property) {
            throw ('Missing required property: {0}.{1}' -f $Path, $property)
        }
    }
}

function Assert-IsArray {
    param(
        [Parameter(Mandatory = $true)]
        $Value,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($Value -isnot [System.Array]) {
        throw ('Expected array value at {0}' -f $Path)
    }
}

Assert-HasProperties -Object $content -Properties @('tool_version', 'generated_at', 'inputs', 'system_information', 'vm_readiness', 'recommendations') -Path 'report'
Assert-HasProperties -Object $content.inputs -Properties @('guest_preference', 'mode', 'usage', 'hypervisor_preference') -Path 'inputs'
Assert-HasProperties -Object $content.system_information -Properties @('os', 'cpu', 'memory', 'storage', 'firmware', 'tpm', 'hypervisors', 'windows_features', 'notes') -Path 'system_information'
Assert-HasProperties -Object $content.system_information.os -Properties @('name', 'version', 'build', 'architecture') -Path 'system_information.os'
Assert-HasProperties -Object $content.system_information.cpu -Properties @('model', 'manufacturer', 'cores', 'threads', 'max_clock_mhz', 'virtualization_supported', 'virtualization_enabled_in_firmware', 'slat_supported') -Path 'system_information.cpu'
Assert-HasProperties -Object $content.system_information.memory -Properties @('total_gb', 'free_gb', 'module_count') -Path 'system_information.memory'
Assert-HasProperties -Object $content.system_information.storage -Properties @('system_drive', 'system_drive_fs', 'system_drive_total_gb', 'system_drive_free_gb', 'physical_media_hint', 'drives', 'preferred_vm_storage') -Path 'system_information.storage'
Assert-HasProperties -Object $content.system_information.firmware -Properties @('boot_mode', 'secure_boot') -Path 'system_information.firmware'
Assert-HasProperties -Object $content.system_information.tpm -Properties @('present', 'ready', 'version') -Path 'system_information.tpm'
Assert-HasProperties -Object $content.system_information.hypervisors -Properties @('vmware_workstation_installed', 'virtualbox_installed') -Path 'system_information.hypervisors'
Assert-HasProperties -Object $content.system_information.windows_features -Properties @('hyperv_enabled', 'memory_integrity_enabled', 'device_guard_available') -Path 'system_information.windows_features'
Assert-HasProperties -Object $content.vm_readiness -Properties @('state', 'takeaway', 'headline', 'primary_reason', 'blockers', 'limitations', 'checks') -Path 'vm_readiness'

Assert-IsArray -Value $content.system_information.notes -Path 'system_information.notes'
Assert-IsArray -Value $content.system_information.storage.drives -Path 'system_information.storage.drives'
Assert-IsArray -Value $content.vm_readiness.blockers -Path 'vm_readiness.blockers'
Assert-IsArray -Value $content.vm_readiness.limitations -Path 'vm_readiness.limitations'
Assert-IsArray -Value $content.vm_readiness.checks -Path 'vm_readiness.checks'
Assert-IsArray -Value $content.recommendations -Path 'recommendations'

$validStates = @('ok', 'limited', 'not_ready')
if ($validStates -notcontains [string]$content.vm_readiness.state) {
    throw ('Invalid readiness state: {0}' -f $content.vm_readiness.state)
}

foreach ($drive in @($content.system_information.storage.drives)) {
    Assert-HasProperties -Object $drive -Properties @('drive_letter', 'is_system_drive', 'filesystem', 'total_gb', 'free_gb', 'storage_type_hint', 'vm_storage_suitable') -Path 'system_information.storage.drives[]'
}

if ($null -ne $content.system_information.storage.preferred_vm_storage) {
    Assert-HasProperties -Object $content.system_information.storage.preferred_vm_storage -Properties @('drive_letter', 'is_system_drive', 'filesystem', 'total_gb', 'free_gb', 'storage_type_hint', 'vm_storage_suitable') -Path 'system_information.storage.preferred_vm_storage'
}

foreach ($check in @($content.vm_readiness.checks)) {
    Assert-HasProperties -Object $check -Properties @('id', 'label', 'status', 'details') -Path 'vm_readiness.checks[]'
}

foreach ($recommendation in @($content.recommendations)) {
    Assert-HasProperties -Object $recommendation -Properties @('id', 'display_name', 'family', 'flavor', 'category', 'architecture', 'official_download_page', 'official_release_page', 'compatibility_label', 'fit_reason', 'preferred_hypervisor', 'vm_profile', 'notes') -Path 'recommendations[]'
    Assert-IsArray -Value $recommendation.notes -Path 'recommendations[].notes'

    if (@($recommendation.PSObject.Properties.Name) -contains 'score') {
        throw 'Public recommendation entries must not expose raw score values.'
    }

    if ($recommendation.compatibility_label -ne 'not_recommended') {
        if ($null -eq $recommendation.vm_profile) {
            throw ('Expected a VM profile for recommendation {0}' -f $recommendation.display_name)
        }

        Assert-HasProperties -Object $recommendation.vm_profile -Properties @('vcpu', 'memory_mb', 'disk_gb', 'firmware', 'secure_boot', 'tpm', 'network', 'storage_location') -Path 'recommendations[].vm_profile'
    }
}

Write-Host 'Example Details.json and text outputs match the documented product contract.'
