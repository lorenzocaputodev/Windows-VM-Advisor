Describe 'Get-IsoRecommendations hypervisor preference' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        foreach ($relativePath in @(Get-AdvisorRulePaths)) {
            . (Join-Path $script:ProjectRoot $relativePath)
        }
    }

    It 'keeps a requested VirtualBox when only Hyper-V is enabled and the score gap is small' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hypervisors = New-HypervisorProfile -HyperVEnabled $true
        $goal = New-UserGoal -GuestPreference 'linux' -HypervisorPreference 'virtualbox'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal
        $entry = @($result.recommendations | Where-Object { $_.id -eq 'linux-mint' })[0]

        $entry.preferred_hypervisor | Should -Be 'Oracle VirtualBox'
    }

    It 'keeps a requested VMware when Hyper-V and Memory Integrity are enabled' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hypervisors = New-HypervisorProfile -HyperVEnabled $true -MemoryIntegrityEnabled $true
        $goal = New-UserGoal -GuestPreference 'linux' -HypervisorPreference 'vmware'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal
        $entry = @($result.recommendations | Where-Object { $_.id -eq 'linux-mint' })[0]

        $entry.preferred_hypervisor | Should -Be 'VMware Workstation'
    }
}
