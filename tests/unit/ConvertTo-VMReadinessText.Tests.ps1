Describe 'ConvertTo-VMReadinessText' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        foreach ($relativePath in @(Get-AdvisorRulePaths)) {
            . (Join-Path $script:ProjectRoot $relativePath)
        }
        . (Join-Path $script:ProjectRoot 'src\core\output\ConvertTo-VMReadinessText.ps1')
    }

    It 'keeps the primary limitation visible in Current limitations when it also explains the result' {
        $hostProfile = Get-HostFixture -Name 'host-secondary-storage'
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'
        $recommendation = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal
        $report = [pscustomobject]@{
            system_information = $hostProfile
            vm_readiness       = $recommendation.vm_readiness
            recommendations    = @($recommendation.recommendations)
        }

        $text = ConvertTo-VMReadinessText -Report $report

        $text | Should -Match 'Why this result: System drive free space is low, but D: is the better local drive for VM storage\.'
        $text | Should -Match '(?s)Current limitations:\r?\n- System drive free space is low, but D: is the better local drive for VM storage\.'
        $text | Should -Not -Match '(?s)Why this result: System drive free space is low, but D: is the better local drive for VM storage\..*Current limitations:\r?\n- None'
    }

    It 'keeps the primary blocker visible in Current blockers when it also explains the result' {
        $hostProfile = Get-HostFixture -Name 'host-high-end'
        $hostProfile.cpu.virtualization_supported = $false
        $hypervisors = New-HypervisorProfile
        $goal = New-UserGoal -GuestPreference 'auto'
        $recommendation = Get-Recommendation -HostProfile $hostProfile -HypervisorProfile $hypervisors -UserGoal $goal
        $report = [pscustomobject]@{
            system_information = $hostProfile
            vm_readiness       = $recommendation.vm_readiness
            recommendations    = @($recommendation.recommendations)
        }

        $text = ConvertTo-VMReadinessText -Report $report

        $text | Should -Match 'Why this result: CPU virtualization support was not detected\.'
        $text | Should -Match '(?s)Current blockers:\r?\n- CPU virtualization support was not detected\.'
        $text | Should -Not -Match '(?s)Why this result: CPU virtualization support was not detected\..*Current blockers:\r?\n- None'
    }
}
