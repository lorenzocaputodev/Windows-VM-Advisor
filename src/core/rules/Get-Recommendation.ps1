function Get-Recommendation {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$HostProfile,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$HypervisorProfile,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$UserGoal
    )

    function Add-UniqueText {
        param(
            [Parameter(Mandatory = $true)]
            [string[]]$Existing,

            [Parameter(Mandatory = $true)]
            [string]$Text
        )

        $items = @($Existing)
        if ($Text -and $items -notcontains $Text) {
            $items += $Text
        }

        return @($items)
    }

    function Set-ObjectProperty {
        param(
            [Parameter(Mandatory = $true)]
            [psobject]$Object,

            [Parameter(Mandatory = $true)]
            [string]$Name,

            [Parameter()]
            $Value
        )

        if (@($Object.PSObject.Properties.Name) -contains $Name) {
            $Object.$Name = $Value
        }
        else {
            $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
        }
    }

    function Get-RecommendationInternalFlag {
        param(
            [Parameter(Mandatory = $false)]
            [psobject]$Recommendation,

            [Parameter(Mandatory = $true)]
            [string]$Name
        )

        if ($Recommendation -and (@($Recommendation.PSObject.Properties.Name) -contains $Name)) {
            return [bool]$Recommendation.$Name
        }

        return $false
    }

    $vmReadiness = Get-VMReadiness -HostProfile $HostProfile -HypervisorProfile $HypervisorProfile
    $recommendations = @(Get-IsoRecommendations -HostProfile $HostProfile -HypervisorProfile $HypervisorProfile -UserGoal $UserGoal -VMReadiness $vmReadiness)

    $recommendedEntries = @($recommendations | Where-Object { $_.compatibility_label -eq 'recommended' })
    $possibleEntries = @($recommendations | Where-Object { $_.compatibility_label -eq 'possible' })
    $recommendedCount = $recommendedEntries.Count
    $possibleCount = $possibleEntries.Count
    $bestPractical = if ($recommendedCount -gt 0) {
        $recommendedEntries[0]
    }
    elseif ($possibleCount -gt 0) {
        $possibleEntries[0]
    }
    else {
        $null
    }
    $structuralLimitations = @(
        $vmReadiness.limitations |
        Where-Object {
            $text = [string]$_
            $text -and
            $text -ne 'Host free RAM is low. Close other applications before starting a VM.' -and
            $text -notmatch '(?i)(drive|storage|VM files)'
        } |
        Select-Object -First 1
    )
    $structuralLimitation = if ($structuralLimitations.Count -gt 0) { [string]$structuralLimitations[0] } else { $null }
    $freeMemoryLimitations = @($vmReadiness.limitations | Where-Object { [string]$_ -eq 'Host free RAM is low. Close other applications before starting a VM.' })
    $freeMemoryLimitation = if ($freeMemoryLimitations.Count -gt 0) { [string]$freeMemoryLimitations[0] } else { $null }
    $storageLimitations = @($vmReadiness.limitations | Where-Object { [string]$_ -match '(?i)(drive|storage|VM files)' } | Select-Object -First 1)
    $storageLimitation = if ($storageLimitations.Count -gt 0) { [string]$storageLimitations[0] } else { $null }
    $bestPracticalHasMaterialFreeMemoryPressure = Get-RecommendationInternalFlag -Recommendation $bestPractical -Name '_material_free_memory_pressure'
    $bestPracticalStorageLocation = if ($bestPractical -and $bestPractical.vm_profile) { [string]$bestPractical.vm_profile.storage_location } else { $null }

    if ($vmReadiness.state -eq 'ok' -and $recommendedCount -eq 0 -and $possibleCount -gt 0) {
        $vmReadiness.state = 'limited'
        $vmReadiness.limitations = Add-UniqueText -Existing @($vmReadiness.limitations) -Text 'No guest option reached the strongest recommendation tier under the current host conditions.'
    }

    if ($recommendedCount -eq 0 -and $possibleCount -eq 0 -and @($vmReadiness.blockers).Count -eq 0) {
        $vmReadiness.state = 'not_ready'
        $vmReadiness.blockers = Add-UniqueText -Existing @($vmReadiness.blockers) -Text 'No practical guest option stands out under the current host conditions.'
    }

    if ($vmReadiness.state -eq 'not_ready' -or -not $bestPractical) {
        $summaryReason = 'No practical guest option stands out under the current host conditions.'
        $vmReadiness.state = 'not_ready'
        $vmReadiness.headline = 'This PC should not be used for a practical VM until blockers are resolved.'
        if (@($vmReadiness.blockers).Count -gt 0) {
            $vmReadiness.primary_reason = [string]@($vmReadiness.blockers)[0]
        }
        else {
            $vmReadiness.primary_reason = $summaryReason
            $vmReadiness.blockers = Add-UniqueText -Existing @($vmReadiness.blockers) -Text $summaryReason
        }
        Set-ObjectProperty -Object $vmReadiness -Name 'takeaway' -Value 'No practical VM guest is a good fit until the current blockers are resolved.'
    }
    elseif ($vmReadiness.state -eq 'limited') {
        $dominantLimitation = if ($structuralLimitation) {
            [string]$structuralLimitation
        }
        elseif ($freeMemoryLimitation -and $bestPracticalHasMaterialFreeMemoryPressure) {
            [string]$freeMemoryLimitation
        }
        elseif ($storageLimitation) {
            [string]$storageLimitation
        }
        elseif (@($vmReadiness.limitations).Count -gt 0) {
            [string]@($vmReadiness.limitations)[0]
        }
        else {
            [string]$vmReadiness.primary_reason
        }
        $vmReadiness.primary_reason = $dominantLimitation

        $preferredStorage = $HostProfile.storage.preferred_vm_storage
        $hasSecondaryPreferredStorage = [bool](
            $preferredStorage -and
            -not $preferredStorage.is_system_drive -and
            [string]$preferredStorage.drive_letter
        )
        $storageDominant = [bool]($storageLimitation -and $dominantLimitation -eq $storageLimitation)

        if ($freeMemoryLimitation -and $bestPracticalHasMaterialFreeMemoryPressure) {
            $vmReadiness.headline = 'This PC can run VMs, but current free RAM is tighter than ideal for the suggested starts.'
            if ($hasSecondaryPreferredStorage -and $bestPracticalStorageLocation) {
                Set-ObjectProperty -Object $vmReadiness -Name 'takeaway' -Value ('This PC is limited for VM use right now. Start with {0}, close other applications first, and keep VM files on {1}.' -f $bestPractical.display_name, $bestPracticalStorageLocation)
            }
            else {
                Set-ObjectProperty -Object $vmReadiness -Name 'takeaway' -Value ('This PC is limited for VM use right now. Start with {0}, then close other applications before launching the VM.' -f $bestPractical.display_name)
            }
        }
        elseif ($bestPractical.family -eq 'linux' -and $storageDominant -and $hasSecondaryPreferredStorage) {
            $vmReadiness.headline = 'This PC can run VMs, but the system drive is tighter than ideal. Keep VM files on the secondary drive.'
            Set-ObjectProperty -Object $vmReadiness -Name 'takeaway' -Value ('This PC is limited for VM use mainly by storage layout. Use {0} and keep VM files on {1}.' -f $bestPractical.display_name, $preferredStorage.drive_letter)
        }
        elseif ($bestPractical.family -eq 'linux') {
            $vmReadiness.headline = 'This PC can run VMs, but lighter Linux guests are the safer first choice.'
            Set-ObjectProperty -Object $vmReadiness -Name 'takeaway' -Value ('This PC is limited for VM use. Start with lighter Linux guests such as {0}.' -f $bestPractical.display_name)
        }
        else {
            $vmReadiness.headline = 'This PC can run VMs, but conservative guest choices and modest VM settings are the safer path.'
            Set-ObjectProperty -Object $vmReadiness -Name 'takeaway' -Value ('This PC is limited for VM use. {0} is still workable, but keep the VM modest.' -f $bestPractical.display_name)
        }
    }
    else {
        if ($freeMemoryLimitation -and $bestPracticalHasMaterialFreeMemoryPressure) {
            $vmReadiness.headline = 'This PC is ready for practical VM use, but current free RAM is tighter than ideal for the suggested starts.'
            $vmReadiness.primary_reason = [string]$freeMemoryLimitation
            Set-ObjectProperty -Object $vmReadiness -Name 'takeaway' -Value ('This PC is ready for practical VM use. Start with {0}, and close other applications before launching the VM.' -f $bestPractical.display_name)
        }
        elseif ($bestPractical.family -eq 'windows') {
            if ([string]$bestPractical.id -like 'windows-11*') {
                $vmReadiness.headline = 'This PC is ready for practical VM use, and stronger Windows guests remain a realistic fit.'
            }
            else {
                $vmReadiness.headline = 'This PC is ready for practical VM use, and Windows guests remain a practical fit.'
            }
            $vmReadiness.primary_reason = ('{0} is the clearest overall fit, with other mainstream guests still in range.' -f $bestPractical.display_name)
        }
        else {
            $vmReadiness.headline = 'This PC is ready for practical VM use, with Linux guests as the clearest first picks.'
            $vmReadiness.primary_reason = ('{0} is the clearest overall fit, while several other practical guests also make sense.' -f $bestPractical.display_name)
        }

        Set-ObjectProperty -Object $vmReadiness -Name 'takeaway' -Value ('This PC is ready for practical VM use. {0} is the clearest overall fit.' -f $bestPractical.display_name)
    }

    foreach ($recommendation in @($recommendations)) {
        if (@($recommendation.PSObject.Properties.Name) -contains '_material_free_memory_pressure') {
            [void]$recommendation.PSObject.Properties.Remove('_material_free_memory_pressure')
        }
    }

    return [pscustomobject]@{
        vm_readiness    = $vmReadiness
        recommendations = @($recommendations)
    }
}
