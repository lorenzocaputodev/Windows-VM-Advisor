function Test-Windows11Suitability {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$HostProfile
    )

    $thresholds = Get-AdvisorThresholds
    $storage = $HostProfile.storage
    $preferredStorage = $null

    if ($storage -and (@($storage.PSObject.Properties.Name) -contains 'preferred_vm_storage')) {
        $preferredStorage = $storage.preferred_vm_storage
    }

    if (-not $preferredStorage) {
        $preferredStorage = Get-PreferredVMStorage -Storage $storage -MinimumFreeGb $thresholds.windows11_min_storage_gb
    }

    $nominalMemoryGb = Get-NominalMemoryGb -ReportedGb ([double]$HostProfile.memory.total_gb)
    $availableStorageGb = if ($preferredStorage) { [double]$preferredStorage.free_gb } else { 0 }
    $score = 0
    $reasons = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]
    $status = 'limited'
    $supported = $true

    if (-not $HostProfile.cpu.virtualization_supported) {
        $warnings.Add('CPU virtualization extensions are not available.')
        return [pscustomobject]@{
            supported = $false
            status    = 'blocked'
            score     = 0
            reasons   = @()
            warnings  = @($warnings)
        }
    }

    if (-not $HostProfile.cpu.virtualization_enabled_in_firmware) {
        $warnings.Add('Hardware virtualization appears disabled in firmware.')
        return [pscustomobject]@{
            supported = $false
            status    = 'blocked'
            score     = 0
            reasons   = @()
            warnings  = @($warnings)
        }
    }

    # The guest gets a virtual TPM, UEFI firmware and Secure Boot from the hypervisor,
    # so those host capabilities do not gate a Windows 11 recommendation.
    if ($nominalMemoryGb -ge $thresholds.windows11_good_memory_gb) {
        $score += 40
        $reasons.Add('Host has enough RAM for a balanced Windows 11 guest.')
    }
    elseif ($nominalMemoryGb -ge $thresholds.windows11_min_memory_gb) {
        $score += 20
        $warnings.Add('Host RAM is usable but may be limiting for a comfortable Windows 11 VM.')
    }
    else {
        $warnings.Add('Host RAM is too low for a practical Windows 11 VM recommendation.')
        $supported = $false
    }

    if ($availableStorageGb -ge $thresholds.windows11_good_storage_gb) {
        $score += 40
        $reasons.Add('A suitable local drive has enough free storage for a Windows 11 guest disk.')
    }
    elseif ($availableStorageGb -ge $thresholds.windows11_min_storage_gb) {
        $score += 20
        $warnings.Add('The best local VM storage location is workable but still tight for a Windows 11 guest.')
    }
    else {
        $warnings.Add('No suitable local drive has enough free storage for a comfortable Windows 11 guest.')
        $supported = $false
    }

    if ($HostProfile.cpu.slat_supported) {
        $score += 20
        $reasons.Add('SLAT support is available.')
    }

    if (-not $supported) {
        $status = 'limited'
    }
    elseif ($score -ge 70) {
        $status = 'good'
    }
    else {
        $status = 'limited'
    }

    [pscustomobject]@{
        supported = $supported
        status    = $status
        score     = $score
        reasons   = @($reasons)
        warnings  = @($warnings)
    }
}
