Describe 'Get-DiskInfo' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\util\Convert-ToRoundedGigabytes.ps1')
        . (Join-Path $projectRoot 'src\core\util\Test-CommandAvailable.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeCimInstance.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeCimAssociatedInstance.ps1')
        . (Join-Path $projectRoot 'src\core\collectors\Get-DiskInfo.ps1')
    }

    It 'falls back cleanly when disk associations and system-drive matching are unavailable' {
        Mock Get-SafeCimInstance {
            param($ClassName)

            switch ($ClassName) {
                'Win32_OperatingSystem' { return [pscustomobject]@{ SystemDrive = 'Z:' } }
                'Win32_LogicalDisk' {
                    return @(
                        [pscustomobject]@{
                            DeviceID  = 'C:'
                            FileSystem = $null
                            Size      = $null
                            FreeSpace = $null
                        }
                    )
                }
                default { return @() }
            }
        }
        Mock Test-CommandAvailable { $false }
        Mock Get-SafeCimAssociatedInstance { $null }

        $result = Get-DiskInfo

        $result.system_drive | Should -Be 'C:'
        $result.system_drive_fs | Should -Be 'Unknown'
        $result.system_drive_total_gb | Should -Be 0
        $result.system_drive_free_gb | Should -Be 0
        $result.physical_media_hint | Should -Be 'Unknown'
        $result.drives[0].storage_type_hint | Should -Be 'Unknown'
    }

    It 'uses disk association metadata when Get-Partition and Get-Disk are unavailable' {
        Mock Get-SafeCimInstance {
            param($ClassName)

            switch ($ClassName) {
                'Win32_OperatingSystem' { return [pscustomobject]@{ SystemDrive = 'C:' } }
                'Win32_LogicalDisk' {
                    return @(
                        [pscustomobject]@{
                            DeviceID  = 'C:'
                            FileSystem = 'NTFS'
                            Size      = 256GB
                            FreeSpace = 128GB
                        }
                    )
                }
                default { return @() }
            }
        }
        Mock Test-CommandAvailable { $false }
        Mock Get-SafeCimAssociatedInstance {
            param($InputObject, $ResultClassName)

            if ($ResultClassName -eq 'Win32_DiskPartition') {
                return [pscustomobject]@{ Name = 'Disk #0, Partition #1' }
            }

            if ($ResultClassName -eq 'Win32_DiskDrive') {
                return [pscustomobject]@{
                    Model = 'Samsung SSD 970 EVO'
                    MediaType = $null
                    InterfaceType = 'NVMe'
                    Caption = 'Samsung NVMe Disk'
                    PNPDeviceID = 'PCI\\NVME'
                }
            }

            return $null
        }

        $result = Get-DiskInfo

        $result.physical_media_hint | Should -Be 'NVMe'
        $result.drives[0].storage_type_hint | Should -Be 'NVMe'
    }

    It 'falls back to the first fixed drive when the reported system drive is unmatched' {
        Mock Get-SafeCimInstance {
            param($ClassName)

            switch ($ClassName) {
                'Win32_OperatingSystem' { return [pscustomobject]@{ SystemDrive = 'Z:' } }
                'Win32_LogicalDisk' {
                    return @(
                        [pscustomobject]@{
                            DeviceID  = 'D:'
                            FileSystem = 'NTFS'
                            Size      = 512GB
                            FreeSpace = 200GB
                        },
                        [pscustomobject]@{
                            DeviceID  = 'E:'
                            FileSystem = 'NTFS'
                            Size      = 1024GB
                            FreeSpace = 500GB
                        }
                    )
                }
                default { return @() }
            }
        }
        Mock Test-CommandAvailable { $false }
        Mock Get-SafeCimAssociatedInstance { $null }

        $result = Get-DiskInfo

        $result.system_drive | Should -Be 'D:'
        $result.system_drive_total_gb | Should -BeGreaterThan 0
    }
}
