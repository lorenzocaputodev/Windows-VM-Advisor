Describe 'Get-TPMInfo' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\util\Test-CommandAvailable.ps1')
        . (Join-Path $projectRoot 'src\core\util\Get-SafeCimInstance.ps1')
        . (Join-Path $projectRoot 'src\core\collectors\Get-TPMInfo.ps1')
    }

    It 'falls back to Win32_Tpm and normalizes partial SpecVersion values' {
        Mock Test-CommandAvailable {
            param($Name)
            return ($Name -eq 'Get-Tpm')
        }
        Mock Get-Tpm { throw 'Get-Tpm failed' }
        Mock Get-SafeCimInstance {
            [pscustomobject]@{
                IsEnabled_InitialValue   = $true
                IsActivated_InitialValue = $true
                SpecVersion              = '2.0,1.3'
            }
        }

        $result = Get-TPMInfo

        $result.tpm_present | Should -BeTrue
        $result.tpm_ready | Should -BeTrue
        $result.tpm_version | Should -Be '2.0'
    }

    It 'uses CIM fallback when Get-Tpm is unavailable' {
        Mock Test-CommandAvailable { $false }
        Mock Get-SafeCimInstance {
            [pscustomobject]@{
                IsEnabled_InitialValue   = $true
                IsActivated_InitialValue = $true
                SpecVersion              = '1.2'
            }
        }

        $result = Get-TPMInfo

        $result.tpm_present | Should -BeTrue
        $result.tpm_ready | Should -BeTrue
        $result.tpm_version | Should -Be '1.2'
    }

    It 'does not overclaim readiness from weak CIM signals' {
        Mock Test-CommandAvailable { $false }
        Mock Get-SafeCimInstance {
            [pscustomobject]@{
                IsEnabled_InitialValue   = $true
                IsActivated_InitialValue = $false
                SpecVersion              = '2.0'
            }
        }

        $result = Get-TPMInfo

        $result.tpm_present | Should -BeTrue
        $result.tpm_ready | Should -BeFalse
        $result.tpm_version | Should -Be '2.0'
    }

    It 'preserves a detected present-but-not-ready state from Get-Tpm when CIM data is missing' {
        Mock Test-CommandAvailable {
            param($Name)
            return ($Name -eq 'Get-Tpm')
        }
        Mock Get-Tpm {
            [pscustomobject]@{
                TpmPresent = $true
                TpmReady = $false
                SpecVersion = '2.0 , 1.3'
                ManufacturerVersionFull20 = $null
            }
        }
        Mock Get-SafeCimInstance { $null }

        $result = Get-TPMInfo

        $result.tpm_present | Should -BeTrue
        $result.tpm_ready | Should -BeFalse
        $result.tpm_version | Should -Be '2.0'
    }
}
