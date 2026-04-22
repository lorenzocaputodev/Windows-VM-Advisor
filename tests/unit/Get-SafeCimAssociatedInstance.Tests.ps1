Describe 'Get-SafeCimAssociatedInstance' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\util\Test-CommandAvailable.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeCimAssociatedInstance.ps1')
    }

    It 'returns CIM association results when available' {
        Mock Test-CommandAvailable {
            param($Name)
            return ($Name -eq 'Get-CimAssociatedInstance')
        }

        function Get-CimAssociatedInstance {
            param($InputObject, $ResultClassName, $ErrorAction)
            [pscustomobject]@{ Name = 'Assoc0' }
        }

        try {
            $result = Get-SafeCimAssociatedInstance -InputObject ([pscustomobject]@{}) -ResultClassName 'Win32_DiskDrive' -First

            ($null -ne $result) | Should -BeTrue
            @($result).Count | Should -Be 1
        }
        finally {
            Remove-Item Function:\Get-CimAssociatedInstance -ErrorAction SilentlyContinue
        }
    }

    It 'falls back to WMI associators when CIM association fails and __RELPATH exists' {
        Mock Test-CommandAvailable {
            param($Name)
            return ($Name -in @('Get-CimAssociatedInstance', 'Get-WmiObject'))
        }
        Mock Get-CimAssociatedInstance { throw 'CIM association failed' }
        Mock Get-WmiObject { @([pscustomobject]@{ Name = 'Assoc1' }) }

        $inputObject = [pscustomobject]@{ __RELPATH = 'Win32_LogicalDisk.DeviceID="C:"' }
        (Get-SafeCimAssociatedInstance -InputObject $inputObject -ResultClassName 'Win32_DiskPartition' -First).Name | Should -Be 'Assoc1'
    }

    It 'returns null or an empty array when WMI fallback cannot run because __RELPATH is missing' {
        Mock Test-CommandAvailable {
            param($Name)
            return ($Name -in @('Get-CimAssociatedInstance', 'Get-WmiObject'))
        }
        Mock Get-CimAssociatedInstance { throw 'CIM association failed' }

        $inputObject = [pscustomobject]@{ DeviceID = 'C:' }
        (Get-SafeCimAssociatedInstance -InputObject $inputObject -ResultClassName 'Win32_DiskPartition' -First) | Should -Be $null
        @((Get-SafeCimAssociatedInstance -InputObject $inputObject -ResultClassName 'Win32_DiskPartition')).Count | Should -Be 0
    }
}
