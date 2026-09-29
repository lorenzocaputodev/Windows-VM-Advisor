Describe 'Get-HypervisorInfo install path detection' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\util\Get-SafeRegistryItemProperties.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeRegistryValue.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeWindowsOptionalFeatureState.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeCimInstance.ps1')
        . (Join-Path $projectRoot 'src\core\collectors\Get-HypervisorInfo.ps1')
        $script:originalProgramFiles = $env:ProgramFiles
    }

    AfterAll {
        $env:ProgramFiles = $script:originalProgramFiles
    }

    It 'finds VirtualBox under a relocated Program Files folder when the uninstall registry has no entry' {
        $env:ProgramFiles = 'D:\Apps'
        Mock Get-SafeRegistryItemProperties { @() }
        Mock Get-SafeWindowsOptionalFeatureState { 'Disabled' }
        Mock Get-SafeCimInstance { $null }
        Mock Get-SafeRegistryValue { $null }
        Mock Test-Path { $Path -eq 'D:\Apps\Oracle\VirtualBox\VirtualBox.exe' }

        $result = Get-HypervisorInfo

        $result.virtualbox_installed | Should -BeTrue
        $result.vmware_workstation_installed | Should -BeFalse
    }
}
