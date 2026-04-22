function Get-FirmwareInfo {
    $firmwareType = Get-SafeRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'PEFirmwareType'
    $computerInfo = $null

    if (Test-CommandAvailable -Name 'Get-ComputerInfo') {
        try {
            $computerInfo = Get-ComputerInfo -Property 'BiosFirmwareType', 'CsBootEnvironment' -ErrorAction Stop
        }
        catch {
            $computerInfo = $null
        }
    }

    $bcdOutput = Invoke-SafeNativeCommand -FilePath 'bcdedit' -Arguments @('/enum', '{current}')

    $bootMode = Resolve-BootMode -FirmwareType $firmwareType -ComputerInfo $computerInfo -BcdOutput $bcdOutput

    $secureBoot = $false
    if ($bootMode -eq 'UEFI' -and (Test-CommandAvailable -Name 'Confirm-SecureBootUEFI')) {
        try {
            $secureBoot = [bool](Confirm-SecureBootUEFI -ErrorAction Stop)
        }
        catch {
            $secureBoot = $false
        }
    }

    [pscustomobject]@{
        boot_mode   = $bootMode
        secure_boot = $secureBoot
    }
}
