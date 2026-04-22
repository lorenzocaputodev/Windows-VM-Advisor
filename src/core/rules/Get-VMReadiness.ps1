function Get-VMReadiness {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$HostProfile,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$HypervisorProfile
    )

    $thresholds = Get-AdvisorThresholds
    $storage = $HostProfile.storage
    $preferredStorage = $storage.preferred_vm_storage
    $blockers = New-Object System.Collections.ArrayList
    $limitations = New-Object System.Collections.ArrayList
    $checks = New-Object System.Collections.ArrayList
    $freeMemoryLimitationText = 'Host free RAM is low. Close other applications before starting a VM.'
    $hasTpm20 = [bool](
        $HostProfile.security.tpm_present -and
        $HostProfile.security.tpm_ready -and
        ($HostProfile.security.tpm_version -match '2\.0')
    )

    function Add-UniqueText {
        param(
            [Parameter(Mandatory = $true)]
            $List,

            [Parameter(Mandatory = $true)]
            [string]$Text
        )

        if ($Text -and -not $List.Contains($Text)) {
            [void]$List.Add($Text)
        }
    }

    function Add-Check {
        param(
            [string]$Id,
            [string]$Label,
            [string]$Status,
            [string]$Details
        )

        [void]$checks.Add([pscustomobject]@{
            id      = $Id
            label   = $Label
            status  = $Status
            details = $Details
        })
    }

    if ($HostProfile.cpu.virtualization_supported) {
        Add-Check -Id 'hardware-virtualization' -Label 'CPU virtualization support' -Status 'ok' -Details 'Hardware virtualization extensions were detected.'
    }
    else {
        Add-UniqueText -List $blockers -Text 'CPU virtualization support was not detected.'
        Add-Check -Id 'hardware-virtualization' -Label 'CPU virtualization support' -Status 'blocked' -Details 'Hardware virtualization extensions were not detected.'
    }

    if ($HostProfile.cpu.virtualization_enabled_in_firmware) {
        Add-Check -Id 'firmware-virtualization' -Label 'Firmware virtualization state' -Status 'ok' -Details 'Hardware virtualization appears to be enabled in BIOS or UEFI.'
    }
    else {
        Add-UniqueText -List $blockers -Text 'Hardware virtualization appears disabled in BIOS or UEFI.'
        Add-Check -Id 'firmware-virtualization' -Label 'Firmware virtualization state' -Status 'blocked' -Details 'Hardware virtualization appears disabled in BIOS or UEFI.'
    }

    if ($HostProfile.cpu.slat_supported) {
        Add-Check -Id 'slat' -Label 'Second Level Address Translation (SLAT)' -Status 'ok' -Details 'SLAT support was detected.'
    }
    else {
        Add-Check -Id 'slat' -Label 'Second Level Address Translation (SLAT)' -Status 'warning' -Details 'SLAT was not detected. Modern guests can still work, but performance headroom may be lower.'
    }

    if ($HostProfile.memory.total_gb -lt $thresholds.readiness_blocked_ram_gb) {
        Add-UniqueText -List $blockers -Text 'Host RAM is below the practical floor for a desktop VM.'
        Add-Check -Id 'memory' -Label 'Host RAM capacity' -Status 'blocked' -Details ('Only {0} GB of RAM was detected.' -f $HostProfile.memory.total_gb)
    }
    elseif ($HostProfile.memory.total_gb -lt $thresholds.readiness_limited_ram_gb) {
        Add-UniqueText -List $limitations -Text 'Host RAM is better suited to lighter guest options.'
        Add-Check -Id 'memory' -Label 'Host RAM capacity' -Status 'warning' -Details ('{0} GB of RAM was detected. Lighter guests are the safer fit.' -f $HostProfile.memory.total_gb)
    }
    else {
        Add-Check -Id 'memory' -Label 'Host RAM capacity' -Status 'ok' -Details ('{0} GB of RAM leaves room for practical VM use.' -f $HostProfile.memory.total_gb)
    }

    $minimumPracticalGuestStartGb = if ($HostProfile.memory.total_gb -ge $thresholds.readiness_limited_ram_gb) {
        [double]$thresholds.windows_guest_min_memory_mb / 1024
    }
    else {
        [double]$thresholds.linux_guest_min_memory_mb / 1024
    }
    if (
        $null -ne $HostProfile.memory.free_gb -and
        [double]$HostProfile.memory.free_gb -lt $minimumPracticalGuestStartGb
    ) {
        Add-UniqueText -List $limitations -Text $freeMemoryLimitationText
        Add-Check -Id 'host-free-memory' -Label 'Host free memory' -Status 'warning' -Details ('Only {0} GB of RAM is currently free. Close other applications before starting a VM.' -f $HostProfile.memory.free_gb)
    }

    if ($storage.system_drive_free_gb -lt $thresholds.readiness_blocked_storage_free_gb) {
        if ($preferredStorage -and -not $preferredStorage.is_system_drive) {
            Add-UniqueText -List $limitations -Text ('System drive free space is low, but {0} is the better local drive for VM storage.' -f $preferredStorage.drive_letter)
            Add-Check -Id 'system-drive-pressure' -Label 'System drive pressure' -Status 'warning' -Details ('Only {0} GB is free on the system drive, so VM files should stay on {1}.' -f $storage.system_drive_free_gb, $preferredStorage.drive_letter)
        }
        else {
            Add-UniqueText -List $limitations -Text 'System drive free space is too low to comfortably host VM files.'
            Add-Check -Id 'system-drive-pressure' -Label 'System drive pressure' -Status 'warning' -Details ('Only {0} GB is free on the system drive.' -f $storage.system_drive_free_gb)
        }
    }
    elseif ($storage.system_drive_free_gb -lt $thresholds.readiness_limited_storage_free_gb) {
        if ($preferredStorage -and -not $preferredStorage.is_system_drive) {
            Add-UniqueText -List $limitations -Text ('System drive space is tighter than ideal, so {0} is the better place for VM files.' -f $preferredStorage.drive_letter)
            Add-Check -Id 'system-drive-pressure' -Label 'System drive pressure' -Status 'warning' -Details ('{0} GB is free on the system drive. {1} is the stronger VM storage location.' -f $storage.system_drive_free_gb, $preferredStorage.drive_letter)
        }
        else {
            Add-UniqueText -List $limitations -Text 'System drive free space is workable, but guest disks should stay conservative.'
            Add-Check -Id 'system-drive-pressure' -Label 'System drive pressure' -Status 'warning' -Details ('{0} GB is free on the system drive.' -f $storage.system_drive_free_gb)
        }
    }
    else {
        Add-Check -Id 'system-drive-pressure' -Label 'System drive pressure' -Status 'ok' -Details ('{0} GB is free on the system drive.' -f $storage.system_drive_free_gb)
    }

    if (-not $preferredStorage) {
        Add-UniqueText -List $blockers -Text 'No local fixed drive has enough free space for a practical VM disk.'
        Add-Check -Id 'vm-storage-availability' -Label 'VM storage availability' -Status 'blocked' -Details 'No suitable local fixed drive with at least 40 GB free was detected.'
    }
    elseif ([double]$preferredStorage.free_gb -lt $thresholds.readiness_limited_storage_free_gb) {
        Add-UniqueText -List $limitations -Text ('VM storage is available on {0}, but free space is still best kept for lighter or conservative guest disks.' -f $preferredStorage.drive_letter)
        Add-Check -Id 'vm-storage-availability' -Label 'VM storage availability' -Status 'warning' -Details ('Preferred VM storage: {0} ({1}, {2} GB free).' -f $preferredStorage.drive_letter, $preferredStorage.storage_type_hint, $preferredStorage.free_gb)
    }
    else {
        Add-Check -Id 'vm-storage-availability' -Label 'VM storage availability' -Status 'ok' -Details ('Preferred VM storage: {0} ({1}, {2} GB free).' -f $preferredStorage.drive_letter, $preferredStorage.storage_type_hint, $preferredStorage.free_gb)
    }

    if ($HypervisorProfile.hyperv_enabled) {
        Add-UniqueText -List $limitations -Text 'Hyper-V is enabled and may reduce compatibility or performance for some desktop hypervisors.'
        Add-Check -Id 'hyperv' -Label 'Hyper-V' -Status 'warning' -Details 'Hyper-V is enabled.'
    }
    else {
        Add-Check -Id 'hyperv' -Label 'Hyper-V' -Status 'ok' -Details 'Hyper-V is disabled.'
    }

    if ($HypervisorProfile.memory_integrity_enabled) {
        Add-UniqueText -List $limitations -Text 'Memory Integrity is enabled and may reduce compatibility or smoothness for some desktop hypervisors.'
        Add-Check -Id 'memory-integrity' -Label 'Memory Integrity' -Status 'warning' -Details 'Memory Integrity is enabled.'
    }
    else {
        Add-Check -Id 'memory-integrity' -Label 'Memory Integrity' -Status 'ok' -Details 'Memory Integrity is disabled.'
    }

    $bootModeStatus = if ($HostProfile.firmware.boot_mode -eq 'UEFI') { 'ok' } else { 'info' }
    Add-Check -Id 'boot-mode' -Label 'Boot mode' -Status $bootModeStatus -Details ('Detected boot mode: {0}.' -f $HostProfile.firmware.boot_mode)

    $secureBootStatus = if ($HostProfile.firmware.secure_boot) { 'ok' } else { 'info' }
    $secureBootDetails = if ($HostProfile.firmware.secure_boot) { 'Secure Boot is enabled.' } else { 'Secure Boot is not enabled or could not be confirmed.' }
    Add-Check -Id 'secure-boot' -Label 'Secure Boot' -Status $secureBootStatus -Details $secureBootDetails

    $tpmStatus = if ($hasTpm20) { 'ok' } else { 'info' }
    $tpmDetails = if ($hasTpm20) { 'TPM 2.0 is present and ready.' } else { 'TPM 2.0 was not confirmed.' }
    Add-Check -Id 'tpm' -Label 'TPM readiness' -Status $tpmStatus -Details $tpmDetails

    $deviceGuardStatus = if ($HypervisorProfile.device_guard_available) { 'ok' } else { 'info' }
    $deviceGuardDetails = if ($HypervisorProfile.device_guard_available) { 'Device Guard information was detected.' } else { 'Device Guard information was not detected.' }
    Add-Check -Id 'device-guard' -Label 'Device Guard detection' -Status $deviceGuardStatus -Details $deviceGuardDetails

    $state = if ($blockers.Count -gt 0) {
        'not_ready'
    }
    elseif (@($limitations | Where-Object { [string]$_ -ne $freeMemoryLimitationText }).Count -gt 0) {
        'limited'
    }
    else {
        'ok'
    }

    $headline = ''
    $primaryReason = ''

    switch ($state) {
        'ok' {
            $headline = 'This PC is ready for practical VM use.'
            $primaryReason = 'Hardware virtualization is enabled and at least one local fixed drive is suitable for practical VM storage.'
        }
        'limited' {
            $headline = 'This PC can run VMs, but lighter or more conservative guest choices are the better fit.'
            $primaryReason = [string]$limitations[0]
        }
        default {
            $headline = 'This PC should not be used for a practical VM until blockers are resolved.'
            $primaryReason = [string]$blockers[0]
        }
    }

    return [pscustomobject]@{
        state          = $state
        headline       = $headline
        primary_reason = $primaryReason
        blockers       = @($blockers)
        limitations    = @($limitations)
        checks         = @($checks)
    }
}
