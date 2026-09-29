Describe 'Test-Windows11Suitability' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        foreach ($relativePath in @(Get-AdvisorRulePaths)) {
            . (Join-Path $script:ProjectRoot $relativePath)
        }
    }

    It 'returns good support for a strong host profile' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'

        $result = Test-Windows11Suitability -HostProfile $hostProfile

        $result.supported | Should -BeTrue
        $result.status | Should -Be 'good'
        ($result.score -ge 80) | Should -BeTrue
    }

    It 'does not require host TPM, Secure Boot or UEFI because the hypervisor provides them to the guest' {
        $hostProfile = Get-HostFixture -Name 'host-midrange'
        $hostProfile.firmware.boot_mode = 'BIOS'

        $result = Test-Windows11Suitability -HostProfile $hostProfile

        $result.supported | Should -BeTrue
        $result.status | Should -Be 'good'
        (@($result.warnings | Where-Object { $_ -match 'TPM|Secure Boot|UEFI' }).Count) | Should -Be 0
    }

    It 'treats an 8 GB host that reports 7.6 GB as meeting the Windows 11 minimum' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.memory.total_gb = 7.6

        $result = Test-Windows11Suitability -HostProfile $hostProfile

        $result.supported | Should -BeTrue
        ($result.warnings -contains 'Host RAM is too low for a practical Windows 11 VM recommendation.') | Should -BeFalse
    }

    It 'returns limited when RAM and storage are below Windows 11 thresholds' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.memory.total_gb = 6
        $hostProfile.storage.system_drive_free_gb = 50
        $hostProfile.storage.drives[0].free_gb = 50
        $hostProfile.storage.drives[0].vm_storage_suitable = $true
        $hostProfile.storage.preferred_vm_storage.free_gb = 50

        $result = Test-Windows11Suitability -HostProfile $hostProfile

        $result.supported | Should -BeFalse
        $result.status | Should -Be 'limited'
        (($result.warnings -contains 'Host RAM is too low for a practical Windows 11 VM recommendation.') -and ($result.warnings -contains 'No suitable local drive has enough free storage for a comfortable Windows 11 guest.')) | Should -BeTrue
    }

    It 'returns blocked when firmware virtualization is disabled' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.cpu.virtualization_enabled_in_firmware = $false

        $result = Test-Windows11Suitability -HostProfile $hostProfile

        $result.supported | Should -BeFalse
        $result.status | Should -Be 'blocked'
    }
}
