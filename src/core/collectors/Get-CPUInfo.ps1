function Get-CPUInfo {
    $processors = @(Get-SafeCimInstance -ClassName 'Win32_Processor' | Where-Object { $_ })
    $cpu = if ($processors.Count -gt 0) { $processors[0] } else { $null }

    # Multi-socket hosts expose one Win32_Processor per socket; totals must cover all of them.
    $totalCores = [int](@($processors | ForEach-Object { if ($_.NumberOfCores) { [int]$_.NumberOfCores } else { 0 } }) | Measure-Object -Sum).Sum
    $totalThreads = [int](@($processors | ForEach-Object { if ($_.NumberOfLogicalProcessors) { [int]$_.NumberOfLogicalProcessors } else { 0 } }) | Measure-Object -Sum).Sum

    [pscustomobject]@{
        model                              = if ($cpu -and $cpu.Name) { $cpu.Name.Trim() } else { 'Unknown' }
        manufacturer                       = if ($cpu -and $cpu.Manufacturer) { [string]$cpu.Manufacturer } else { 'Unknown' }
        cores                              = $totalCores
        threads                            = $totalThreads
        max_clock_mhz                      = if ($cpu -and $cpu.MaxClockSpeed) { [int]$cpu.MaxClockSpeed } else { 0 }
        virtualization_supported           = [bool]($cpu -and $cpu.VMMonitorModeExtensions)
        virtualization_enabled_in_firmware = [bool]($cpu -and $cpu.VirtualizationFirmwareEnabled)
        slat_supported                     = [bool]($cpu -and $cpu.SecondLevelAddressTranslationExtensions)
    }
}
