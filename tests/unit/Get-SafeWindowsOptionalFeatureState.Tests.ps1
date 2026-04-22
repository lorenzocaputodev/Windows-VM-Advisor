Describe 'Get-SafeWindowsOptionalFeatureState' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\util\Test-CommandAvailable.ps1')
        . (Join-Path $projectRoot 'src\core\util\Invoke-SafeNativeCommand.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeWindowsOptionalFeatureState.ps1')
    }

    It 'returns the cmdlet state when Get-WindowsOptionalFeature is available' {
        Mock Test-CommandAvailable {
            param($Name)
            return ($Name -eq 'Get-WindowsOptionalFeature')
        }
        Mock Get-WindowsOptionalFeature {
            [pscustomobject]@{ State = 'Disabled' }
        }

        Get-SafeWindowsOptionalFeatureState -FeatureName 'Microsoft-Hyper-V-All' | Should -Be 'Disabled'
    }

    It 'falls back to DISM when Get-WindowsOptionalFeature is unavailable' {
        Mock Test-CommandAvailable {
            param($Name)
            return ($Name -eq 'dism.exe')
        }
        Mock Invoke-SafeNativeCommand {
            @'
Feature Name : Microsoft-Hyper-V-All
State : Enabled
'@
        }

        Get-SafeWindowsOptionalFeatureState -FeatureName 'Microsoft-Hyper-V-All' | Should -Be 'Enabled'
    }

    It 'returns Disabled from DISM when the fallback reports Disabled' {
        Mock Test-CommandAvailable {
            param($Name)
            return ($Name -eq 'dism.exe')
        }
        Mock Invoke-SafeNativeCommand {
            @'
Feature Name : Microsoft-Hyper-V-All
State : Disabled
'@
        }

        Get-SafeWindowsOptionalFeatureState -FeatureName 'Microsoft-Hyper-V-All' | Should -Be 'Disabled'
    }

    It 'returns Unknown when DISM output is malformed or unavailable' {
        Mock Test-CommandAvailable {
            param($Name)
            return ($Name -eq 'dism.exe')
        }
        Mock Invoke-SafeNativeCommand { 'No useful state here' }

        Get-SafeWindowsOptionalFeatureState -FeatureName 'Microsoft-Hyper-V-All' | Should -Be 'Unknown'
    }
}
