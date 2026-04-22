function ConvertTo-UserConsoleSummary {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Report,

        [Parameter(Mandatory = $true)]
        [string]$ResultsPath
    )

    $system = $Report.system_information
    $readiness = $Report.vm_readiness
    $recommendations = @($Report.recommendations)
    $guidance = Get-BestFitGuidance -Report $Report
    $recommendedRecommendations = @($recommendations | Where-Object { $_.compatibility_label -eq 'recommended' })
    $possibleRecommendations = @($recommendations | Where-Object { $_.compatibility_label -eq 'possible' })
    $notRecommendedRecommendations = @($recommendations | Where-Object { $_.compatibility_label -eq 'not_recommended' })
    $lines = New-Object System.Collections.Generic.List[string]

    function Add-Section {
        param(
            [Parameter(Mandatory = $true)]
            $LineBuffer,

            [Parameter(Mandatory = $true)]
            [string]$Title
        )

        if ($LineBuffer.Count -gt 0 -and $LineBuffer[$LineBuffer.Count - 1] -ne '') {
            $LineBuffer.Add('')
        }
        $LineBuffer.Add($Title)
        $LineBuffer.Add(('-' * $Title.Length))
        $LineBuffer.Add('')
    }

    function Get-YesNo {
        param([bool]$Value)

        if ($Value) { return 'Yes' }
        return 'No'
    }

    $vmwareText = if ($system.hypervisors.vmware_workstation_installed) { 'Installed' } else { 'Not detected' }
    $virtualBoxText = if ($system.hypervisors.virtualbox_installed) { 'Installed' } else { 'Not detected' }
    $hyperVText = if ($system.windows_features.hyperv_enabled) { 'Enabled' } else { 'Disabled' }
    $memoryIntegrityText = if ($system.windows_features.memory_integrity_enabled) { 'Enabled' } else { 'Disabled' }
    $deviceGuardText = if ($system.windows_features.device_guard_available) { 'Detected' } else { 'Not detected' }
    $virtSupportedText = Get-YesNo -Value ([bool]$system.cpu.virtualization_supported)
    $virtFirmwareText = Get-YesNo -Value ([bool]$system.cpu.virtualization_enabled_in_firmware)
    $slatText = Get-YesNo -Value ([bool]$system.cpu.slat_supported)
    $preferredStorageText = if ($system.storage.preferred_vm_storage) {
        '{0} ({1}, {2} GB free)' -f
            $system.storage.preferred_vm_storage.drive_letter,
            $system.storage.preferred_vm_storage.storage_type_hint,
            $system.storage.preferred_vm_storage.free_gb
    }
    else {
        'None suitable'
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
        'TPM: Present {0} | Ready {1} | Version {2}' -f
            (Get-YesNo -Value ([bool]$system.tpm.present)),
            (Get-YesNo -Value ([bool]$system.tpm.ready)),
            $system.tpm.version
    }

    function Add-TopRecommendations {
        param(
            [Parameter(Mandatory = $true)]
            $LineBuffer,

            [Parameter(Mandatory = $true)]
            [object[]]$Entries
        )

        if ($Entries.Count -eq 0) {
            $LineBuffer.Add('- None')
            $LineBuffer.Add('')
            return
        }

        foreach ($entry in $Entries) {
            $label = switch ([string]$entry.compatibility_label) {
                'recommended' { 'Recommended' }
                'possible' { 'Possible' }
                default { 'Not recommended' }
            }

            $LineBuffer.Add(('- {0} [{1}] - {2}' -f $entry.display_name, $label, $entry.fit_reason))
        }
    }

    $topRecommendations = if ($recommendedRecommendations.Count -gt 0) {
        @($recommendedRecommendations | Select-Object -First 3)
    }
    elseif ($possibleRecommendations.Count -gt 0) {
        @($possibleRecommendations | Select-Object -First 3)
    }
    else {
        @($notRecommendedRecommendations | Select-Object -First 2)
    }

    $lines.Add('Windows-VM-Advisor')
    $lines.Add('==================')
    $lines.Add('')

    Add-Section -LineBuffer $lines -Title 'Takeaway'
    $lines.Add($readiness.takeaway)

    $lines.Add('')
    Add-Section -LineBuffer $lines -Title 'System Overview'
    $lines.Add(('OS: {0} {1} (Build {2}, {3})' -f $system.os.name, $system.os.version, $system.os.build, $system.os.architecture))
    $lines.Add(('CPU: {0} | {1} cores / {2} threads | Virtualization support: {3} | Firmware enabled: {4} | SLAT: {5}' -f
        $system.cpu.model,
        $system.cpu.cores,
        $system.cpu.threads,
        $virtSupportedText,
        $virtFirmwareText,
        $slatText
    ))
    $lines.Add(('Memory: {0} GB total, {1} GB free' -f $system.memory.total_gb, $system.memory.free_gb))
    $lines.Add(('Storage: System {0} {1}/{2} GB free ({3}) | Preferred VM drive: {4}' -f
        $system.storage.system_drive,
        $system.storage.system_drive_free_gb,
        $system.storage.system_drive_total_gb,
        $system.storage.physical_media_hint,
        $preferredStorageText
    ))
    $lines.Add(('Firmware: {0} | Secure Boot: {1} | {2}' -f
        $system.firmware.boot_mode,
        $(if ($system.firmware.secure_boot) { 'Enabled' } else { 'Disabled' }),
        $tpmText
    ))
    $lines.Add(('Hypervisors: VMware Workstation {0} | Oracle VirtualBox {1}' -f $vmwareText.ToLowerInvariant(), $virtualBoxText.ToLowerInvariant()))
    $lines.Add(('Windows safeguards: Hyper-V {0}; Memory Integrity {1}; Device Guard {2}' -f $hyperVText, $memoryIntegrityText, $deviceGuardText))
    $lines.Add('')

    Add-Section -LineBuffer $lines -Title 'VM Readiness'
    $lines.Add(('{0}: {1}' -f $readiness.state.ToUpperInvariant(), $readiness.headline))
    $lines.Add(('Why this result: {0}' -f $readiness.primary_reason))
    $lines.Add('')

    Add-Section -LineBuffer $lines -Title 'Best-Fit Guidance'
    if (($recommendedRecommendations.Count + $possibleRecommendations.Count) -gt 0) {
        $lines.Add(('- Best overall fit: {0}' -f $guidance.best_overall.display_name))
        if ($guidance.best_lightweight -and -not $guidance.overall_is_lightweight) {
            $lines.Add(('- Best lightweight option: {0}' -f $guidance.best_lightweight.display_name))
        }
        if ($guidance.best_windows) {
            $lines.Add(('- Best Windows option: {0}' -f $guidance.best_windows.display_name))
        }
    }
    else {
        $lines.Add('- No practical guest is currently recommended under the current host conditions.')
    }
    $lines.Add('')

    Add-Section -LineBuffer $lines -Title 'Top Recommendations'
    Add-TopRecommendations -LineBuffer $lines -Entries $topRecommendations
    if ($recommendedRecommendations.Count -gt 0 -and $possibleRecommendations.Count -gt 0) {
        $lines.Add(('- More usable options are listed in ISO-Recommendations.txt ({0} additional).' -f $possibleRecommendations.Count))
    }
    elseif ($recommendedRecommendations.Count -eq 0 -and $possibleRecommendations.Count -gt $topRecommendations.Count) {
        $lines.Add(('- More usable options are listed in ISO-Recommendations.txt ({0} additional).' -f ($possibleRecommendations.Count - $topRecommendations.Count)))
    }
    if ($notRecommendedRecommendations.Count -gt $topRecommendations.Count) {
        $lines.Add('- Full blocked list is in ISO-Recommendations.txt')
    }
    if (($recommendedRecommendations.Count + $possibleRecommendations.Count) -gt 0) {
        if ($lines[$lines.Count - 1] -ne '') {
            $lines.Add('')
        }
        $lines.Add('VM settings are listed in VM-Profiles.txt')
    }

    Add-Section -LineBuffer $lines -Title 'Results Path'
    $lines.Add($ResultsPath)

    return ($lines -join [Environment]::NewLine).TrimEnd()
}
