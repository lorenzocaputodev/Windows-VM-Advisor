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

    if ($HostProfile.memory.total_gb -ge $thresholds.windows11_good_memory_gb) {
        $score += 20
        $reasons.Add('Host has enough RAM for a balanced Windows 11 guest.')
    }
    elseif ($HostProfile.memory.total_gb -ge $thresholds.windows11_min_memory_gb) {
        $score += 10
        $warnings.Add('Host RAM is usable but may be limiting for a comfortable Windows 11 VM.')
    }
    else {
        $warnings.Add('Host RAM is too low for a practical Windows 11 VM recommendation.')
        $supported = $false
    }

    if ($availableStorageGb -ge $thresholds.windows11_good_storage_gb) {
        $score += 20
        $reasons.Add('A suitable local drive has enough free storage for a Windows 11 guest disk.')
    }
    elseif ($availableStorageGb -ge $thresholds.windows11_min_storage_gb) {
        $score += 10
        $warnings.Add('The best local VM storage location is workable but still tight for a Windows 11 guest.')
    }
    else {
        $warnings.Add('No suitable local drive has enough free storage for a comfortable Windows 11 guest.')
        $supported = $false
    }

    if ($HostProfile.firmware.boot_mode -eq 'UEFI') {
        $score += 15
        $reasons.Add('UEFI boot mode is available.')
    }
    else {
        $warnings.Add('UEFI was not detected.')
        $supported = $false
    }

    if ($HostProfile.firmware.secure_boot) {
        $score += 15
        $reasons.Add('Secure Boot is available.')
    }
    else {
        $warnings.Add('Secure Boot is not available or could not be confirmed.')
        $supported = $false
    }

    if ($HostProfile.security.tpm_present -and $HostProfile.security.tpm_ready -and ($HostProfile.security.tpm_version -match '2\.0')) {
        $score += 20
        $reasons.Add('TPM 2.0 is available.')
    }
    else {
        $warnings.Add('TPM 2.0 was not confirmed.')
        $supported = $false
    }

    if ($HostProfile.cpu.slat_supported) {
        $score += 10
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
