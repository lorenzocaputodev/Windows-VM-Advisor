function Test-VirtualBoxSuitability {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$HostProfile,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$HypervisorProfile
    )

    $score = 60
    $reasons = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]
    $status = 'good'

    $reasons.Add('Oracle VirtualBox is a workable local option when Windows security features are not in the way.')

    if ($HypervisorProfile.virtualbox_installed) {
        $score += 15
        $reasons.Add('VirtualBox is already installed.')
    }

    if (-not $HostProfile.cpu.virtualization_supported -or -not $HostProfile.cpu.virtualization_enabled_in_firmware) {
        $score = 0
        $status = 'blocked'
        $warnings.Add('Virtualization support is missing or disabled.')
    }

    if ($HypervisorProfile.hyperv_enabled -and $HypervisorProfile.memory_integrity_enabled) {
        $score = 0
        $status = 'blocked'
        $warnings.Add('Hyper-V and Memory Integrity together make VirtualBox a poor recommendation on this host.')
    }
    elseif ($HypervisorProfile.hyperv_enabled) {
        $score -= 20
        $status = 'limited'
        $warnings.Add('Hyper-V may reduce compatibility or performance for VirtualBox.')
    }

    if ($status -ne 'blocked' -and $HypervisorProfile.memory_integrity_enabled) {
        $score -= 10
        $status = 'limited'
        $warnings.Add('Memory Integrity may affect VirtualBox behavior on some hosts.')
    }

    [pscustomobject]@{
        name     = 'Oracle VirtualBox'
        score    = [math]::Max($score, 0)
        status   = $status
        reasons  = @($reasons)
        warnings = @($warnings)
    }
}
