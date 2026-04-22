function Get-DiskInfo {
    $os = Get-SafeCimInstance -ClassName 'Win32_OperatingSystem' -First
    $systemDrive = if ($os -and $os.SystemDrive) { [string]$os.SystemDrive } else { 'C:' }
    $logicalDisks = @(
        Get-SafeCimInstance -ClassName 'Win32_LogicalDisk' -Filter 'DriveType = 3' |
        Where-Object { $_.DeviceID -match '^[A-Z]:$' }
    )

    function Get-NormalizedStorageTypeHint {
        param(
            [string[]]$Hints
        )

        $combined = ((@($Hints) | Where-Object { $_ }) -join ' ').ToUpperInvariant()
        if ($combined -match 'NVME') {
            return 'NVMe'
        }
        if ($combined -match 'SSD|SCM|SOLID') {
            return 'SSD'
        }
        if ($combined -match 'HDD|HARD DISK|FIXED HARD DISK|ROTATION|SATA') {
            return 'HDD'
        }

        return 'Unknown'
    }

    function Get-StorageTypeHintForLogicalDisk {
        param(
            [Parameter(Mandatory = $true)]
            $LogicalDisk
        )

        $driveLetter = ([string]$LogicalDisk.DeviceID).TrimEnd(':')
        if (
            $driveLetter -and
            (Test-CommandAvailable -Name 'Get-Partition') -and
            (Test-CommandAvailable -Name 'Get-Disk')
        ) {
            try {
                $partition = Get-Partition -DriveLetter $driveLetter -ErrorAction Stop
                if ($partition) {
                    $disk = Get-Disk -Number $partition.DiskNumber -ErrorAction Stop
                    if ($disk) {
                        return Get-NormalizedStorageTypeHint -Hints @(
                            [string]$disk.BusType,
                            [string]$disk.MediaType,
                            [string]$disk.FriendlyName,
                            [string]$disk.Model
                        )
                    }
                }
            }
            catch {
            }
        }

        $partition = Get-SafeCimAssociatedInstance -InputObject $LogicalDisk -ResultClassName 'Win32_DiskPartition' -First
        $diskDrive = if ($partition) {
            Get-SafeCimAssociatedInstance -InputObject $partition -ResultClassName 'Win32_DiskDrive' -First
        }
        else {
            $null
        }

        if ($diskDrive) {
            return Get-NormalizedStorageTypeHint -Hints @(
                [string]$diskDrive.Model,
                [string]$diskDrive.MediaType,
                [string]$diskDrive.InterfaceType,
                [string]$diskDrive.Caption,
                [string]$diskDrive.PNPDeviceID
            )
        }

        return 'Unknown'
    }

    function Get-NormalizedDriveSize {
        param($Value)

        if ($null -eq $Value -or -not ($Value -as [double])) {
            return 0
        }

        return (Convert-ToRoundedGigabytes -Bytes ([double]$Value))
    }

    $drives = New-Object System.Collections.ArrayList
    foreach ($logicalDisk in $logicalDisks) {
        $driveLetter = if ($logicalDisk -and $logicalDisk.DeviceID) { [string]$logicalDisk.DeviceID } else { $null }
        if (-not $driveLetter) {
            continue
        }

        [void]$drives.Add([pscustomobject]@{
            drive_letter      = $driveLetter
            is_system_drive   = ($driveLetter -eq $systemDrive)
            filesystem        = if ($logicalDisk.FileSystem) { [string]$logicalDisk.FileSystem } else { 'Unknown' }
            total_gb          = Get-NormalizedDriveSize -Value $logicalDisk.Size
            free_gb           = Get-NormalizedDriveSize -Value $logicalDisk.FreeSpace
            storage_type_hint = Get-StorageTypeHintForLogicalDisk -LogicalDisk $logicalDisk
        })
    }

    $systemDriveMatches = @(
        $drives |
        Where-Object { $_.is_system_drive } |
        Select-Object -First 1
    )
    $systemDriveInfo = if ($systemDriveMatches.Count -gt 0) { $systemDriveMatches[0] } else { $null }
    if (-not $systemDriveInfo) {
        $fallbackDriveMatches = @(
            $drives |
            Select-Object -First 1
        )
        $systemDriveInfo = if ($fallbackDriveMatches.Count -gt 0) { $fallbackDriveMatches[0] } else { $null }
    }

    if (-not $systemDriveInfo) {
        $systemDriveInfo = [pscustomobject]@{
            drive_letter      = $systemDrive
            filesystem        = 'Unknown'
            total_gb          = 0
            free_gb           = 0
            storage_type_hint = 'Unknown'
        }
    }

    [pscustomobject]@{
        system_drive          = if ($systemDriveInfo.drive_letter) { [string]$systemDriveInfo.drive_letter } else { $systemDrive }
        system_drive_fs       = [string]$systemDriveInfo.filesystem
        system_drive_total_gb = [double]$systemDriveInfo.total_gb
        system_drive_free_gb  = [double]$systemDriveInfo.free_gb
        physical_media_hint   = [string]$systemDriveInfo.storage_type_hint
        drives                = @($drives)
    }
}
