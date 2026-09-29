Describe 'Get-VMReadiness host architecture' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        foreach ($relativePath in @(Get-AdvisorRulePaths)) {
            . (Join-Path $script:ProjectRoot $relativePath)
        }
    }

    It 'blocks ARM hosts because the catalog only contains x64 guests' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.os.architecture = 'ARM 64-bit Processor'

        $result = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile (New-HypervisorProfile)

        $result.state | Should -Be 'not_ready'
        (@($result.blockers | Where-Object { $_ -match 'ARM host' }).Count) | Should -Be 1
    }

    It 'blocks 32-bit hosts' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.os.architecture = '32-bit'

        $result = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile (New-HypervisorProfile)

        $result.state | Should -Be 'not_ready'
        ($result.blockers -contains 'A 32-bit host cannot run 64-bit guests.') | Should -BeTrue
    }

    It 'accepts 64-bit hosts and does not block an unknown architecture' -ForEach @(
        @{ Architecture = '64-bit' }
        @{ Architecture = 'Unknown' }
    ) {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.os.architecture = $Architecture

        $result = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile (New-HypervisorProfile)

        $result.state | Should -Be 'ok'
        @($result.blockers).Count | Should -Be 0
    }
}
