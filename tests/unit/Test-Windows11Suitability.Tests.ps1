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

    It 'returns limited when Secure Boot or TPM are missing' {
        $hostProfile = Get-HostFixture -Name 'host-midrange'

        $result = Test-Windows11Suitability -HostProfile $hostProfile

        $result.supported | Should -BeFalse
        $result.status | Should -Be 'limited'
        (($result.warnings -contains 'Secure Boot is not available or could not be confirmed.') -and ($result.warnings -contains 'TPM 2.0 was not confirmed.')) | Should -BeTrue
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
