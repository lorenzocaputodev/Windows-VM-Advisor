Describe 'Get-DiskInfo storage type detection' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\util\Convert-ToRoundedGigabytes.ps1')
        . (Join-Path $projectRoot 'src\core\util\Test-CommandAvailable.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeCimInstance.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeCimAssociatedInstance.ps1')
        . (Join-Path $projectRoot 'src\core\collectors\Get-DiskInfo.ps1')

        function Get-Partition { param($DriveLetter, $ErrorAction) }
        function Get-Disk { param($Number, $ErrorAction) }
        function Get-PhysicalDisk { param($ErrorAction) }
    }

    BeforeEach {
        Mock Get-SafeCimInstance {
            switch ($ClassName) {
                'Win32_OperatingSystem' { return [pscustomobject]@{ SystemDrive = 'C:' } }
                'Win32_LogicalDisk' {
                    return @([pscustomobject]@{ DeviceID = 'C:'; FileSystem = 'NTFS'; Size = 256GB; FreeSpace = 128GB })
                }
                default { return @() }
            }
        }
    }

    It 'does not classify a drive as HDD from generic SATA or fixed-disk labels alone' {
        Mock Test-CommandAvailable { $false }
        Mock Get-SafeCimAssociatedInstance {
            if ($ResultClassName -eq 'Win32_DiskPartition') {
                return [pscustomobject]@{ Name = 'Disk #0, Partition #1' }
            }

            return [pscustomobject]@{
                Model         = 'Samsung 870 EVO 500GB'
                MediaType     = 'Fixed hard disk media'
                InterfaceType = 'SCSI'
                Caption       = 'Samsung 870 EVO 500GB'
                PNPDeviceID   = 'SCSI\DISK&VEN_SAMSUNG'
            }
        }

        (Get-DiskInfo).drives[0].storage_type_hint | Should -Be 'Unknown'
    }

    It 'classifies an explicit rotational hint as HDD' {
        Mock Test-CommandAvailable { $false }
        Mock Get-SafeCimAssociatedInstance {
            if ($ResultClassName -eq 'Win32_DiskPartition') {
                return [pscustomobject]@{ Name = 'Disk #0, Partition #1' }
            }

            return [pscustomobject]@{ Model = 'WDC WD10EZEX HDD'; MediaType = $null; InterfaceType = 'IDE'; Caption = 'WDC'; PNPDeviceID = 'IDE\DISK' }
        }

        (Get-DiskInfo).drives[0].storage_type_hint | Should -Be 'HDD'
    }

    It 'uses Get-PhysicalDisk media type when Get-Disk reports it as unspecified' {
        Mock Test-CommandAvailable { $true }
        Mock Get-Partition { [pscustomobject]@{ DiskNumber = 0 } }
        Mock Get-Disk { [pscustomobject]@{ Number = 0; BusType = 'SATA'; MediaType = 'Unspecified'; FriendlyName = 'Generic'; Model = 'Generic' } }
        Mock Get-PhysicalDisk { [pscustomobject]@{ DeviceId = '0'; MediaType = 'SSD'; BusType = 'SATA' } }

        (Get-DiskInfo).drives[0].storage_type_hint | Should -Be 'SSD'
    }
}
