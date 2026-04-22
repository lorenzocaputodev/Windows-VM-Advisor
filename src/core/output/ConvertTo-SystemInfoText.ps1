function ConvertTo-SystemInfoText {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Report
    )

    $system = $Report.system_information
    $lines = New-Object System.Collections.Generic.List[string]

    $vmwareText = if ($system.hypervisors.vmware_workstation_installed) { 'Installed' } else { 'Not detected' }
    $virtualBoxText = if ($system.hypervisors.virtualbox_installed) { 'Installed' } else { 'Not detected' }
    $deviceGuardText = if ($system.windows_features.device_guard_available) { 'Detected' } else { 'Not detected' }
    $hyperVText = if ($system.windows_features.hyperv_enabled) { 'Enabled' } else { 'Disabled' }
    $memoryIntegrityText = if ($system.windows_features.memory_integrity_enabled) { 'Enabled' } else { 'Disabled' }
    $virtSupportedText = if ($system.cpu.virtualization_supported) { 'Yes' } else { 'No' }
    $virtFirmwareText = if ($system.cpu.virtualization_enabled_in_firmware) { 'Yes' } else { 'No' }
    $slatText = if ($system.cpu.slat_supported) { 'Yes' } else { 'No' }
    $secureBootText = if ($system.firmware.secure_boot) { 'Enabled' } else { 'Disabled' }
    $tpmPresentText = if ($system.tpm.present) { 'Yes' } else { 'No' }
    $tpmReadyText = if ($system.tpm.ready) { 'Yes' } else { 'No' }
    $moduleCountProperty = $system.memory.PSObject.Properties['module_count']
    $moduleCount = if ($moduleCountProperty) { [int]$moduleCountProperty.Value } else { $null }
    $memoryLine = if ($null -ne $moduleCount -and $moduleCount -gt 0) {
        'Memory: {0} GB total, {1} GB free across {2} module(s)' -f $system.memory.total_gb, $system.memory.free_gb, $moduleCount
    }
    else {
        'Memory: {0} GB total, {1} GB free' -f $system.memory.total_gb, $system.memory.free_gb
    }
    $cpuClockSuffix = if ($null -ne $system.cpu.max_clock_mhz -and [string]$system.cpu.max_clock_mhz -ne '') {
        ', reported max clock {0} MHz' -f $system.cpu.max_clock_mhz
    }
    else {
        ''
    }
    $tpmText = if ($system.tpm.present -and $system.tpm.ready) {
        'TPM: Present and ready | Version {0}' -f $system.tpm.version
    }
    elseif (-not $system.tpm.present -and -not $system.tpm.ready -and [string]$system.tpm.version -eq 'Unknown') {
        'TPM: Not confirmed | Version Unknown'
    }
    elseif ($system.tpm.present -and -not $system.tpm.ready) {
        'TPM: Present, but not ready | Version {0}' -f $system.tpm.version
    }
    else {
        'TPM: Present {0} | Ready {1} | Version {2}' -f $tpmPresentText, $tpmReadyText, $system.tpm.version
    }

    function Get-DriveVmStorageStatus {
        param(
            [Parameter(Mandatory = $true)]
            [pscustomobject]$Drive,

            [Parameter()]
            [string]$PreferredDriveLetter
        )

        if ($PreferredDriveLetter -and [string]$Drive.drive_letter -eq $PreferredDriveLetter) {
            return 'Preferred for VM files'
        }

        if (-not $Drive.vm_storage_suitable) {
            return 'Too tight for practical VM files'
        }

        if ($Drive.is_system_drive -and $PreferredDriveLetter -and [string]$Drive.drive_letter -ne $PreferredDriveLetter) {
            return 'Usable, but not ideal for VM files'
        }

        return 'Usable for VM files'
    }

    $lines.Add('Windows-VM-Advisor - System Information')
    $lines.Add('=======================================')
    $lines.Add('')
    $lines.Add(('Operating system: {0} {1} (Build {2}, {3})' -f $system.os.name, $system.os.version, $system.os.build, $system.os.architecture))
    $lines.Add(('Processor: {0}' -f $system.cpu.model))
    $lines.Add(('CPU layout: {0} cores, {1} threads{2}' -f $system.cpu.cores, $system.cpu.threads, $cpuClockSuffix))
    $lines.Add(('Virtualization support: {0} | Firmware enabled: {1} | SLAT: {2}' -f
        $virtSupportedText,
        $virtFirmwareText,
        $slatText
    ))
    $lines.Add($memoryLine)
    $lines.Add(('System drive: {0} ({1}), {2} GB total, {3} GB free, {4}' -f
        $system.storage.system_drive,
        $system.storage.system_drive_fs,
        $system.storage.system_drive_total_gb,
        $system.storage.system_drive_free_gb,
        $system.storage.physical_media_hint
    ))
    $lines.Add(('Firmware: {0}' -f $system.firmware.boot_mode))
    $lines.Add(('Secure Boot: {0}' -f $secureBootText))
    $lines.Add($tpmText)
    $lines.Add(('Hypervisors: VMware Workstation {0} | Oracle VirtualBox {1}' -f $vmwareText.ToLowerInvariant(), $virtualBoxText.ToLowerInvariant()))
    $lines.Add(('Windows safeguards: Hyper-V {0}; Memory Integrity {1}; Device Guard {2}' -f $hyperVText, $memoryIntegrityText, $deviceGuardText))
    $lines.Add('')
    $lines.Add('Storage overview:')
    $preferredDriveLetter = if ($system.storage.preferred_vm_storage) { [string]$system.storage.preferred_vm_storage.drive_letter } else { $null }
    foreach ($drive in @($system.storage.drives)) {
        $systemMarker = if ($drive.is_system_drive) { ' [System]' } else { '' }
        $storageFitText = Get-DriveVmStorageStatus -Drive $drive -PreferredDriveLetter $preferredDriveLetter
        $lines.Add(('- {0}{1} | {2}, {3} GB total, {4} GB free, {5}, VM storage fit: {6}' -f
            $drive.drive_letter,
            $systemMarker,
            $drive.filesystem,
            $drive.total_gb,
            $drive.free_gb,
            $drive.storage_type_hint,
            $storageFitText
        ))
    }

    if ($system.storage.preferred_vm_storage) {
        $preferred = $system.storage.preferred_vm_storage
        $lines.Add(('Best place for VM files: {0} ({1}, {2} GB free)' -f
            $preferred.drive_letter,
            $preferred.storage_type_hint,
            $preferred.free_gb
        ))
    }
    else {
        $lines.Add('Best place for VM files: No suitable local drive was found')
    }

    if (@($system.notes).Count -gt 0) {
        $lines.Add('')
        $lines.Add('Notes:')
        foreach ($note in @($system.notes)) {
            $lines.Add(('- {0}' -f $note))
        }
    }

    return ($lines -join [Environment]::NewLine)
}
