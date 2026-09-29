Describe 'Get-VMReadiness on hosts that report slightly less RAM than installed' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        foreach ($relativePath in @(Get-AdvisorRulePaths)) {
            . (Join-Path $script:ProjectRoot $relativePath)
        }
    }

    It 'does not flag an 8 GB host that reports 7.6 GB as RAM limited' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.memory.total_gb = 7.6
        $hypervisors = New-HypervisorProfile

        $result = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        ($result.limitations -contains 'Host RAM is better suited to lighter guest options.') | Should -BeFalse
        $result.state | Should -Be 'ok'
    }

    It 'still flags a 6 GB host as RAM limited' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.memory.total_gb = 5.6
        $hypervisors = New-HypervisorProfile

        $result = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        ($result.limitations -contains 'Host RAM is better suited to lighter guest options.') | Should -BeTrue
    }
}
