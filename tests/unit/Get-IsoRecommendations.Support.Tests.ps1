Describe 'Get-IsoRecommendations support status and headroom' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        foreach ($relativePath in @(Get-AdvisorRulePaths)) {
            . (Join-Path $script:ProjectRoot $relativePath)
        }
    }

    It 'never labels the end-of-support Windows 10 as recommended and explains why' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'windows' -Mode 'performance'
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)
        $windows10 = @($result | Where-Object { $_.id -eq 'windows-10' })[0]

        $windows10.compatibility_label | Should -Be 'possible'
        (@($windows10.notes | Where-Object { $_ -match 'reached end of support' }).Count) | Should -Be 1
    }

    It 'does not add the end-of-support note to supported guests' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)

        (@($result | Where-Object { $_.id -ne 'windows-10' } | ForEach-Object { $_.notes } | Where-Object { $_ -match 'reached end of support' }).Count) | Should -Be 0
    }

    It 'warns when a Windows guest would leave less than the host reserve of RAM' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.memory.total_gb = 7.6
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'windows'
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)
        $windows11 = @($result | Where-Object { $_.id -eq 'windows-11' })[0]

        $windows11.vm_profile.memory_mb | Should -Be 4096
        (@($windows11.notes | Where-Object { $_ -match '^Only .+ of RAM will remain' }).Count) | Should -Be 1
    }

    It 'does not warn about headroom on a roomy host' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'windows'
        $readiness = Get-VMReadiness -HostProfile $hostProfile -HypervisorProfile $hypervisors

        $result = @(Get-IsoRecommendations -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal -VMReadiness $readiness)

        (@($result | ForEach-Object { $_.notes } | Where-Object { $_ -match '^Only .+ of RAM will remain' }).Count) | Should -Be 0
    }
}
