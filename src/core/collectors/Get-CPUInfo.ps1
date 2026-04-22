function Get-CPUInfo {
    $cpu = Get-SafeCimInstance -ClassName 'Win32_Processor' -First

    [pscustomobject]@{
        model                              = if ($cpu -and $cpu.Name) { $cpu.Name.Trim() } else { 'Unknown' }
        manufacturer                       = if ($cpu -and $cpu.Manufacturer) { [string]$cpu.Manufacturer } else { 'Unknown' }
        cores                              = if ($cpu -and $cpu.NumberOfCores) { [int]$cpu.NumberOfCores } else { 0 }
        threads                            = if ($cpu -and $cpu.NumberOfLogicalProcessors) { [int]$cpu.NumberOfLogicalProcessors } else { 0 }
        max_clock_mhz                      = if ($cpu -and $cpu.MaxClockSpeed) { [int]$cpu.MaxClockSpeed } else { 0 }
        virtualization_supported           = [bool]($cpu -and $cpu.VMMonitorModeExtensions)
        virtualization_enabled_in_firmware = [bool]($cpu -and $cpu.VirtualizationFirmwareEnabled)
        slat_supported                     = [bool]($cpu -and $cpu.SecondLevelAddressTranslationExtensions)
    }
}
