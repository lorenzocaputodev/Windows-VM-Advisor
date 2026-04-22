Describe 'Get-VirtualizationInfo' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\util\Test-CommandAvailable.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeCimInstance.ps1')
        . (Join-Path $projectRoot 'src\core\util\Invoke-SafeNativeCommand.ps1')
        . (Join-Path $projectRoot 'src\core\collectors\Get-CPUInfo.ps1')
        . (Join-Path $projectRoot 'src\core\collectors\Get-VirtualizationInfo.ps1')
    }

    It 'keeps direct CPU virtualization signals when Win32_Processor already reports them' {
        Mock Test-CommandAvailable { $false }
        Mock Get-SafeCimInstance { $null }
        Mock Invoke-SafeNativeCommand { $null }

        $cpuInfo = [pscustomobject]@{
            virtualization_supported           = $true
            virtualization_enabled_in_firmware = $true
            slat_supported                     = $true
        }

        $result = Get-VirtualizationInfo -CPUInfo $cpuInfo

        $result.virtualization_supported | Should -BeTrue
        $result.virtualization_enabled_in_firmware | Should -BeTrue
        $result.slat_supported | Should -BeTrue
    }

    It 'uses Get-ComputerInfo Hyper-V requirement signals when Win32_Processor fields are false or empty' {
        Mock Test-CommandAvailable {
            param($Name)
            $Name -eq 'Get-ComputerInfo'
        }
        Mock Get-SafeCimInstance { $null }
        Mock Invoke-SafeNativeCommand { $null }
        Mock Get-ComputerInfo {
            [pscustomobject]@{
                HyperVRequirementVMMonitorModeExtensions       = 'True'
                HyperVRequirementVirtualizationFirmwareEnabled = $true
                HyperVRequirementSecondLevelAddressTranslation = 'Yes'
            }
        }

        $cpuInfo = [pscustomobject]@{
            virtualization_supported           = $false
            virtualization_enabled_in_firmware = $null
            slat_supported                     = $false
        }

        $result = Get-VirtualizationInfo -CPUInfo $cpuInfo

        $result.virtualization_supported | Should -BeTrue
        $result.virtualization_enabled_in_firmware | Should -BeTrue
        $result.slat_supported | Should -BeTrue
    }

    It 'merges partial fallback signals per field without overclaiming unsupported signals' {
        Mock Test-CommandAvailable {
            param($Name)
            $Name -eq 'Get-ComputerInfo'
        }
        Mock Get-SafeCimInstance { $null }
        Mock Invoke-SafeNativeCommand { $null }
        Mock Get-ComputerInfo {
            [pscustomobject]@{
                HyperVRequirementVMMonitorModeExtensions       = ''
                HyperVRequirementVirtualizationFirmwareEnabled = 'Enabled'
                HyperVRequirementSecondLevelAddressTranslation = $null
            }
        }

        $cpuInfo = [pscustomobject]@{
            virtualization_supported           = $false
            virtualization_enabled_in_firmware = $false
            slat_supported                     = $true
        }

        $result = Get-VirtualizationInfo -CPUInfo $cpuInfo

        $result.virtualization_supported | Should -BeFalse
        $result.virtualization_enabled_in_firmware | Should -BeTrue
        $result.slat_supported | Should -BeTrue
    }

    It 'keeps signals false when no trusted source can positively confirm them' {
        Mock Test-CommandAvailable {
            param($Name)
            $Name -eq 'Get-ComputerInfo'
        }
        Mock Get-SafeCimInstance { $null }
        Mock Invoke-SafeNativeCommand { $null }
        Mock Get-ComputerInfo {
            [pscustomobject]@{
                HyperVRequirementVMMonitorModeExtensions       = 'Unknown'
                HyperVRequirementVirtualizationFirmwareEnabled = ''
                HyperVRequirementSecondLevelAddressTranslation = $null
            }
        }

        $cpuInfo = [pscustomobject]@{
            virtualization_supported           = $false
            virtualization_enabled_in_firmware = $false
            slat_supported                     = $false
        }

        $result = Get-VirtualizationInfo -CPUInfo $cpuInfo

        $result.virtualization_supported | Should -BeFalse
        $result.virtualization_enabled_in_firmware | Should -BeFalse
        $result.slat_supported | Should -BeFalse
    }

    It 'uses active hypervisor evidence from Win32_ComputerSystem when CPU and Get-ComputerInfo signals are not useful' {
        Mock Test-CommandAvailable {
            param($Name)
            $Name -eq 'Get-ComputerInfo'
        }
        Mock Get-ComputerInfo {
            [pscustomobject]@{
                HyperVRequirementVMMonitorModeExtensions       = ''
                HyperVRequirementVirtualizationFirmwareEnabled = ''
                HyperVRequirementSecondLevelAddressTranslation = ''
            }
        }
        Mock Get-SafeCimInstance {
            param($ClassName, $First)

            if ($ClassName -eq 'Win32_ComputerSystem') {
                return [pscustomobject]@{
                    HypervisorPresent = $true
                }
            }

            return $null
        }
        Mock Invoke-SafeNativeCommand { $null }

        $cpuInfo = [pscustomobject]@{
            virtualization_supported           = $false
            virtualization_enabled_in_firmware = $false
            slat_supported                     = $false
        }

        $result = Get-VirtualizationInfo -CPUInfo $cpuInfo

        $result.virtualization_supported | Should -BeTrue
        $result.virtualization_enabled_in_firmware | Should -BeTrue
        $result.slat_supported | Should -BeFalse
    }

    It 'uses the live hypervisor-detected systeminfo text as positive evidence without promoting SLAT' {
        Mock Test-CommandAvailable {
            param($Name)
            $Name -eq 'Get-ComputerInfo' -or $Name -eq 'systeminfo'
        }
        Mock Get-ComputerInfo {
            [pscustomobject]@{
                HyperVRequirementVMMonitorModeExtensions       = ''
                HyperVRequirementVirtualizationFirmwareEnabled = ''
                HyperVRequirementSecondLevelAddressTranslation = ''
            }
        }
        Mock Get-SafeCimInstance { $null }
        Mock Invoke-SafeNativeCommand {
            'Hyper-V Requirements: A hypervisor has been detected. Features required for Hyper-V will not be displayed.'
        }

        $cpuInfo = [pscustomobject]@{
            virtualization_supported           = $false
            virtualization_enabled_in_firmware = $false
            slat_supported                     = $false
        }

        $result = Get-VirtualizationInfo -CPUInfo $cpuInfo

        $result.virtualization_supported | Should -BeTrue
        $result.virtualization_enabled_in_firmware | Should -BeTrue
        $result.slat_supported | Should -BeFalse
    }
}
