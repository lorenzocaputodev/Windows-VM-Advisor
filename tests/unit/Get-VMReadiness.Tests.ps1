Describe 'Get-VMReadiness' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        foreach ($relativePath in @(Get-AdvisorRulePaths)) {
            . (Join-Path $script:ProjectRoot $relativePath)
        }
    }

    It 'returns ok for a strong host with no blockers or limitations' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hypervisors = New-HypervisorProfile

        $result = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result.state | Should -Be 'ok'
        @($result.blockers).Count | Should -Be 0
        @($result.limitations).Count | Should -Be 0
    }

    It 'returns limited for a modest host that is still usable for lighter VMs' {
        $hostProfile = Get-HostFixture -Name 'host-low-end'
        $hypervisors = New-HypervisorProfile

        $result = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result.state | Should -Be 'limited'
        ($result.limitations -contains 'Host RAM is better suited to lighter guest options.') | Should -BeTrue
        ($result.limitations -contains 'VM storage is available on C:, but free space is still best kept for lighter or conservative guest disks.') | Should -BeTrue
    }

    It 'warns when host free RAM is low without changing readiness state by itself' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.memory.free_gb = 3.8
        $hypervisors = New-HypervisorProfile

        $result = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors
        $freeMemoryCheck = @($result.checks | Where-Object { $_.id -eq 'host-free-memory' })[0]

        $result.state | Should -Be 'ok'
        ($result.limitations -contains 'Host free RAM is low. Close other applications before starting a VM.') | Should -BeTrue
        $freeMemoryCheck.status | Should -Be 'warning'
        $freeMemoryCheck.label | Should -Be 'Host free memory'
    }

    It 'keeps the host usable when the system drive is tight but a secondary fixed drive is suitable' {
        $hostProfile = Get-HostFixture -Name 'host-secondary-storage'
        $hypervisors = New-HypervisorProfile

        $result = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result.state | Should -Be 'limited'
        ($result.blockers -contains 'No local fixed drive has enough free space for a practical VM disk.') | Should -BeFalse
        ($result.limitations -contains 'System drive free space is low, but D: is the better local drive for VM storage.') | Should -BeTrue
        (@($result.checks | Where-Object { $_.id -eq 'vm-storage-availability' })[0].status) | Should -Be 'ok'
    }

    It 'returns not_ready when no suitable fixed drive is available for practical VM storage' {
        $hostProfile = Get-HostFixture -Name 'host-secondary-storage'
        foreach ($drive in @($hostProfile.storage.drives)) {
            $drive.free_gb = 30
            $drive.vm_storage_suitable = $false
        }
        $hostProfile.storage.system_drive_free_gb = 30
        $hostProfile.storage.preferred_vm_storage = $null
        $hypervisors = New-HypervisorProfile

        $result = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result.state | Should -Be 'not_ready'
        ($result.blockers -contains 'No local fixed drive has enough free space for a practical VM disk.') | Should -BeTrue
    }

    It 'returns not_ready when firmware virtualization is disabled' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.cpu.virtualization_enabled_in_firmware = $false
        $hypervisors = New-HypervisorProfile

        $result = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result.state | Should -Be 'not_ready'
        ($result.blockers -contains 'Hardware virtualization appears disabled in BIOS or UEFI.') | Should -BeTrue
    }
}
