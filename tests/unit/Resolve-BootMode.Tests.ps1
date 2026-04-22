Describe 'Resolve-BootMode' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        foreach ($relativePath in @(Get-AdvisorRulePaths)) {
            . (Join-Path $script:ProjectRoot $relativePath)
        }
    }

    It 'returns the registry firmware type when available' {
        Resolve-BootMode -FirmwareType 2 | Should -Be 'UEFI'
    }

    It 'falls back to Get-ComputerInfo firmware data when the registry value is missing' {
        $computerInfo = [pscustomobject]@{
            BiosFirmwareType = 'Uefi'
        }

        Resolve-BootMode -FirmwareType $null -ComputerInfo $computerInfo | Should -Be 'UEFI'
    }

    It 'falls back to bcdedit output when earlier sources are unavailable' {
        Resolve-BootMode -FirmwareType $null -BcdOutput 'path                    \Windows\system32\winload.exe' | Should -Be 'BIOS'
    }

    It 'recognizes broader EFI loader paths in bcdedit output' {
        Resolve-BootMode -FirmwareType $null -BcdOutput 'path                    \EFI\Microsoft\Boot\bootmgfw.efi' | Should -Be 'UEFI'
    }

    It 'returns Unknown when no safe signal is available' {
        Resolve-BootMode -FirmwareType $null | Should -Be 'Unknown'
    }
}
