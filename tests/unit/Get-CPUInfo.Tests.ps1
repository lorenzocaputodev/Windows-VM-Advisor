Describe 'Get-CPUInfo' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\collectors\Get-CPUInfo.ps1')

        function Get-SafeCimInstance { param($ClassName, $Namespace, $Filter, [switch]$First) }
    }

    It 'sums cores and threads across all sockets' {
        Mock Get-SafeCimInstance {
            @(
                [pscustomobject]@{ Name = 'Xeon '; Manufacturer = 'GenuineIntel'; NumberOfCores = 8; NumberOfLogicalProcessors = 16; MaxClockSpeed = 3000; VMMonitorModeExtensions = $true; VirtualizationFirmwareEnabled = $true; SecondLevelAddressTranslationExtensions = $true },
                [pscustomobject]@{ Name = 'Xeon '; Manufacturer = 'GenuineIntel'; NumberOfCores = 8; NumberOfLogicalProcessors = 16; MaxClockSpeed = 3000; VMMonitorModeExtensions = $true; VirtualizationFirmwareEnabled = $true; SecondLevelAddressTranslationExtensions = $true }
            )
        }

        $result = Get-CPUInfo

        $result.cores | Should -Be 16
        $result.threads | Should -Be 32
        $result.model | Should -Be 'Xeon'
        $result.virtualization_supported | Should -BeTrue
    }

    It 'returns safe defaults when no processor data is available' {
        Mock Get-SafeCimInstance { @() }

        $result = Get-CPUInfo

        $result.cores | Should -Be 0
        $result.threads | Should -Be 0
        $result.model | Should -Be 'Unknown'
        $result.virtualization_supported | Should -BeFalse
    }
}
