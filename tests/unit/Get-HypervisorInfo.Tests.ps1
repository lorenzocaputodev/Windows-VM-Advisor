Describe 'Get-HypervisorInfo' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\util\Get-SafeRegistryItemProperties.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeRegistryValue.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeWindowsOptionalFeatureState.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeCimInstance.ps1')
        . (Join-Path $projectRoot 'src\core\collectors\Get-HypervisorInfo.ps1')
    }

    It 'tolerates incomplete uninstall registry entries and falls back to known install paths' {
        Mock Get-SafeRegistryItemProperties { @() }
        Mock Test-Path {
            param($Path)
            return ($Path -like '*VirtualBox.exe')
        }
        Mock Get-SafeWindowsOptionalFeatureState { 'Enabled' }
        Mock Get-SafeCimInstance { $null }
        Mock Get-SafeRegistryValue { $null }

        $result = Get-HypervisorInfo

        $result.virtualbox_installed | Should -BeTrue
        $result.vmware_workstation_installed | Should -BeFalse
        $result.hyperv_enabled | Should -BeTrue
    }

    It 'ignores uninstall entries without DisplayName and uses registry fallback for Memory Integrity' {
        Mock Get-SafeRegistryItemProperties {
            @(
                [pscustomobject]@{ Publisher = 'Unknown' },
                [pscustomobject]@{ DisplayName = $null }
            )
        }
        Mock Test-Path { $false }
        Mock Get-SafeWindowsOptionalFeatureState { 'Disabled' }
        Mock Get-SafeCimInstance { $null }
        Mock Get-SafeRegistryValue { 1 } -ParameterFilter { $Name -eq 'Enabled' }

        $result = Get-HypervisorInfo

        $result.memory_integrity_enabled | Should -BeTrue
        $result.device_guard_available | Should -BeTrue
    }

    It 'uses VMware path fallback and ignores mixed valid and invalid uninstall rows' {
        Mock Get-SafeRegistryItemProperties {
            @(
                [pscustomobject]@{ DisplayName = 'Noise App' },
                [pscustomobject]@{ DisplayName = $null },
                [pscustomobject]@{ Publisher = 'Unknown' }
            )
        }
        Mock Test-Path {
            param($Path)
            return ($Path -like '*vmware.exe')
        }
        Mock Get-SafeWindowsOptionalFeatureState { 'Disabled' }
        Mock Get-SafeCimInstance { $null }
        Mock Get-SafeRegistryValue { $null }

        $result = Get-HypervisorInfo

        $result.vmware_workstation_installed | Should -BeTrue
        $result.virtualbox_installed | Should -BeFalse
    }

    It 'uses Device Guard configured services when running services are missing' {
        Mock Get-SafeRegistryItemProperties { @() }
        Mock Test-Path { $false }
        Mock Get-SafeWindowsOptionalFeatureState { 'Disabled' }
        Mock Get-SafeCimInstance {
            [pscustomobject]@{
                SecurityServicesRunning = @()
                SecurityServicesConfigured = @(2)
            }
        }
        Mock Get-SafeRegistryValue { $null }

        $result = Get-HypervisorInfo

        $result.device_guard_available | Should -BeTrue
        $result.memory_integrity_enabled | Should -BeTrue
    }

    It 'keeps Memory Integrity disabled when the registry fallback is missing or zero' {
        Mock Get-SafeRegistryItemProperties { @() }
        Mock Test-Path { $false }
        Mock Get-SafeWindowsOptionalFeatureState { 'Disabled' }
        Mock Get-SafeCimInstance { $null }
        Mock Get-SafeRegistryValue { 0 } -ParameterFilter { $Name -eq 'Enabled' }

        $result = Get-HypervisorInfo

        $result.memory_integrity_enabled | Should -BeFalse
    }
}
