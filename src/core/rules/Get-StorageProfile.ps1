function Get-StorageProfile {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Storage
    )

    $thresholds = Get-AdvisorThresholds

    $rawDrives = @($Storage.drives)
    if ($rawDrives.Count -eq 0) {
        $rawDrives = @(
            [pscustomobject]@{
                drive_letter       = [string]$Storage.system_drive
                is_system_drive    = $true
                filesystem         = [string]$Storage.system_drive_fs
                total_gb           = [double]$Storage.system_drive_total_gb
                free_gb            = [double]$Storage.system_drive_free_gb
                storage_type_hint  = [string]$Storage.physical_media_hint
            }
        )
    }

    $normalizedDrives = New-Object System.Collections.ArrayList
    foreach ($rawDrive in $rawDrives) {
        if (-not $rawDrive) {
            continue
        }

        $driveLetter = [string]$rawDrive.drive_letter
        if (-not $driveLetter) {
            continue
        }

        $storageTypeHint = [string]$rawDrive.storage_type_hint
        if (-not $storageTypeHint) {
            $storageTypeHint = 'Unknown'
        }

        $isSuitable = [bool]([double]$rawDrive.free_gb -ge $thresholds.readiness_blocked_storage_free_gb)

        [void]$normalizedDrives.Add([pscustomobject]@{
            drive_letter        = $driveLetter
            is_system_drive     = [bool]$rawDrive.is_system_drive
            filesystem          = if ($rawDrive.filesystem) { [string]$rawDrive.filesystem } else { 'Unknown' }
            total_gb            = [double]$rawDrive.total_gb
            free_gb             = [double]$rawDrive.free_gb
            storage_type_hint   = $storageTypeHint
            vm_storage_suitable = $isSuitable
        })
    }

    $preferredDrive = Get-PreferredVMStorage -Storage ([pscustomobject]@{ drives = @($normalizedDrives) }) -MinimumFreeGb $thresholds.readiness_blocked_storage_free_gb

    $systemDrive = @($normalizedDrives | Where-Object { $_.is_system_drive } | Select-Object -First 1)[0]
    if (-not $systemDrive) {
        $systemDrive = @($normalizedDrives | Select-Object -First 1)[0]
    }

    return [pscustomobject]@{
        system_drive          = if ($systemDrive) { [string]$systemDrive.drive_letter } else { [string]$Storage.system_drive }
        system_drive_fs       = if ($systemDrive) { [string]$systemDrive.filesystem } else { [string]$Storage.system_drive_fs }
        system_drive_total_gb = if ($systemDrive) { [double]$systemDrive.total_gb } else { [double]$Storage.system_drive_total_gb }
        system_drive_free_gb  = if ($systemDrive) { [double]$systemDrive.free_gb } else { [double]$Storage.system_drive_free_gb }
        physical_media_hint   = if ($systemDrive) { [string]$systemDrive.storage_type_hint } else { [string]$Storage.physical_media_hint }
        drives                = @($normalizedDrives)
        preferred_vm_storage  = if ($preferredDrive) {
            [pscustomobject]@{
                drive_letter        = [string]$preferredDrive.drive_letter
                is_system_drive     = [bool]$preferredDrive.is_system_drive
                filesystem          = [string]$preferredDrive.filesystem
                total_gb            = [double]$preferredDrive.total_gb
                free_gb             = [double]$preferredDrive.free_gb
                storage_type_hint   = [string]$preferredDrive.storage_type_hint
                vm_storage_suitable = [bool]$preferredDrive.vm_storage_suitable
            }
        }
        else {
            $null
        }
    }
}
