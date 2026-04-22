Describe 'Get-IsoRecommendations' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        foreach ($relativePath in @(Get-AdvisorRulePaths)) {
            . (Join-Path $script:ProjectRoot $relativePath)
        }
    }

    It 'keeps Kali as a first-class specialist guest without duplicate scope notes when it remains viable' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.memory.total_gb = 4
        $hostProfile.memory.free_gb = 1.5
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'linux' -Mode 'performance'
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)
        $kali = @($result | Where-Object { $_.id -eq 'kali-linux' })[0]

        $kali.compatibility_label | Should -Be 'possible'
        $kali.vm_profile.memory_mb | Should -Be 2048
        ($kali.notes -contains 'RAM was reduced to 2048 MB to stay within more comfortable host-safe limits.') | Should -BeTrue
        ($kali.notes -contains 'Current free RAM is tighter than ideal for this starting profile. Close other applications before starting the VM.') | Should -BeTrue
        ($kali.notes -contains 'This is a specialist security-lab guest, not the default everyday desktop choice.') | Should -BeFalse
    }

    It 'keeps structural blockers ahead of Kali scope wording when the host is truly below minimum' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.memory.total_gb = 3.5
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto' -Mode 'balanced'
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)
        $kali = @($result | Where-Object { $_.id -eq 'kali-linux' })[0]

        $kali.compatibility_label | Should -Be 'not_recommended'
        $kali.fit_reason | Should -Be 'This guest expects at least 4 GB of host RAM.'
        $kali.vm_profile | Should -BeNullOrEmpty
        (@($kali.notes | Where-Object { $_ -match '^RAM was reduced to ' }).Count) | Should -Be 0
        (@($kali.notes | Where-Object { $_ -match '^RAM is starting at ' }).Count) | Should -Be 0
        (@($kali.notes | Where-Object { $_ -match '^Current free RAM is tighter than ideal for this starting profile' }).Count) | Should -Be 0
        (@($kali.notes | Where-Object { $_ -match '^Use .+ as the preferred VM storage location' }).Count) | Should -Be 0
    }

    It 'treats new catalog entries as first-class recommendation members with explicit fit reasons' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto' -Mode 'balanced'
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)
        $arch = @($result | Where-Object { $_.id -eq 'arch-linux' })[0]
        $rocky = @($result | Where-Object { $_.id -eq 'rocky-linux' })[0]
        $freebsd = @($result | Where-Object { $_.id -eq 'freebsd' })[0]
        $nixos = @($result | Where-Object { $_.id -eq 'nixos' })[0]

        $arch.fit_reason | Should -Match 'advanced DIY Linux option|manual setup'
        $rocky.fit_reason | Should -Match 'enterprise-style Linux guest|server-like'
        $freebsd.fit_reason | Should -Match 'Unix-like guest|lab-oriented'
        $nixos.fit_reason | Should -Match 'declarative Linux option|reproducible environments'
        $freebsd.family | Should -Be 'bsd'
        $arch.compatibility_label | Should -Not -BeNullOrEmpty
        $rocky.compatibility_label | Should -Not -BeNullOrEmpty
        $freebsd.compatibility_label | Should -Not -BeNullOrEmpty
        $nixos.compatibility_label | Should -Not -BeNullOrEmpty
        $arch.vm_profile.memory_mb | Should -BeGreaterThan 0
        $rocky.vm_profile.memory_mb | Should -BeGreaterThan 0
        $freebsd.vm_profile.memory_mb | Should -BeGreaterThan 0
        $nixos.vm_profile.memory_mb | Should -BeGreaterThan 0
    }

    It 'keeps VM memory profiles on standard tiers and adds an operational free-RAM note on a strong host with low free RAM' {
        $hostProfile = Get-HostFixture -Name 'host-secondary-storage'
        $hostProfile.memory.total_gb = 16.0
        $hostProfile.memory.free_gb = 3.7
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto' -Mode 'balanced'
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)
        $linuxMint = @($result | Where-Object { $_.id -eq 'linux-mint' })[0]
        $windows10 = @($result | Where-Object { $_.id -eq 'windows-10' })[0]
        $profileMemoryValues = @(
            $result |
            Where-Object { $null -ne $_.vm_profile } |
            Select-Object -ExpandProperty vm_profile |
            Select-Object -ExpandProperty memory_mb
        )

        $linuxMint.vm_profile.memory_mb | Should -Be 3072
        $windows10.vm_profile.memory_mb | Should -Be 4096
        ($linuxMint.notes -contains 'RAM is starting at 3072 MB because current free RAM is tighter than ideal. Close other applications before starting the VM.') | Should -BeTrue
        ($windows10.notes -contains 'RAM is starting at 4096 MB because current free RAM is tighter than ideal. Close other applications before starting the VM.') | Should -BeTrue
        (@($profileMemoryValues | Where-Object { $_ -notin @(2048, 3072, 4096, 6144, 8192) }).Count) | Should -Be 0
    }

    It 'uses a distinct structural RAM note when host-safe capacity reduces the profile without current free-RAM pressure' {
        $hostProfile = Get-HostFixture -Name 'host-secondary-storage'
        $hostProfile.memory.total_gb = 9.0
        $hostProfile.memory.free_gb = 7.0
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto' -Mode 'performance'
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)
        $linuxMint = @($result | Where-Object { $_.id -eq 'linux-mint' })[0]

        $linuxMint.vm_profile.memory_mb | Should -Be 4096
        ($linuxMint.notes -contains 'RAM was reduced to 4096 MB to stay within more comfortable host-safe limits.') | Should -BeTrue
        (@($linuxMint.notes | Where-Object { $_ -match '^RAM is starting at ' }).Count) | Should -Be 0
    }

    It 'keeps the final ranking coherent on a strong host with low free RAM by leaving Linux ahead overall and Windows 10 ahead of Windows 11 inside the Windows pair' {
        $hostProfile = Get-HostFixture -Name 'host-secondary-storage'
        $hostProfile.memory.total_gb = 16.0
        $hostProfile.memory.free_gb = 3.7
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto' -Mode 'balanced'
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)
        $ids = @($result | Select-Object -ExpandProperty id)

        $ids[0] | Should -Be 'linux-mint'
        $ids.IndexOf('windows-10') | Should -BeLessThan $ids.IndexOf('windows-11')
        $ids.IndexOf('windows-10') | Should -BeGreaterThan $ids.IndexOf('linux-mint')
    }

    It 'returns the final canonical grouped order used by user-facing outputs' {
        $hostProfile = Get-HostFixture -Name 'host-secondary-storage'
        $hostProfile.memory.total_gb = 16.0
        $hostProfile.memory.free_gb = 3.7
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto' -Mode 'balanced'
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)
        $labels = @($result | Select-Object -ExpandProperty compatibility_label)

        $labels | Should -Be @(
            'recommended',
            'recommended',
            'possible',
            'possible',
            'possible',
            'possible',
            'possible',
            'possible',
            'possible',
            'possible',
            'not_recommended',
            'not_recommended'
        )
        @($result | Select-Object -First 2 -ExpandProperty id) | Should -Be @('linux-mint', 'ubuntu-lts')
        $result[2].id | Should -Be 'debian-stable'
    }

    It 'uses only standard memory tiers on a lighter host and lets lighter Linux rise naturally' {
        $hostProfile = Get-HostFixture -Name 'host-low-end'
        $hostProfile.memory.total_gb = 7.6
        $hostProfile.memory.free_gb = 2.6
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto' -Mode 'balanced'
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)
        $topTwoIds = @($result | Select-Object -First 2 -ExpandProperty id)
        $profileMemoryValues = @(
            $result |
            Where-Object { $null -ne $_.vm_profile } |
            Select-Object -ExpandProperty vm_profile |
            Select-Object -ExpandProperty memory_mb
        )

        ($topTwoIds -contains 'debian-stable') | Should -BeTrue
        ($topTwoIds -contains 'lubuntu') | Should -BeTrue
        (@($profileMemoryValues | Where-Object { $_ -notin @(2048, 3072, 4096, 6144, 8192) }).Count) | Should -Be 0
    }

    It 'uses a role-aware FreeBSD reason instead of the generic fallback when role context is the main limitation' {
        $hostProfile = Get-HostFixture -Name 'host-midrange'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto' -Mode 'balanced'
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)
        $freebsd = @($result | Where-Object { $_.id -eq 'freebsd' })[0]

        $freebsd.fit_reason | Should -Be 'Advanced Unix-like guest better suited to technical or lab-oriented VM use than to a default everyday desktop VM.'
    }

    It 'keeps Rocky Linux role-aware on normal hosts and keeps structural blockers primary when the host is truly below minimum' {
        $hostProfile = Get-HostFixture -Name 'host-midrange'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto' -Mode 'balanced'
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)
        $rocky = @($result | Where-Object { $_.id -eq 'rocky-linux' })[0]

        $rocky.compatibility_label | Should -Be 'possible'
        $rocky.fit_reason | Should -Be 'Enterprise-style Linux guest that can work here, though it is not the strongest default desktop fit.'

        $hostProfile.memory.total_gb = 3.5
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors
        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)
        $rocky = @($result | Where-Object { $_.id -eq 'rocky-linux' })[0]

        $rocky.compatibility_label | Should -Be 'not_recommended'
        $rocky.fit_reason | Should -Be 'This guest expects at least 4 GB of host RAM.'
    }

    It 'uses concrete storage blockers ahead of scope-note wording when the host is globally storage blocked' {
        $hostProfile = Get-HostFixture -Name 'host-low-end'
        $hostProfile.storage.system_drive_free_gb = 24.2
        @($hostProfile.storage.drives | Where-Object { $_.drive_letter -eq 'C:' })[0].free_gb = 24.2
        @($hostProfile.storage.drives | Where-Object { $_.drive_letter -eq 'C:' })[0].vm_storage_suitable = $false
        $hostProfile.storage.preferred_vm_storage = $null
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto' -Mode 'balanced'
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)
        $rocky = @($result | Where-Object { $_.id -eq 'rocky-linux' })[0]
        $freebsd = @($result | Where-Object { $_.id -eq 'freebsd' })[0]
        $kali = @($result | Where-Object { $_.id -eq 'kali-linux' })[0]

        $readiness.state | Should -Be 'not_ready'
        $readiness.primary_reason | Should -Be 'No local fixed drive has enough free space for a practical VM disk.'
        $rocky.fit_reason | Should -Be 'No suitable local fixed drive has enough free space for Rocky Linux.'
        $freebsd.fit_reason | Should -Be 'No suitable local fixed drive has enough free space for FreeBSD.'
        $kali.fit_reason | Should -Be 'No suitable local fixed drive has enough free space for Kali Linux.'
    }
}
