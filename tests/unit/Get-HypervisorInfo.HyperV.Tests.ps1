Describe 'Get-HypervisorInfo Hyper-V verification' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\util\Get-SafeRegistryItemProperties.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeRegistryValue.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeWindowsOptionalFeatureState.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeCimInstance.ps1')
        . (Join-Path $projectRoot 'src\core\collectors\Get-HypervisorInfo.ps1')
    }

    It 'reports Hyper-V state <State> as enabled=<Enabled> verified=<Verified>' -ForEach @(
        @{ State = 'Enabled'; Enabled = $true; Verified = $true }
        @{ State = 'Disabled'; Enabled = $false; Verified = $true }
        @{ State = 'Unknown'; Enabled = $false; Verified = $false }
    ) {
        Mock Get-SafeRegistryItemProperties { @() }
        Mock Test-Path { $false }
        Mock Get-SafeWindowsOptionalFeatureState { $State }
        Mock Get-SafeCimInstance { $null }
        Mock Get-SafeRegistryValue { $null }

        $result = Get-HypervisorInfo

        $result.hyperv_enabled | Should -Be $Enabled
        $result.hyperv_state_verified | Should -Be $Verified
    }
}
