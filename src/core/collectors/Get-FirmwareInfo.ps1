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
    if ($bootMode -eq 'UEFI') {
        $secureBootConfirmed = $false
        if (Test-CommandAvailable -Name 'Confirm-SecureBootUEFI') {
            try {
                $secureBoot = [bool](Confirm-SecureBootUEFI -ErrorAction Stop)
                $secureBootConfirmed = $true
            }
            catch {
                $secureBoot = $false
            }
        }

        # Confirm-SecureBootUEFI needs elevation; the registry state is readable without it.
        if (-not $secureBootConfirmed) {
            $secureBootState = Get-SafeRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' -Name 'UEFISecureBootEnabled'
            $secureBoot = ($secureBootState -eq 1)
        }
    }

    [pscustomobject]@{
        boot_mode   = $bootMode
        secure_boot = $secureBoot
    }
}
