Describe 'Hypervisor suitability rules' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        foreach ($relativePath in @(Get-AdvisorRulePaths)) {
            . (Join-Path $script:ProjectRoot $relativePath)
        }
    }

    It 'boosts VMware when it is already installed on a ready host' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hypervisors = New-HypervisorProfile -VmwareInstalled $true

        $result = Test-VMwareSuitability -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result.status | Should -Be 'good'
        ($result.score -gt 65) | Should -BeTrue
    }

    It 'applies Hyper-V and Memory Integrity penalties to VMware without blocking it' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hypervisors = New-HypervisorProfile -HyperVEnabled $true -MemoryIntegrityEnabled $true

        $result = Test-VMwareSuitability -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result.status | Should -Be 'limited'
        (($result.warnings -contains 'Hyper-V may affect VMware performance depending on host configuration.') -and ($result.warnings -contains 'Memory Integrity may reduce virtualization smoothness on some hosts.')) | Should -BeTrue
    }

    It 'blocks VirtualBox when Hyper-V and Memory Integrity are both enabled' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hypervisors = New-HypervisorProfile -HyperVEnabled $true -MemoryIntegrityEnabled $true

        $result = Test-VirtualBoxSuitability -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result.status | Should -Be 'blocked'
        ($result.warnings -contains 'Hyper-V and Memory Integrity together make VirtualBox a poor recommendation on this host.') | Should -BeTrue
    }

    It 'blocks both hypervisors when virtualization is disabled in firmware' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.cpu.virtualization_enabled_in_firmware = $false
        $hypervisors = New-HypervisorProfile

        $vmware = Test-VMwareSuitability -HostProfile $hostProfile -HypervisorProfile $hypervisors
        $virtualBox = Test-VirtualBoxSuitability -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $vmware.status | Should -Be 'blocked'
        $virtualBox.status | Should -Be 'blocked'
    }
}
