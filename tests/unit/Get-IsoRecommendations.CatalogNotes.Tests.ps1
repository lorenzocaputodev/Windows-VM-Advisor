Describe 'Get-IsoRecommendations catalog notes and openSUSE' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        foreach ($relativePath in @(Get-AdvisorRulePaths)) {
            . (Join-Path $script:ProjectRoot $relativePath)
        }

        function Get-Ranked {
            param([string]$Fixture)

            $hostProfile = Get-HostFixture -Name $Fixture
            $hypervisors = New-HypervisorProfile
            $goal = New-UserGoal -GuestPreference 'auto' -Mode 'balanced'
            $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors
            return @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)
        }
    }

    It 'lists openSUSE Leap with its own fit reason' {
        $result = Get-Ranked -Fixture 'host-high-end'
        $suse = @($result | Where-Object { $_.id -eq 'opensuse-leap' })[0]

        $suse.display_name | Should -Be 'openSUSE Leap'
        $suse.family | Should -Be 'linux'
        $suse.fit_reason | Should -Match 'KDE Plasma'
        $suse.vm_profile.memory_mb | Should -BeGreaterThan 0
    }

    It 'keeps guests flagged as strong-host-only out of the recommended tier on a modest host' {
        $result = Get-Ranked -Fixture 'host-midrange'
        $flagged = @($result | Where-Object { $_.id -in @('fedora-workstation', 'opensuse-leap') })

        $flagged.Count | Should -Be 2
        (@($flagged | Where-Object { $_.compatibility_label -eq 'recommended' }).Count) | Should -Be 0
    }

    It 'adds the Rocky Linux CPU requirement note only when the guest has a profile' {
        $withProfile = @((Get-Ranked -Fixture 'host-high-end') | Where-Object { $_.id -eq 'rocky-linux' })[0]
        $withoutProfile = @((Get-Ranked -Fixture 'host-low-end') | Where-Object { $_.id -eq 'rocky-linux' })[0]

        $withProfile.vm_profile | Should -Not -BeNullOrEmpty
        (@($withProfile.notes | Where-Object { $_ -match 'x86-64-v3' }).Count) | Should -Be 1
        $withoutProfile.vm_profile | Should -BeNullOrEmpty
        (@($withoutProfile.notes | Where-Object { $_ -match 'x86-64-v3' }).Count) | Should -Be 0
    }

    It 'points Kali users to the ready-made VM images only when the guest has a profile' {
        $withProfile = @((Get-Ranked -Fixture 'host-high-end') | Where-Object { $_.id -eq 'kali-linux' })[0]
        $withoutProfile = @((Get-Ranked -Fixture 'host-low-end') | Where-Object { $_.id -eq 'kali-linux' })[0]

        (@($withProfile.notes | Where-Object { $_ -match 'ready-made VMware and VirtualBox images' }).Count) | Should -Be 1
        (@($withoutProfile.notes | Where-Object { $_ -match 'ready-made VMware and VirtualBox images' }).Count) | Should -Be 0
    }

    It 'does not attach catalog notes to unrelated guests' {
        $result = Get-Ranked -Fixture 'host-high-end'

        (@($result | Where-Object { $_.id -notin @('rocky-linux', 'kali-linux') } | ForEach-Object { $_.notes } | Where-Object { $_ -match 'x86-64-v3|ready-made' }).Count) | Should -Be 0
    }
}
