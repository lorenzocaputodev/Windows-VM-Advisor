Describe 'Get-FirmwareInfo' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\util\Test-CommandAvailable.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeRegistryValue.ps1')
        . (Join-Path $projectRoot 'src\core\util\Invoke-SafeNativeCommand.ps1')
        . (Join-Path $projectRoot 'src\core\util\Resolve-BootMode.ps1')
        . (Join-Path $projectRoot 'src\core\collectors\Get-FirmwareInfo.ps1')
    }

    It 'falls back to bcdedit when registry and Get-ComputerInfo are unavailable' {
        Mock Get-SafeRegistryValue { $null }
        Mock Test-CommandAvailable {
            param($Name)
            return $Name -in @('bcdedit')
        }
        Mock Invoke-SafeNativeCommand { 'path                    \EFI\Microsoft\Boot\bootmgfw.efi' }

        $result = Get-FirmwareInfo

        $result.boot_mode | Should -Be 'UEFI'
        $result.secure_boot | Should -BeFalse
    }

    It 'keeps Secure Boot false when boot mode is UEFI but confirmation is unavailable' {
        Mock Get-SafeRegistryValue { 2 }
        Mock Test-CommandAvailable {
            param($Name)
            return $false
        }
        Mock Invoke-SafeNativeCommand { $null }

        $result = Get-FirmwareInfo

        $result.boot_mode | Should -Be 'UEFI'
        $result.secure_boot | Should -BeFalse
    }

    It 'returns Unknown when all firmware detection paths are unavailable' {
        Mock Get-SafeRegistryValue { $null }
        Mock Test-CommandAvailable { $false }
        Mock Invoke-SafeNativeCommand { $null }

        $result = Get-FirmwareInfo

        $result.boot_mode | Should -Be 'Unknown'
        $result.secure_boot | Should -BeFalse
    }
}
