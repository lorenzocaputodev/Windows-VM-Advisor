function Resolve-BootMode {
    param(
        $FirmwareType,
        $ComputerInfo,
        [string]$BcdOutput
    )

    switch ($FirmwareType) {
        1 { return 'BIOS' }
        2 { return 'UEFI' }
    }

    if ($ComputerInfo) {
        $firmwareTypeProperty = $ComputerInfo.PSObject.Properties['BiosFirmwareType']
        if ($firmwareTypeProperty) {
            $firmwareText = [string]$firmwareTypeProperty.Value
            if ($firmwareText -match 'Uefi|EFI|UEFI') {
                return 'UEFI'
            }
            if ($firmwareText -match 'Legacy|Bios|BIOS') {
                return 'BIOS'
            }
        }

        $bootEnvironmentProperty = $ComputerInfo.PSObject.Properties['CsBootEnvironment']
        if ($bootEnvironmentProperty) {
            $bootEnvironment = [string]$bootEnvironmentProperty.Value
            if ($bootEnvironment -match 'EFI|UEFI') {
                return 'UEFI'
            }
            if ($bootEnvironment -match 'Legacy|BIOS|Bios') {
                return 'BIOS'
            }
        }
    }

    if ($BcdOutput) {
        if ($BcdOutput -match '(?im)^\s*path\s+.+\.efi\s*$' -or $BcdOutput -match '(?i)winload\.efi') {
            return 'UEFI'
        }
        if ($BcdOutput -match '(?im)^\s*path\s+.+\.exe\s*$' -or $BcdOutput -match '(?i)winload\.exe') {
            return 'BIOS'
        }
    }

    return 'Unknown'
}
