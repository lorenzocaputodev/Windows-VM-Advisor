Describe 'Get-FirmwareInfo Secure Boot without elevation' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\util\Test-CommandAvailable.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeRegistryValue.ps1')
        . (Join-Path $projectRoot 'src\core\util\Invoke-SafeNativeCommand.ps1')
        . (Join-Path $projectRoot 'src\core\util\Resolve-BootMode.ps1')
        . (Join-Path $projectRoot 'src\core\collectors\Get-FirmwareInfo.ps1')

        function Confirm-SecureBootUEFI { param($ErrorAction) }
    }

    It 'reads Secure Boot state from the registry when Confirm-SecureBootUEFI cannot run' {
        Mock Get-SafeRegistryValue {
            if ($Name -eq 'PEFirmwareType') { return 2 }
            if ($Name -eq 'UEFISecureBootEnabled') { return 1 }
            return $null
        }
        Mock Test-CommandAvailable { $Name -eq 'Confirm-SecureBootUEFI' }
        Mock Confirm-SecureBootUEFI { throw 'Access denied' }
        Mock Invoke-SafeNativeCommand { $null }

        $result = Get-FirmwareInfo

        $result.boot_mode | Should -Be 'UEFI'
        $result.secure_boot | Should -BeTrue
    }

    It 'trusts Confirm-SecureBootUEFI over the registry when it succeeds' {
        Mock Get-SafeRegistryValue {
            if ($Name -eq 'PEFirmwareType') { return 2 }
            if ($Name -eq 'UEFISecureBootEnabled') { return 1 }
            return $null
        }
        Mock Test-CommandAvailable { $Name -eq 'Confirm-SecureBootUEFI' }
        Mock Confirm-SecureBootUEFI { $false }
        Mock Invoke-SafeNativeCommand { $null }

        (Get-FirmwareInfo).secure_boot | Should -BeFalse
    }
}
