function Test-VMwareSuitability {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$HostProfile,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$HypervisorProfile
    )

    $score = 65
    $reasons = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]
    $status = 'good'

    $reasons.Add('VMware Workstation is a strong general-purpose option for Windows hosts.')

    if ($HypervisorProfile.vmware_workstation_installed) {
        $score += 15
        $reasons.Add('VMware Workstation is already installed.')
    }

    if (-not $HostProfile.cpu.virtualization_supported -or -not $HostProfile.cpu.virtualization_enabled_in_firmware) {
        $score = 0
        $status = 'blocked'
        $warnings.Add('Virtualization support is missing or disabled.')
    }

    if ($HypervisorProfile.hyperv_enabled) {
        $score -= 10
        $status = 'limited'
        $warnings.Add('Hyper-V may affect VMware performance depending on host configuration.')
    }

    if ($HypervisorProfile.memory_integrity_enabled) {
        $score -= 5
        $status = 'limited'
        $warnings.Add('Memory Integrity may reduce virtualization smoothness on some hosts.')
    }

    [pscustomobject]@{
        name     = 'VMware Workstation'
        score    = [math]::Max($score, 0)
        status   = $status
        reasons  = @($reasons)
        warnings = @($warnings)
    }
}
