function Get-IsoRecommendations {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$HostProfile,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$HypervisorProfile,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$UserGoal,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$VMReadiness
    )

    $thresholds = Get-AdvisorThresholds
    $catalog = Get-IsoCatalog
    $storage = $HostProfile.storage
    $defaultPreferredStorage = $storage.preferred_vm_storage
    $defaultPreferredFreeGb = if ($defaultPreferredStorage) { [double]$defaultPreferredStorage.free_gb } else { 0 }
    $defaultPreferredType = if ($defaultPreferredStorage) { [string]$defaultPreferredStorage.storage_type_hint } else { 'Unknown' }
    $virtualizationReady = [bool](
        $HostProfile.cpu.virtualization_supported -and
        $HostProfile.cpu.virtualization_enabled_in_firmware
    )
    $hostConstrained = [bool](
        $HostProfile.memory.total_gb -lt $thresholds.readiness_limited_ram_gb -or
        $defaultPreferredFreeGb -lt $thresholds.readiness_limited_storage_free_gb -or
        $defaultPreferredType -eq 'HDD'
    )
    $hostStrong = [bool](
        $HostProfile.memory.total_gb -ge $thresholds.host_strong_memory_gb -and
        $defaultPreferredFreeGb -ge $thresholds.host_strong_storage_free_gb -and
        $HostProfile.cpu.threads -ge $thresholds.host_strong_threads -and
        $virtualizationReady
    )
    $hasTpm20 = [bool](
        $HostProfile.security.tpm_present -and
        $HostProfile.security.tpm_ready -and
        ($HostProfile.security.tpm_version -match '2\.0')
    )
    $windows11Suitability = Test-Windows11Suitability -HostProfile $HostProfile
    $vmware = Test-VMwareSuitability -HostProfile $HostProfile -HypervisorProfile $HypervisorProfile
    $virtualBox = Test-VirtualBoxSuitability -HostProfile $HostProfile -HypervisorProfile $HypervisorProfile

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

    function Get-LevelIndex {
        param([string]$Name)

        switch ($Name) {
            'light' { return 0 }
            'balanced' { return 1 }
            'performance' { return 2 }
            default { return 1 }
        }
    }

    function Get-LevelName {
        param([int]$Index)

        switch ($Index) {
            0 { return 'light' }
            2 { return 'performance' }
            default { return 'balanced' }
        }
    }

    function Clamp-Level {
        param([int]$Index)

        return [math]::Min(2, [math]::Max(0, $Index))
    }

    function Get-MemoryTiers {
        param([string]$Family)

        if ($Family -eq 'windows') {
            return @(4096, 6144, 8192)
        }

        return @(2048, 3072, 4096, 6144)
    }

    function Get-ProfileFamily {
        param([pscustomobject]$Entry)

        if ([string]$Entry.family -eq 'windows') {
            return 'windows'
        }

        return 'linux'
    }

    function Get-HighestTierAtOrBelow {
        param(
            [int[]]$Tiers,
            [int]$LimitMb
        )

        $matches = @($Tiers | Where-Object { $_ -le $LimitMb } | Sort-Object)
        if ($matches.Count -gt 0) {
            return [int]$matches[-1]
        }

        return $null
    }

    function Get-LowestTierAtOrAbove {
        param(
            [int[]]$Tiers,
            [int]$LimitMb
        )

        $matches = @($Tiers | Where-Object { $_ -ge $LimitMb } | Sort-Object)
        if ($matches.Count -gt 0) {
            return [int]$matches[0]
        }

        return $null
    }

    function Get-HypervisorDecision {
        param(
            [pscustomobject]$Vmware,
            [pscustomobject]$VirtualBox,
            [pscustomobject]$HypervisorProfile,
            [pscustomobject]$UserGoal
        )

        $note = $null

        if ($UserGoal.hypervisor_preference -eq 'vmware') {
            if ($Vmware.status -ne 'blocked') {
                return [pscustomobject]@{
                    name   = 'VMware Workstation'
                    status = $Vmware.status
                    note   = $note
                }
            }

            if ($VirtualBox.status -ne 'blocked') {
                return [pscustomobject]@{
                    name   = 'Oracle VirtualBox'
                    status = $VirtualBox.status
                    note   = 'VMware Workstation was requested, but Oracle VirtualBox is the safer choice on this host.'
                }
            }
        }
        elseif ($UserGoal.hypervisor_preference -eq 'virtualbox') {
            if ($VirtualBox.status -ne 'blocked') {
                return [pscustomobject]@{
                    name   = 'Oracle VirtualBox'
                    status = $VirtualBox.status
                    note   = $note
                }
            }

            if ($Vmware.status -ne 'blocked') {
                return [pscustomobject]@{
                    name   = 'VMware Workstation'
                    status = $Vmware.status
                    note   = 'Oracle VirtualBox was requested, but VMware Workstation is the safer choice on this host.'
                }
            }
        }

        $installedSuitable = New-Object System.Collections.ArrayList
        if ($HypervisorProfile.vmware_workstation_installed -and $Vmware.status -ne 'blocked') {
            [void]$installedSuitable.Add($Vmware)
        }
        if ($HypervisorProfile.virtualbox_installed -and $VirtualBox.status -ne 'blocked') {
            [void]$installedSuitable.Add($VirtualBox)
        }

        if ($installedSuitable.Count -gt 0) {
            $bestInstalled = @($installedSuitable | Sort-Object -Property score -Descending | Select-Object -First 1)[0]
            return [pscustomobject]@{
                name   = [string]$bestInstalled.name
                status = [string]$bestInstalled.status
                note   = $note
            }
        }

        if ($Vmware.status -eq 'blocked' -and $VirtualBox.status -eq 'blocked') {
            return [pscustomobject]@{
                name   = 'No practical hypervisor until blockers are resolved'
                status = 'blocked'
                note   = $note
            }
        }

        if ($Vmware.score -ge $VirtualBox.score -and $Vmware.status -ne 'blocked') {
            return [pscustomobject]@{
                name   = 'VMware Workstation'
                status = $Vmware.status
                note   = $note
            }
        }

        return [pscustomobject]@{
            name   = 'Oracle VirtualBox'
            status = $VirtualBox.status
            note   = $note
        }
    }

    function Get-ModeFitScore {
        param(
            [string]$RequestedMode,
            [string]$EntryMode
        )

        $difference = [math]::Abs((Get-LevelIndex -Name $RequestedMode) - (Get-LevelIndex -Name $EntryMode))
        switch ($difference) {
            0 { return 6 }
            1 { return 3 }
            default { return -3 }
        }
    }

    function Get-FitReasonTemplate {
        param(
            [pscustomobject]$Entry,
            [string]$Label
        )

        switch ([string]$Entry.id) {
            'linux-mint' {
                if ($Label -eq 'recommended') { return 'Balanced desktop Linux choice for moderate hardware.' }
                return 'Friendly desktop Linux option, though lighter guests are easier on this host.'
            }
            'ubuntu-lts' {
                if ($Label -eq 'recommended') { return 'Mainstream and broadly supported Linux guest for general VM use.' }
                return 'Broadly supported Linux guest that still works here with a conservative start.'
            }
            'debian-stable' {
                if ($Label -eq 'recommended') { return 'Conservative and lightweight VM choice for modest hardware.' }
                return 'Efficient Linux choice, but it fits best when the VM stays modest.'
            }
            'lubuntu' {
                if ($Label -eq 'recommended') { return 'Very light desktop Linux choice for tighter host conditions.' }
                return 'Very light Linux desktop that still works here with modest VM settings.'
            }
            'fedora-workstation' {
                if ($Label -eq 'recommended') { return 'Modern developer-friendly Linux desktop for stronger or more technical hosts.' }
                return 'Modern Linux desktop that stays workable here, but it is not the most conservative fit.'
            }
            'arch-linux' {
                if ($Label -eq 'recommended') { return 'Advanced DIY Linux option for users who want a more manual setup.' }
                return 'Advanced Linux guest that can work here, but it fits best for users comfortable with a more manual setup.'
            }
            'nixos' {
                if ($Label -eq 'recommended') { return 'Advanced declarative Linux option for technical users who want reproducible environments.' }
                return 'Advanced declarative Linux option that can work here, though it is not the simplest default desktop choice.'
            }
            'rocky-linux' {
                if ($Label -eq 'recommended') { return 'Enterprise-style Linux guest better suited to lab or server-like use than to a default desktop VM.' }
                return 'Enterprise-style Linux guest that can work here, though it is not the strongest default desktop fit.'
            }
            'freebsd' {
                if ($Label -eq 'recommended') { return 'Advanced Unix-like guest for technical or lab-oriented use.' }
                return 'Advanced Unix-like guest better suited to technical or lab-oriented VM use than to a default everyday desktop VM.'
            }
            'windows-10' {
                if ($Label -eq 'recommended') { return 'Most forgiving Windows desktop option for broader host compatibility.' }
                return 'Most forgiving Windows desktop option here, but it should start modestly.'
            }
            'windows-11' {
                if ($Label -eq 'recommended') { return 'Newer Windows desktop option that expects a more comfortable host setup.' }
                return 'Windows 11 is workable here only when the VM stays conservative.'
            }
            'kali-linux' {
                if ($Label -eq 'recommended') { return 'Security-focused guest intended for specialist lab use, not as a default desktop VM.' }
                return 'Security-focused guest best suited to specialist lab use rather than a default desktop VM.'
            }
        }

        if ([string]$Entry.family -eq 'windows') {
            if ($Label -eq 'recommended') { return 'Practical Windows guest for the current host conditions.' }
            return 'Windows guest that can work here, but it is not the strongest overall fit.'
        }

        switch ([string]$Entry.role) {
            'mainstream_desktop' {
                if ($Label -eq 'recommended') { return 'Practical everyday Linux desktop for the current host conditions.' }
                return 'Everyday Linux desktop that can work here, though stronger default fits exist on this host.'
            }
            'lightweight_desktop' {
                if ($Label -eq 'recommended') { return 'Lightweight Linux desktop that fits modest host conditions well.' }
                return 'Lighter Linux desktop that stays viable here with a conservative VM start.'
            }
            'advanced_desktop' {
                if ($Label -eq 'recommended') { return 'Advanced Linux desktop that makes sense here for a more technical setup.' }
                return 'Advanced Linux desktop that can work here, though it is not the simplest default choice.'
            }
            'specialist_security' {
                if ($Label -eq 'recommended') { return 'Security-focused Linux guest that fits a specialist lab-oriented setup.' }
                return 'Security-focused Linux guest that is viable here, but it remains specialist rather than a default desktop choice.'
            }
            'enterprise_server_like' {
                if ($Label -eq 'recommended') { return 'Enterprise-style Linux guest that fits a stronger lab-oriented setup.' }
                return 'Enterprise-style Linux guest that can work here, though it is not a default everyday desktop pick.'
            }
            'unix_like_advanced' {
                if ($Label -eq 'recommended') { return 'Advanced Unix-like guest that suits a technical VM setup.' }
                return 'Advanced Unix-like guest better suited to technical or lab-oriented VM use than to a default everyday desktop VM.'
            }
        }

        if ($Label -eq 'recommended') { return 'Practical Linux guest for the current host conditions.' }
        return 'Linux guest that can work here, but stronger fits exist on this host.'
    }

    function Get-DefaultDesktopFitAdjustment {
        param([pscustomobject]$Entry)

        switch ([string]$Entry.default_desktop_fit) {
            'high' { return 3 }
            'low' { return -3 }
            default { return 0 }
        }
    }

    function Get-ResourceTierAdjustment {
        param(
            [pscustomobject]$Entry,
            [bool]$HostStrong,
            [bool]$HostConstrained,
            [bool]$FreeMemoryTight
        )

        switch ([string]$Entry.resource_tier) {
            'light' {
                if ($HostConstrained -or $FreeMemoryTight) { return 3 }
                return 0
            }
            'heavy' {
                if ($HostConstrained -or $FreeMemoryTight) { return -3 }
                if ($HostStrong) { return 2 }
                return 0
            }
            default { return 0 }
        }
    }

    function Get-RoleAdjustment {
        param(
            [pscustomobject]$Entry,
            [bool]$HostStrong,
            [bool]$HostConstrained,
            [bool]$FreeMemoryTight
        )

        $adjustment = 0
        switch ([string]$Entry.role) {
            'mainstream_desktop' {
                if ($HostConstrained -or $FreeMemoryTight) { $adjustment += 1 } else { $adjustment += 3 }
            }
            'lightweight_desktop' {
                if ($HostConstrained -or $FreeMemoryTight) { $adjustment += 4 } else { $adjustment += 1 }
            }
            'advanced_desktop' {
                if (-not $HostStrong) { $adjustment -= 2 }
            }
            'specialist_security' {
                if ($HostStrong) { $adjustment -= 2 } else { $adjustment -= 4 }
            }
            'enterprise_server_like' {
                if ($HostStrong) { $adjustment -= 2 } else { $adjustment -= 4 }
            }
            'unix_like_advanced' {
                if ($HostStrong) { $adjustment -= 2 } else { $adjustment -= 4 }
            }
        }

        if ([bool]$Entry.specialist) {
            $adjustment -= 1
        }

        return $adjustment
    }

    function Get-RoleLabelThresholds {
        param(
            [pscustomobject]$Entry,
            [bool]$HostStrong,
            [bool]$HostConstrained
        )

        $recommendedThreshold = 78
        $possibleThreshold = 64

        switch ([string]$Entry.role) {
            'mainstream_desktop' {
                $recommendedThreshold -= 2
            }
            'lightweight_desktop' {
                if ($HostConstrained) { $recommendedThreshold -= 6 } else { $recommendedThreshold -= 1 }
                $possibleThreshold -= 1
            }
            'advanced_desktop' {
                if (-not $HostStrong) { $recommendedThreshold += 3 }
                $possibleThreshold += 1
            }
            'specialist_security' {
                $recommendedThreshold += ($(if ($HostStrong) { 4 } else { 6 }))
                $possibleThreshold += 2
            }
            'enterprise_server_like' {
                $recommendedThreshold += ($(if ($HostStrong) { 4 } else { 6 }))
                $possibleThreshold += 2
            }
            'unix_like_advanced' {
                $recommendedThreshold += ($(if ($HostStrong) { 4 } else { 6 }))
                $possibleThreshold += 2
            }
        }

        return [pscustomobject]@{
            recommended = $recommendedThreshold
            possible    = $possibleThreshold
        }
    }

    function Get-StructuralMemoryReductionNote {
        param([int]$FinalMemoryMb)

        return ('RAM was reduced to {0} MB to stay within more comfortable host-safe limits.' -f $FinalMemoryMb)
    }

    function Get-FreeMemoryAdjustedNote {
        param([int]$FinalMemoryMb)

        return ('RAM is starting at {0} MB because current free RAM is tighter than ideal. Close other applications before starting the VM.' -f $FinalMemoryMb)
    }

    function Get-FreeMemoryAdvisoryNote {
        return 'Current free RAM is tighter than ideal for this starting profile. Close other applications before starting the VM.'
    }

    $hypervisorDecision = Get-HypervisorDecision -Vmware $vmware -VirtualBox $virtualBox -HypervisorProfile $HypervisorProfile -UserGoal $UserGoal
    $scoredEntries = New-Object System.Collections.ArrayList

    foreach ($catalogEntry in $catalog) {
        $scopeNote = if (@($catalogEntry.PSObject.Properties.Name) -contains 'scope_note') {
            [string]@($catalogEntry.scope_note)[0]
        }
        else {
            ''
        }

        $entry = [pscustomobject]@{
            id                         = [string](@($catalogEntry.id)[0])
            display_name               = [string](@($catalogEntry.display_name)[0])
            family                     = [string](@($catalogEntry.family)[0])
            flavor                     = [string](@($catalogEntry.flavor)[0])
            category                   = [string](@($catalogEntry.category)[0])
            architecture               = [string](@($catalogEntry.architecture)[0])
            official_download_page     = [string](@($catalogEntry.official_download_page)[0])
            official_release_page      = [string](@($catalogEntry.official_release_page)[0])
            typical_vm_fit             = [string](@($catalogEntry.typical_vm_fit)[0])
            role                       = [string](@($catalogEntry.role)[0])
            default_desktop_fit        = [string](@($catalogEntry.default_desktop_fit)[0])
            resource_tier              = [string](@($catalogEntry.resource_tier)[0])
            specialist                 = [bool](@($catalogEntry.specialist)[0])
            scope_note                 = $scopeNote
            requires_tpm               = [bool](@($catalogEntry.requires_tpm)[0])
            requires_secure_boot       = [bool](@($catalogEntry.requires_secure_boot)[0])
            requires_uefi              = [bool](@($catalogEntry.requires_uefi)[0])
            general_purpose_vm_use     = [bool](@($catalogEntry.general_purpose_vm_use)[0])
            low_end_host_friendly      = [bool](@($catalogEntry.low_end_host_friendly)[0])
            security_lab_use           = [bool](@($catalogEntry.security_lab_use)[0])
            enterprise_windows_testing = [bool](@($catalogEntry.enterprise_windows_testing)[0])
            base_score                 = [int](@($catalogEntry.base_score)[0])
            min_host_ram_gb            = [double](@($catalogEntry.min_host_ram_gb)[0])
            min_free_storage_gb        = [double](@($catalogEntry.min_free_storage_gb)[0])
        }

        $entryBlockers = New-Object System.Collections.ArrayList
        $entryNotes = New-Object System.Collections.ArrayList
        $score = [int]$entry.base_score
        $entryStorage = Get-PreferredVMStorage -Storage $storage -MinimumFreeGb $entry.min_free_storage_gb
        $entryStorageFreeGb = if ($entryStorage) { [double]$entryStorage.free_gb } else { 0 }

        if ($UserGoal.guest_preference -eq [string]$entry.family) {
            $score += 18
        }
        elseif ($UserGoal.guest_preference -ne 'auto') {
            $score -= 12
        }

        $score += Get-ModeFitScore -RequestedMode $UserGoal.mode -EntryMode $entry.typical_vm_fit

        if ($entry.general_purpose_vm_use) {
            $score += 4
        }

        if ($entry.low_end_host_friendly -and $hostConstrained) {
            $score += 8
        }

        if ($entry.enterprise_windows_testing) {
            if ($hostStrong -and $entry.family -eq 'windows') {
                $score += 5
            }
            else {
                $score -= 1
            }
        }

        if (-not $virtualizationReady) {
            Add-UniqueText -List $entryBlockers -Text 'Hardware virtualization must be enabled before a practical VM can be recommended.'
        }

        if ($HostProfile.memory.total_gb -lt [double]$entry.min_host_ram_gb) {
            Add-UniqueText -List $entryBlockers -Text ('This guest expects at least {0} GB of host RAM.' -f $entry.min_host_ram_gb)
        }

        if (-not $entryStorage) {
            Add-UniqueText -List $entryBlockers -Text ('No suitable local fixed drive has enough free space for {0}.' -f $entry.display_name)
        }

        if ($entry.requires_uefi -and $HostProfile.firmware.boot_mode -ne 'UEFI') {
            Add-UniqueText -List $entryBlockers -Text 'UEFI boot mode was not detected.'
        }

        if ($entry.requires_secure_boot -and -not $HostProfile.firmware.secure_boot) {
            Add-UniqueText -List $entryBlockers -Text 'Secure Boot is required for this guest but was not confirmed.'
        }

        if ($entry.requires_tpm -and -not $hasTpm20) {
            Add-UniqueText -List $entryBlockers -Text 'TPM 2.0 is required for this guest but was not confirmed.'
        }

        if ($entry.family -eq 'windows') {
            if ($HostProfile.memory.total_gb -ge $thresholds.host_strong_memory_gb) {
                $score += 8
            }
            elseif ($HostProfile.memory.total_gb -ge $thresholds.windows10_min_memory_gb) {
                $score += 4
            }

            if ($entryStorageFreeGb -ge $thresholds.windows11_good_storage_gb) {
                $score += 8
            }
            elseif ($entryStorageFreeGb -ge $entry.min_free_storage_gb) {
                $score += 4
            }

            if ($HostProfile.cpu.slat_supported) {
                $score += 2
            }

            if ($HostProfile.firmware.boot_mode -eq 'UEFI') {
                $score += 2
            }
        }
        else {
            if ($HostProfile.memory.total_gb -ge $thresholds.readiness_limited_ram_gb) {
                $score += 8
            }
            elseif ($HostProfile.memory.total_gb -ge $entry.min_host_ram_gb) {
                $score += 4
            }

            if ($entryStorageFreeGb -ge $thresholds.readiness_limited_storage_free_gb) {
                $score += 8
            }
            elseif ($entryStorageFreeGb -ge $entry.min_free_storage_gb) {
                $score += 4
            }

            if ($defaultPreferredType -eq 'HDD' -and $entry.low_end_host_friendly) {
                $score += 3
            }
        }

        if ([string]$entry.display_name -like 'Windows 11*') {
            if ($windows11Suitability.supported) {
                $score += [int][math]::Floor([double]$windows11Suitability.score / 4)
            }
            else {
                foreach ($warning in @($windows11Suitability.warnings)) {
                    Add-UniqueText -List $entryBlockers -Text ([string]$warning)
                }
            }
        }

        if ($VMReadiness.state -eq 'not_ready') {
            Add-UniqueText -List $entryBlockers -Text $VMReadiness.primary_reason
        }

        $profileInfo = $null
        $label = 'not_recommended'
        if ($entryBlockers.Count -eq 0) {
            $profileNotes = New-Object System.Collections.ArrayList
            $profileFamily = Get-ProfileFamily -Entry $entry
            $isNonWindowsGuest = [bool]($profileFamily -ne 'windows')
            $familyProfiles = $thresholds.profiles.$profileFamily
            $memoryTiers = @(Get-MemoryTiers -Family $profileFamily)
            $fitOffsets = @{
                light       = -1
                balanced    = 0
                performance = 1
            }

            $requestedIndex = Get-LevelIndex -Name $UserGoal.mode
            $fitOffset = [int]$fitOffsets[[string]$entry.typical_vm_fit]
            $targetLevelName = Get-LevelName -Index (Clamp-Level -Index ($requestedIndex + $fitOffset))
            $targetProfile = $familyProfiles.$targetLevelName
            $targetVcpu = [int]$targetProfile.vcpu
            $targetMemoryMb = [int]$targetProfile.memory_mb
            $targetDiskGb = [int]$targetProfile.disk_gb

            $minMemoryMb = if ($profileFamily -eq 'windows') {
                [int]$thresholds.windows_guest_min_memory_mb
            }
            else {
                [int]$thresholds.linux_guest_min_memory_mb
            }
            $minimumMemoryTier = Get-LowestTierAtOrAbove -Tiers $memoryTiers -LimitMb $minMemoryMb
            $memoryReducedStructurally = $false

            $vcpuCap = [math]::Max(1, [int][math]::Floor([double]$HostProfile.cpu.threads / 2))
            $vcpu = [math]::Min($targetVcpu, $vcpuCap)
            $profileAdjusted = $false
            if ($vcpu -lt $targetVcpu) {
                [void]$profileNotes.Add(('vCPU was reduced from {0} to {1} to stay within host CPU capacity.' -f $targetVcpu, $vcpu))
                $profileAdjusted = $true
            }

            $memoryCapMb = [math]::Max(0, [int][math]::Floor(([double]$HostProfile.memory.total_gb - $thresholds.host_reserved_memory_gb) * 1024))
            $structuralMemoryLimitMb = [math]::Min($targetMemoryMb, $memoryCapMb)
            $memoryMb = Get-HighestTierAtOrBelow -Tiers $memoryTiers -LimitMb $structuralMemoryLimitMb
            if ($null -eq $memoryMb -or $memoryMb -lt $minimumMemoryTier) {
                $memoryMb = $minimumMemoryTier
            }
            if ($memoryMb -lt $targetMemoryMb) {
                $profileAdjusted = $true
                $memoryReducedStructurally = $true
            }

            $freeMemoryTight = $false
            $freeMemoryAdjusted = $false
            if ($null -ne $HostProfile.memory.free_gb) {
                $operationalFreeMemoryMb = [math]::Max(0, [int][math]::Floor(([double]$HostProfile.memory.free_gb * 1024) - 512))
                if ($operationalFreeMemoryMb -lt $memoryMb) {
                    $operationalTier = Get-HighestTierAtOrBelow -Tiers $memoryTiers -LimitMb $operationalFreeMemoryMb
                    if ($null -ne $operationalTier -and $operationalTier -ge $minimumMemoryTier -and $operationalTier -lt $memoryMb) {
                        $memoryMb = $operationalTier
                        $profileAdjusted = $true
                        $freeMemoryAdjusted = $true
                        $freeMemoryTight = $true
                    }
                    else {
                        if ($memoryMb -gt $minimumMemoryTier) {
                            $memoryMb = $minimumMemoryTier
                            $profileAdjusted = $true
                            $freeMemoryAdjusted = $true
                        }
                        else {
                            [void]$profileNotes.Add((Get-FreeMemoryAdvisoryNote))
                        }
                        $freeMemoryTight = $true
                    }
                }
            }

            $diskCapGb = [math]::Max(0, [int][math]::Floor($entryStorageFreeGb - $thresholds.host_reserved_disk_gb))
            $diskGb = [math]::Min($targetDiskGb, $diskCapGb)
            if ($diskGb -lt $targetDiskGb) {
                [void]$profileNotes.Add(('Disk size was reduced from {0} GB to {1} GB to stay within the preferred VM storage location.' -f $targetDiskGb, $diskGb))
                $profileAdjusted = $true
            }

            $minimumDiskGb = if ($profileFamily -eq 'windows') {
                [int]$thresholds.windows_guest_min_disk_gb
            }
            else {
                [int]$thresholds.linux_guest_min_disk_gb
            }
            if ($diskGb -lt $minimumDiskGb) {
                Add-UniqueText -List $entryBlockers -Text ('The best local VM storage location still does not leave enough room for {0}.' -f $entry.display_name)
            }
            else {
                if ($profileNotes.Count -gt 0 -or $freeMemoryAdjusted -or $memoryReducedStructurally) {
                    $consolidatedProfileNotes = New-Object System.Collections.ArrayList
                    foreach ($profileNote in @($profileNotes)) {
                        $text = [string]$profileNote
                        [void]$consolidatedProfileNotes.Add($text)
                    }

                    if ($freeMemoryAdjusted) {
                        [void]$consolidatedProfileNotes.Insert(0, (Get-FreeMemoryAdjustedNote -FinalMemoryMb $memoryMb))
                    }
                    elseif ($memoryReducedStructurally) {
                        [void]$consolidatedProfileNotes.Insert(0, (Get-StructuralMemoryReductionNote -FinalMemoryMb $memoryMb))
                    }

                    $profileNotes = $consolidatedProfileNotes
                }

                $firmware = if ($entry.requires_uefi -or $HostProfile.firmware.boot_mode -eq 'UEFI') { 'UEFI' } else { 'BIOS' }
                $profileInfo = [pscustomobject]@{
                    reduced              = $profileAdjusted
                    free_memory_adjusted = $freeMemoryAdjusted
                    free_memory_tight    = $freeMemoryTight
                    notes   = @($profileNotes)
                    profile = [pscustomobject]@{
                        vcpu             = $vcpu
                        memory_mb        = $memoryMb
                        disk_gb          = $diskGb
                        firmware         = $firmware
                        secure_boot      = [bool]$entry.requires_secure_boot
                        tpm              = [bool]$entry.requires_tpm
                        network          = 'NAT'
                        storage_location = [string]$entryStorage.drive_letter
                    }
                }
            }
        }

        if ($profileInfo) {
            if ($profileInfo.free_memory_adjusted) {
                if ($entry.family -eq 'windows') {
                    $score -= 8
                }
                elseif ($entry.typical_vm_fit -eq 'light') {
                    $score -= 2
                }
                else {
                    $score -= 5
                }
            }
            elseif ($profileInfo.free_memory_tight) {
                if ($entry.family -eq 'windows') {
                    $score -= 10
                }
                elseif ($entry.typical_vm_fit -eq 'light') {
                    $score -= 3
                }
                else {
                    $score -= 6
                }
            }
        }

        if ($entryBlockers.Count -eq 0 -and $profileInfo) {
            $score += Get-DefaultDesktopFitAdjustment -Entry $entry
            $score += Get-ResourceTierAdjustment -Entry $entry -HostStrong $hostStrong -HostConstrained $hostConstrained -FreeMemoryTight ([bool]$profileInfo.free_memory_tight)
            $score += Get-RoleAdjustment -Entry $entry -HostStrong $hostStrong -HostConstrained $hostConstrained -FreeMemoryTight ([bool]$profileInfo.free_memory_tight)
        }

        if ($entryBlockers.Count -eq 0 -and $profileInfo -and $hypervisorDecision.status -ne 'blocked') {
            if ([string]$entry.display_name -like 'Windows 11*') {
                if ($windows11Suitability.supported -and $score -ge 96 -and -not $profileInfo.reduced) {
                    $label = 'recommended'
                }
                elseif ($score -ge 80) {
                    $label = 'possible'
                }
            }
            elseif ([string]$entry.id -eq 'windows-10') {
                if ($score -ge 82 -and -not $profileInfo.reduced) {
                    $label = 'recommended'
                }
                elseif ($score -ge 70) {
                    $label = 'possible'
                }
            }
            elseif ($isNonWindowsGuest) {
                $roleThresholds = Get-RoleLabelThresholds -Entry $entry -HostStrong $hostStrong -HostConstrained $hostConstrained
                if ($score -ge $roleThresholds.recommended) {
                    $label = 'recommended'
                }
                elseif ($score -ge $roleThresholds.possible) {
                    $label = 'possible'
                }

                if ($label -eq 'recommended' -and $profileInfo.reduced -and $entry.role -notin @('mainstream_desktop', 'lightweight_desktop')) {
                    $label = 'possible'
                }
            }

            if ($label -eq 'not_recommended' -and $isNonWindowsGuest) {
                $roleThresholds = Get-RoleLabelThresholds -Entry $entry -HostStrong $hostStrong -HostConstrained $hostConstrained
                if ($score -ge $roleThresholds.possible) {
                    $label = 'possible'
                }
            }
            elseif ($label -eq 'not_recommended' -and $score -ge 68) {
                $label = 'possible'
            }

        }

        if ($hypervisorDecision.status -eq 'blocked') {
            $label = 'not_recommended'
            $profileInfo = $null
            Add-UniqueText -List $entryBlockers -Text 'Resolve the host blockers before creating a practical VM.'
        }

        if ($hypervisorDecision.note) {
            Add-UniqueText -List $entryNotes -Text ([string]$hypervisorDecision.note)
        }

        if ($profileInfo) {
            if ($entryStorage -and -not $entryStorage.is_system_drive) {
                Add-UniqueText -List $entryNotes -Text ('Use {0} as the preferred VM storage location for this guest.' -f $entryStorage.drive_letter)
            }
            foreach ($profileNote in @($profileInfo.notes)) {
                Add-UniqueText -List $entryNotes -Text ([string]$profileNote)
            }
        }

        if (-not $profileInfo) {
            $filteredNotes = New-Object System.Collections.ArrayList
            foreach ($existingNote in @($entryNotes)) {
                $text = [string]$existingNote
                if (
                    $text -and
                    $text -notmatch '^Use .+ as the preferred VM storage location' -and
                    $text -notmatch '^RAM was reduced to ' -and
                    $text -notmatch '^RAM is starting at ' -and
                    $text -notmatch '^(vCPU|RAM|Disk size) was reduced from ' -and
                    $text -notmatch '^Current free RAM is tighter than ideal for this starting profile'
                ) {
                    [void]$filteredNotes.Add($text)
                }
            }
            $entryNotes = $filteredNotes
        }

        if ($label -eq 'not_recommended') {
            $filteredNotes = New-Object System.Collections.ArrayList
            foreach ($existingNote in @($entryNotes)) {
                $text = [string]$existingNote
                if (
                    $text -and
                    $text -notmatch '^Use .+ as the preferred VM storage location' -and
                    $text -notmatch '^RAM was reduced to ' -and
                    $text -notmatch '^RAM is starting at ' -and
                    $text -notmatch '^(vCPU|RAM|Disk size) was reduced from ' -and
                    $text -notmatch '^Current free RAM is tighter than ideal for this starting profile'
                ) {
                    [void]$filteredNotes.Add($text)
                }
            }
            $entryNotes = $filteredNotes
            $fitReason = if ($entryBlockers.Count -gt 0) {
                [string]$entryBlockers[0]
            }
            elseif ([string]$entry.scope_note) {
                [string]$entry.scope_note
            }
            elseif ([string]$entry.id -eq 'rocky-linux') {
                'Enterprise-style Linux guest better suited to server-like or lab-oriented VM use than to a default everyday desktop VM.'
            }
            else {
                'This guest is not a practical fit for the current host conditions.'
            }
            if ([string]$entry.scope_note) {
                $filteredNotes = New-Object System.Collections.ArrayList
                foreach ($existingNote in @($entryNotes)) {
                    $text = [string]$existingNote
                    if ($text -and $text -notmatch '(?i)specialist security-lab guest|default everyday desktop choice') {
                        [void]$filteredNotes.Add($text)
                    }
                }
                $entryNotes = $filteredNotes
            }
            $profileInfo = $null
        }
        else {
            $fitReason = Get-FitReasonTemplate -Entry $entry -Label $label
        }

        $sortScore = $score
        switch ($label) {
            'recommended' { $sortScore += 30 }
            'possible' { $sortScore += 10 }
            default { $sortScore -= 20 }
        }

        [void]$scoredEntries.Add([pscustomobject]@{
            sort_score = $sortScore
            item       = [pscustomobject]@{
                id                     = [string]$entry.id
                display_name           = [string]$entry.display_name
                family                 = [string]$entry.family
                flavor                 = [string]$entry.flavor
                category               = [string]$entry.category
                architecture           = [string]$entry.architecture
                official_download_page = [string]$entry.official_download_page
                official_release_page  = [string]$entry.official_release_page
                compatibility_label    = $label
                fit_reason             = $fitReason
                preferred_hypervisor   = [string]$hypervisorDecision.name
                vm_profile             = if ($profileInfo) { $profileInfo.profile } else { $null }
                notes                  = @($entryNotes)
                _material_free_memory_pressure = [bool]($profileInfo -and $profileInfo.free_memory_adjusted)
            }
        })
    }

    $sortedRecommendations = @(
        $scoredEntries |
        Sort-Object -Property @{ Expression = 'sort_score'; Descending = $true }, @{ Expression = { $_.item.display_name }; Descending = $false } |
        ForEach-Object { $_.item }
    )

    $recommendedLimit = if ($VMReadiness.state -eq 'limited') {
        2
    }
    elseif ($hostStrong) {
        4
    }
    else {
        3
    }
    $recommendedKept = 0

    foreach ($recommendation in $sortedRecommendations) {
        if ([string]$recommendation.compatibility_label -ne 'recommended') {
            continue
        }

        $demoteToPossible = $false
        if ($recommendedKept -ge $recommendedLimit) {
            $demoteToPossible = $true
        }
        elseif ($VMReadiness.state -eq 'limited' -and $recommendation.family -eq 'windows') {
            $demoteToPossible = $true
        }
        elseif (-not $hostStrong -and $recommendation.id -eq 'fedora-workstation') {
            $demoteToPossible = $true
        }
        if ($demoteToPossible) {
            $recommendation.compatibility_label = 'possible'
            $recommendation.fit_reason = Get-FitReasonTemplate -Entry $recommendation -Label 'possible'
            continue
        }

        $recommendedKept++
    }

    $windows10 = @($sortedRecommendations | Where-Object { $_.id -eq 'windows-10' } | Select-Object -First 1)[0]
    $windows11 = @($sortedRecommendations | Where-Object { $_.id -eq 'windows-11' } | Select-Object -First 1)[0]
    if ($windows10 -and $windows11) {
        $labelRank = @{
            recommended     = 3
            possible        = 2
            not_recommended = 1
        }
        $preferWindows10 = $false
        if ($labelRank[[string]$windows10.compatibility_label] -gt $labelRank[[string]$windows11.compatibility_label]) {
            $preferWindows10 = $true
        }
        elseif (
            $labelRank[[string]$windows10.compatibility_label] -eq $labelRank[[string]$windows11.compatibility_label] -and
            [string]$VMReadiness.state -eq 'limited'
        ) {
            $preferWindows10 = $true
        }

        if ($preferWindows10) {
            $windows10Index = @($sortedRecommendations | Select-Object -ExpandProperty id).IndexOf('windows-10')
            $windows11Index = @($sortedRecommendations | Select-Object -ExpandProperty id).IndexOf('windows-11')

            if ($windows10Index -ge 0 -and $windows11Index -ge 0 -and $windows10Index -gt $windows11Index) {
                $temp = $sortedRecommendations[$windows11Index]
                $sortedRecommendations[$windows11Index] = $sortedRecommendations[$windows10Index]
                $sortedRecommendations[$windows10Index] = $temp
            }
        }
    }

    $finalRecommendations = @(
        @($sortedRecommendations | Where-Object { [string]$_.compatibility_label -eq 'recommended' })
        @($sortedRecommendations | Where-Object { [string]$_.compatibility_label -eq 'possible' })
        @($sortedRecommendations | Where-Object { [string]$_.compatibility_label -eq 'not_recommended' })
    )

    return @($finalRecommendations)
}
