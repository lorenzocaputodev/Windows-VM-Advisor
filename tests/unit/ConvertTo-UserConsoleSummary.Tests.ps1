Describe 'ConvertTo-UserConsoleSummary' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        . (Join-Path $script:ProjectRoot 'src\core\catalog\Get-IsoCatalog.ps1')
        . (Join-Path $script:ProjectRoot 'src\core\output\Get-BestFitGuidance.ps1')
        . (Join-Path $script:ProjectRoot 'src\core\output\ConvertTo-UserConsoleSummary.ps1')
    }

    It 'omits empty fit placeholders and keeps blocked recommendations visible in no-usable cases' {
        $report = [pscustomobject]@{
            system_information = [pscustomobject]@{
                os = [pscustomobject]@{
                    name         = 'Windows 10'
                    version      = '22H2'
                    build        = '19045'
                    architecture = '64-bit'
                }
                cpu = [pscustomobject]@{
                    model                               = 'Intel Core i5'
                    cores                               = 4
                    threads                             = 8
                    virtualization_supported           = $true
                    virtualization_enabled_in_firmware = $true
                    slat_supported                      = $true
                }
                memory = [pscustomobject]@{
                    total_gb = 8.0
                    free_gb  = 1.8
                }
                storage = [pscustomobject]@{
                    system_drive          = 'C:'
                    system_drive_free_gb  = 24.5
                    system_drive_total_gb = 128.0
                    physical_media_hint   = 'SSD'
                    preferred_vm_storage  = $null
                }
                firmware = [pscustomobject]@{
                    boot_mode   = 'UEFI'
                    secure_boot = $true
                }
                tpm = [pscustomobject]@{
                    present = $false
                    ready   = $false
                    version = 'Unknown'
                }
                hypervisors = [pscustomobject]@{
                    vmware_workstation_installed = $false
                    virtualbox_installed         = $true
                }
                windows_features = [pscustomobject]@{
                    hyperv_enabled           = $false
                    memory_integrity_enabled = $false
                    device_guard_available   = $true
                }
            }
            vm_readiness = [pscustomobject]@{
                state          = 'not_ready'
                headline       = 'This PC should not be used for a practical VM until blockers are resolved.'
                primary_reason = 'No local fixed drive has enough free space for a practical VM disk.'
                takeaway       = 'No practical VM guest is a good fit until the current blockers are resolved.'
            }
            recommendations = @(
                [pscustomobject]@{
                    id                  = 'linux-mint'
                    display_name        = 'Linux Mint'
                    family              = 'linux'
                    compatibility_label = 'not_recommended'
                    fit_reason          = 'No suitable local fixed drive has enough free space for Linux Mint.'
                    vm_profile          = $null
                    notes               = @()
                },
                [pscustomobject]@{
                    id                  = 'ubuntu-lts'
                    display_name        = 'Ubuntu LTS'
                    family              = 'linux'
                    compatibility_label = 'not_recommended'
                    fit_reason          = 'No suitable local fixed drive has enough free space for Ubuntu LTS.'
                    vm_profile          = $null
                    notes               = @()
                }
            )
        }

        $text = ConvertTo-UserConsoleSummary -Report $report -ResultsPath 'C:\Temp\latest'

        $text | Should -Match 'Best-Fit Guidance'
        $text | Should -Match 'No practical guest is currently recommended under the current host conditions\.'
        $text | Should -Not -Match 'Best overall fit: None'
        $text | Should -Match 'Top Recommendations'
        $text | Should -Match 'Linux Mint \[Not recommended\]'
    }
}
