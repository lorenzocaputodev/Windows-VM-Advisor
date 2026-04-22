function Get-RAMInfo {
    $computerSystem = Get-SafeCimInstance -ClassName 'Win32_ComputerSystem' -First
    $os = Get-SafeCimInstance -ClassName 'Win32_OperatingSystem' -First
    $modules = @(Get-SafeCimInstance -ClassName 'Win32_PhysicalMemory')

    $totalBytes = 0
    if ($computerSystem -and $computerSystem.TotalPhysicalMemory) {
        $totalBytes = [double]$computerSystem.TotalPhysicalMemory
    }

    $freeBytes = 0
    if ($os -and $os.FreePhysicalMemory) {
        $freeBytes = ([double]$os.FreePhysicalMemory) * 1KB
    }

    [pscustomobject]@{
        total_gb     = Convert-ToRoundedGigabytes -Bytes $totalBytes
        free_gb      = Convert-ToRoundedGigabytes -Bytes $freeBytes
        module_count = $modules.Count
    }
}
