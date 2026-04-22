Describe 'Get-Recommendation' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        foreach ($relativePath in @(Get-AdvisorRulePaths)) {
            . (Join-Path $script:ProjectRoot $relativePath)
        }
    }

    It 'ranks Windows 11-family options highest on a strong modern host' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal

        $result.vm_readiness.state | Should -Be 'ok'
        $result.recommendations[0].display_name | Should -Be 'Windows 11'
        $result.recommendations[0].compatibility_label | Should -Be 'recommended'
        $result.vm_readiness.takeaway | Should -Match 'Windows 11'
        $result.vm_readiness.headline | Should -Match 'Windows guests remain'
        $result.recommendations[0].vm_profile.vcpu | Should -BeGreaterThan 0
    }

    It 'keeps Windows 11-family entries below practical mid-range choices when firmware security support is incomplete' {
        $hostProfile = Get-HostFixture -Name 'host-midrange'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal

        $topThree = @($result.recommendations | Select-Object -First 3 -ExpandProperty display_name)
        $windows11 = @($result.recommendations | Where-Object { $_.id -eq 'windows-11' })[0]

        $result.vm_readiness.state | Should -Be 'ok'
        $topThree[0] | Should -Be 'Linux Mint'
        $topThree[1] | Should -Be 'Ubuntu LTS'
        $topThree[2] | Should -Be 'Windows 10'
        $windows11.compatibility_label | Should -Be 'not_recommended'
        @($result.recommendations | Where-Object { $_.compatibility_label -eq 'recommended' }).Count | Should -Be 3
        (@($result.recommendations | Select-Object -ExpandProperty display_name) -contains 'Windows 10 Enterprise LTSC 2021') | Should -BeFalse
        (@($result.recommendations | Select-Object -ExpandProperty display_name) -contains 'Windows 11 Enterprise LTSC 2024') | Should -BeFalse
    }

    It 'marks stronger lightweight Linux options as recommended on a constrained but usable host' {
        $hostProfile = Get-HostFixture -Name 'host-low-end'
        $hostProfile.memory.total_gb = 7.6
        $hostProfile.memory.free_gb = 2.6
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal
        $topEntry = $result.recommendations[0]
        $kaliIndex = @($result.recommendations | Select-Object -ExpandProperty display_name).IndexOf('Kali Linux')

        $result.vm_readiness.state | Should -Be 'limited'
        $result.vm_readiness.primary_reason | Should -Be 'Host RAM is better suited to lighter guest options.'
        $result.vm_readiness.takeaway | Should -Match 'lighter Linux guests'
        $topEntry.family | Should -Be 'linux'
        $topEntry.compatibility_label | Should -Be 'recommended'
        ((@($result.recommendations | Where-Object { $_.compatibility_label -eq 'recommended' }).Count) -le 2) | Should -BeTrue
        $kaliIndex | Should -BeGreaterThan 4
    }

    It 'keeps blocked hosts explicit when no practical guest remains workable' {
        $hostProfile = Get-HostFixture -Name 'host-low-end'
        $hostProfile.cpu.virtualization_supported = $false
        $hostProfile.cpu.virtualization_enabled_in_firmware = $false
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal

        $result.vm_readiness.state | Should -Be 'not_ready'
        $result.vm_readiness.takeaway | Should -Match 'No practical VM guest'
        @($result.recommendations | Where-Object { $_.compatibility_label -eq 'recommended' }).Count | Should -Be 0
    }

    It 'keeps the root virtualization blocker without adding duplicate derived blocker text' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.cpu.virtualization_supported = $false
        $hostProfile.cpu.virtualization_enabled_in_firmware = $true
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal

        $result.vm_readiness.state | Should -Be 'not_ready'
        $result.vm_readiness.primary_reason | Should -Be 'CPU virtualization support was not detected.'
        ($result.vm_readiness.blockers -contains 'CPU virtualization support was not detected.') | Should -BeTrue
        ($result.vm_readiness.blockers -contains 'No practical guest option stands out under the current host conditions.') | Should -BeFalse
        ($result.vm_readiness.blockers -contains 'No practical VM guest is a good fit until the current blockers are resolved.') | Should -BeFalse
    }

    It 'uses richer fit reasons instead of repeating generic storage-cap text' {
        $hostProfile = Get-HostFixture -Name 'host-midrange'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal
        $linuxMint = @($result.recommendations | Where-Object { $_.id -eq 'linux-mint' })[0]
        $ubuntu = @($result.recommendations | Where-Object { $_.id -eq 'ubuntu-lts' })[0]
        $windows10 = @($result.recommendations | Where-Object { $_.id -eq 'windows-10' })[0]

        $linuxMint.fit_reason | Should -Match 'Balanced desktop Linux choice'
        $ubuntu.fit_reason | Should -Match 'Mainstream and broadly supported Linux guest'
        $windows10.fit_reason | Should -Match 'Most forgiving Windows desktop option'
    }

    It 'uses the cleaned 12-guest catalog and gives the new entries explicit first-class reasons' {
        $hostProfile = Get-HostFixture -Name 'host-midrange'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal
        $names = @($result.recommendations | Select-Object -ExpandProperty display_name)
        $arch = @($result.recommendations | Where-Object { $_.id -eq 'arch-linux' })[0]
        $rocky = @($result.recommendations | Where-Object { $_.id -eq 'rocky-linux' })[0]
        $freebsd = @($result.recommendations | Where-Object { $_.id -eq 'freebsd' })[0]
        $nixos = @($result.recommendations | Where-Object { $_.id -eq 'nixos' })[0]

        ($names -contains 'MX Linux') | Should -BeFalse
        ($names -contains 'Pop!_OS') | Should -BeFalse
        ($names -contains 'Zorin OS') | Should -BeFalse
        ($names -contains 'openSUSE Leap') | Should -BeFalse
        ($names -contains 'Xubuntu') | Should -BeFalse
        ($names -contains 'Arch Linux') | Should -BeTrue
        ($names -contains 'Rocky Linux') | Should -BeTrue
        ($names -contains 'FreeBSD') | Should -BeTrue
        ($names -contains 'NixOS') | Should -BeTrue
        $arch.fit_reason | Should -Match 'advanced DIY Linux option|manual setup'
        $rocky.fit_reason | Should -Match 'enterprise-style Linux guest|server-like'
        $freebsd.fit_reason | Should -Match 'Unix-like guest|lab-oriented'
        $nixos.fit_reason | Should -Match 'declarative Linux option|reproducible environments'
    }

    It 'uses a secondary drive as the VM storage location when the system drive is pressured' {
        $hostProfile = Get-HostFixture -Name 'host-secondary-storage'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal
        $topUsable = @(
            $result.recommendations |
            Where-Object { $_.compatibility_label -ne 'not_recommended' } |
            Select-Object -First 1
        )[0]

        $result.vm_readiness.state | Should -Be 'limited'
        $topUsable.vm_profile.storage_location | Should -Be 'D:'
        ($topUsable.notes -contains 'Use D: as the preferred VM storage location for this guest.') | Should -BeTrue
    }

    It 'keeps the technical storage limitation as primary_reason on storage-only limited hosts' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.storage.system_drive_free_gb = 55
        @($hostProfile.storage.drives | Where-Object { $_.drive_letter -eq 'C:' })[0].free_gb = 55
        $hostProfile.storage.preferred_vm_storage = [pscustomobject]@{
            drive_letter        = 'D:'
            is_system_drive     = $false
            filesystem          = 'NTFS'
            total_gb            = 500.0
            free_gb             = 320.0
            storage_type_hint   = 'SSD'
            vm_storage_suitable = $true
        }
        $hostProfile.storage.drives = @(
            @($hostProfile.storage.drives | Where-Object { $_.drive_letter -eq 'C:' })[0],
            $hostProfile.storage.preferred_vm_storage
        )
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal

        $result.vm_readiness.state | Should -Be 'limited'
        # The old behavior incorrectly replaced the technical cause with guest advice.
        $result.vm_readiness.primary_reason | Should -Be 'System drive space is tighter than ideal, so D: is the better place for VM files.'
        $result.vm_readiness.headline | Should -Be 'This PC can run VMs, but the system drive is tighter than ideal. Keep VM files on the secondary drive.'
        $result.vm_readiness.takeaway | Should -Be 'This PC is limited for VM use mainly by storage layout. Use Linux Mint and keep VM files on D:.'
    }

    It 'keeps storage-led readiness messaging when low free RAM is only advisory and the top profile is not materially changed' {
        $hostProfile = Get-HostFixture -Name 'host-secondary-storage'
        $hostProfile.memory.total_gb = 8.0
        $hostProfile.memory.free_gb = 3.3
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'linux' -Mode 'light'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal
        $topEntry = $result.recommendations[0]

        $result.vm_readiness.state | Should -Be 'limited'
        $result.vm_readiness.primary_reason | Should -Be 'System drive free space is low, but D: is the better local drive for VM storage.'
        $result.vm_readiness.headline | Should -Be 'This PC can run VMs, but the system drive is tighter than ideal. Keep VM files on the secondary drive.'
        $result.vm_readiness.takeaway | Should -Be 'This PC is limited for VM use mainly by storage layout. Use Linux Mint and keep VM files on D:.'
        $topEntry.vm_profile.memory_mb | Should -Be 2048
        (@($topEntry.notes | Where-Object { $_ -match 'current free RAM is tighter than ideal|Close other applications before starting the VM' }).Count) | Should -Be 0
    }

    It 'keeps free-RAM pressure coherent across readiness messaging and final ranking on a strong host' {
        $hostProfile = Get-HostFixture -Name 'host-secondary-storage'
        $hostProfile.memory.total_gb = 16.0
        $hostProfile.memory.free_gb = 3.7
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal
        $topEntry = $result.recommendations[0]
        $windows10 = @($result.recommendations | Where-Object { $_.id -eq 'windows-10' })[0]
        $ids = @($result.recommendations | Select-Object -ExpandProperty id)

        $result.vm_readiness.state | Should -Be 'limited'
        $result.vm_readiness.primary_reason | Should -Be 'Host free RAM is low. Close other applications before starting a VM.'
        $result.vm_readiness.headline | Should -Match 'current free RAM is tighter than ideal'
        $result.vm_readiness.takeaway | Should -Match 'close other applications first'
        $topEntry.id | Should -Be 'linux-mint'
        $topEntry.vm_profile.memory_mb | Should -Be 3072
        ($topEntry.notes -contains 'RAM is starting at 3072 MB because current free RAM is tighter than ideal. Close other applications before starting the VM.') | Should -BeTrue
        $windows10.vm_profile.memory_mb | Should -Be 4096
        $ids.IndexOf('windows-10') | Should -BeLessThan $ids.IndexOf('windows-11')
        $ids.IndexOf('windows-10') | Should -BeGreaterThan $ids.IndexOf('linux-mint')
    }

    It 'uses the structured free-RAM pressure path in the ok state when the top practical guest is materially reshaped' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.memory.free_gb = 3.7
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal
        $topEntry = $result.recommendations[0]

        $result.vm_readiness.state | Should -Be 'ok'
        $result.vm_readiness.primary_reason | Should -Be 'Host free RAM is low. Close other applications before starting a VM.'
        $result.vm_readiness.headline | Should -Be 'This PC is ready for practical VM use, but current free RAM is tighter than ideal for the suggested starts.'
        $result.vm_readiness.takeaway | Should -Be 'This PC is ready for practical VM use. Linux Mint is the clearest overall fit.'
        $topEntry.id | Should -Be 'linux-mint'
        $topEntry.vm_profile.memory_mb | Should -Be 3072
        ($topEntry.notes -contains 'RAM is starting at 3072 MB because current free RAM is tighter than ideal. Close other applications before starting the VM.') | Should -BeTrue
    }

    It 'keeps Windows 10 ahead of Windows 11 in limited user-facing ordering when Windows 10 is the better Windows fit' {
        $hostProfile = Get-HostFixture -Name 'host-secondary-storage'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal
        $ids = @($result.recommendations | Select-Object -ExpandProperty id)

        $result.vm_readiness.state | Should -Be 'limited'
        $ids.IndexOf('windows-10') | Should -BeLessThan $ids.IndexOf('windows-11')
    }

    It 'honors a linux preference by keeping Linux family entries at the top of the ranked list' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'linux'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal

        $result.recommendations[0].family | Should -Be 'linux'
        $result.recommendations[1].family | Should -Be 'linux'
    }

    It 'falls back to VMware Workstation when VirtualBox is requested but blocked' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hypervisors = New-HypervisorProfile -HyperVEnabled $true -MemoryIntegrityEnabled $true
        $goal = New-UserGoal -GuestPreference 'windows' -HypervisorPreference 'virtualbox'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal

        $windows10 = @($result.recommendations | Where-Object { $_.id -eq 'windows-10' })[0]

        $windows10.preferred_hypervisor | Should -Be 'VMware Workstation'
        ($windows10.notes -contains 'Oracle VirtualBox was requested, but VMware Workstation is the safer choice on this host.') | Should -BeTrue
    }

    It 'keeps public recommendation entries free of raw score fields while returning usable VM profiles' {
        $hostProfile = Get-HostFixture -Name 'host-midrange'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal

        $topEntry = $result.recommendations[0]

        ($topEntry.PSObject.Properties.Name -contains 'score') | Should -BeFalse
        ($topEntry.PSObject.Properties.Name -contains '_material_free_memory_pressure') | Should -BeFalse
        $topEntry.vm_profile.vcpu | Should -BeGreaterThan 0
        $topEntry.vm_profile.memory_mb | Should -BeGreaterThan 0
        $topEntry.vm_profile.disk_gb | Should -BeGreaterThan 0
        $topEntry.vm_profile.storage_location | Should -Not -BeNullOrEmpty
    }
}
