Describe 'Get-BestFitGuidance' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        foreach ($relativePath in @(Get-AdvisorRulePaths)) {
            . (Join-Path $script:ProjectRoot $relativePath)
        }
        . (Join-Path $script:ProjectRoot 'src\core\output\Get-BestFitGuidance.ps1')
    }

    It 'keeps best overall, best lightweight, and best Windows aligned to the final canonical ranking on a capable host' {
        $hostProfile = Get-HostFixture -Name 'host-midrange'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal
        $report = [pscustomobject]@{
            recommendations = @($result.recommendations)
            vm_readiness    = $result.vm_readiness
        }
        $guidance = Get-BestFitGuidance -Report $report

        $guidance.best_overall.id | Should -Be 'linux-mint'
        $guidance.best_lightweight.id | Should -Be 'debian-stable'
        $guidance.best_windows.id | Should -Be 'windows-10'
    }

    It 'uses the deterministic lightweight fallback only when no lightweight-desktop entry remains usable' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'windows'

        $result = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal
        $recommendations = @($result.recommendations | ForEach-Object {
            if ($_.id -in @('debian-stable', 'lubuntu')) {
                $_.compatibility_label = 'not_recommended'
            }
            $_
        })
        $report = [pscustomobject]@{
            recommendations = $recommendations
            vm_readiness    = $result.vm_readiness
        }
        $guidance = Get-BestFitGuidance -Report $report

        $guidance.best_lightweight.id | Should -Be 'linux-mint'
        $guidance.best_lightweight.vm_profile.memory_mb | Should -BeLessOrEqual 4096
    }
}
