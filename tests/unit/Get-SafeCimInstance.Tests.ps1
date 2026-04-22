Describe 'Get-SafeCimInstance' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\util\Test-CommandAvailable.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeCimInstance.ps1')
    }

    It 'returns CIM results when Get-CimInstance succeeds' {
        Mock Test-CommandAvailable {
            param($Name)
            return ($Name -eq 'Get-CimInstance')
        }
        Mock Get-CimInstance { @([pscustomobject]@{ Name = 'CPU0' }) }

        @((Get-SafeCimInstance -ClassName 'Win32_Processor')).Count | Should -Be 1
    }

    It 'falls back to WMI when CIM fails and WMI is available' {
        Mock Test-CommandAvailable {
            param($Name)
            return ($Name -in @('Get-CimInstance', 'Get-WmiObject'))
        }
        Mock Get-CimInstance { throw 'CIM failed' }
        Mock Get-WmiObject { @([pscustomobject]@{ Name = 'CPU0' }) }

        (Get-SafeCimInstance -ClassName 'Win32_Processor' -First).Name | Should -Be 'CPU0'
    }

    It 'returns null or an empty array when both CIM and WMI are unavailable' {
        Mock Test-CommandAvailable { $false }

        (Get-SafeCimInstance -ClassName 'Win32_Processor' -First) | Should -Be $null
        @((Get-SafeCimInstance -ClassName 'Win32_Processor')).Count | Should -Be 0
    }
}
