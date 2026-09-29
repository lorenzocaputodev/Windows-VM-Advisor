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

    # VirtualBox 6+ can run on top of the Windows Hypervisor Platform, so Hyper-V and
    # Memory Integrity lower the score heavily instead of blocking VirtualBox outright.
    if ($HypervisorProfile.hyperv_enabled) {
        $score -= 20
        if ($status -ne 'blocked') {
            $status = 'limited'
        }
        $warnings.Add('Hyper-V may reduce compatibility or performance for VirtualBox.')
    }

    if ($HypervisorProfile.memory_integrity_enabled) {
        $score -= 10
        if ($status -ne 'blocked') {
            $status = 'limited'
        }
        $warnings.Add('Memory Integrity may affect VirtualBox behavior on some hosts.')
    }

    if ($HypervisorProfile.hyperv_enabled -and $HypervisorProfile.memory_integrity_enabled) {
        $warnings.Add('Hyper-V and Memory Integrity together make VirtualBox a poor recommendation on this host.')
    }

    [pscustomobject]@{
        name     = 'Oracle VirtualBox'
        score    = [math]::Max($score, 0)
        status   = $status
        reasons  = @($reasons)
        warnings = @($warnings)
    }
}
