function ConvertTo-VMProfilesText {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Report
    )

    $recommendations = @($Report.recommendations)
    $usableRecommendations = @($recommendations | Where-Object { $_.compatibility_label -ne 'not_recommended' })

    $lines = New-Object System.Collections.Generic.List[string]

    function Add-ProfileGroup {
        param(
            [Parameter(Mandatory = $true)]
            $LineBuffer,

            [Parameter(Mandatory = $true)]
            [object[]]$Entries,

            [Parameter(Mandatory = $true)]
            [string]$Heading,

            [Parameter(Mandatory = $true)]
            [string]$LabelValue
        )

        $LineBuffer.Add($Heading + ':')
        $groupEntries = @($Entries | Where-Object { [string]$_.compatibility_label -eq $LabelValue })

        if ($groupEntries.Count -eq 0) {
            $LineBuffer.Add('- None')
            $LineBuffer.Add('')
            return
        }

        foreach ($recommendation in $groupEntries) {
            $profile = $recommendation.vm_profile
            $label = if ($recommendation.compatibility_label -eq 'recommended') { 'Recommended' } else { 'Possible' }
            $secureBootText = if ($profile.secure_boot) { 'Enabled' } else { 'Disabled' }
            $tpmText = if ($profile.tpm) { 'Yes' } else { 'No' }
            $notes = @($recommendation.notes | Where-Object {
                $trimmed = [string]$_
                $trimmed -and ($trimmed -ne ('Use {0} as the preferred VM storage location for this guest.' -f $profile.storage_location))
            })

            $LineBuffer.Add(('- {0} [{1}]' -f $recommendation.display_name, $label))
            $LineBuffer.Add(('   Hypervisor: {0}' -f $recommendation.preferred_hypervisor))
            $LineBuffer.Add(('   Suggested setup: {0} vCPU, {1} MB RAM, {2} GB disk, {3}, Secure Boot {4}, TPM {5}, Network {6}' -f
                $profile.vcpu,
                $profile.memory_mb,
                $profile.disk_gb,
                $profile.firmware,
                $secureBootText,
                $tpmText,
                $profile.network
            ))
            $LineBuffer.Add(('   Save VM files on: {0}' -f $profile.storage_location))

            if ($notes.Count -gt 0) {
                $LineBuffer.Add(('   Notes: {0}' -f ($notes -join '; ')))
            }

            $LineBuffer.Add('')
        }
    }

    $lines.Add('Windows-VM-Advisor - VM Profiles')
    $lines.Add('================================')
    $lines.Add('')
    $lines.Add('Use these settings as a practical starting point. Increase them only if needed.')
    $lines.Add('')

    if ($usableRecommendations.Count -eq 0) {
        $lines.Add('No practical VM profiles are recommended until the current blockers are resolved.')
        return ($lines -join [Environment]::NewLine)
    }

    Add-ProfileGroup -LineBuffer $lines -Entries $recommendations -Heading 'Best choices' -LabelValue 'recommended'
    Add-ProfileGroup -LineBuffer $lines -Entries $recommendations -Heading 'Usable, but less ideal' -LabelValue 'possible'

    return ($lines -join [Environment]::NewLine).TrimEnd()
}
