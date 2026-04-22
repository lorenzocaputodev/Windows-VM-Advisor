Describe 'ConvertTo-SystemInfoText' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        . (Join-Path $script:ProjectRoot 'src\core\output\ConvertTo-SystemInfoText.ps1')

        function New-SystemInfoReport {
            param(
                [Parameter()]
                $ModuleCount = 2
            )

            return [pscustomobject]@{
                system_information = [pscustomobject]@{
                    os = [pscustomobject]@{
                        name         = 'Windows 10'
                        version      = '22H2'
                        build        = '19045'
                        architecture = 'x64'
                    }
                    cpu = [pscustomobject]@{
                        model                               = 'Intel Core i7'
                        cores                               = 8
                        threads                             = 16
                        max_clock_mhz                       = 4200
                        virtualization_supported           = $true
                        virtualization_enabled_in_firmware = $true
                        slat_supported                      = $true
                    }
                    memory = [pscustomobject]@{
                        total_gb     = 16.0
                        free_gb      = 3.7
                        module_count = $ModuleCount
                    }
                    storage = [pscustomobject]@{
                        system_drive          = 'C:'
                        system_drive_fs       = 'NTFS'
                        system_drive_total_gb = 475.0
                        system_drive_free_gb  = 48.0
                        physical_media_hint   = 'SSD'
                        drives = @(
                            [pscustomobject]@{
                                drive_letter        = 'C:'
                                is_system_drive     = $true
                                filesystem          = 'NTFS'
                                total_gb            = 475.0
                                free_gb             = 48.0
                                storage_type_hint   = 'SSD'
                                vm_storage_suitable = $true
                            },
                            [pscustomobject]@{
                                drive_letter        = 'D:'
                                is_system_drive     = $false
                                filesystem          = 'NTFS'
                                total_gb            = 931.0
                                free_gb             = 420.0
                                storage_type_hint   = 'SSD'
                                vm_storage_suitable = $true
                            },
                            [pscustomobject]@{
                                drive_letter        = 'E:'
                                is_system_drive     = $false
                                filesystem          = 'NTFS'
                                total_gb            = 120.0
                                free_gb             = 18.0
                                storage_type_hint   = 'HDD'
                                vm_storage_suitable = $false
                            }
                        )
                        preferred_vm_storage = [pscustomobject]@{
                            drive_letter      = 'D:'
                            storage_type_hint = 'SSD'
                            free_gb           = 420.0
                        }
                    }
                    firmware = [pscustomobject]@{
                        boot_mode   = 'UEFI'
                        secure_boot = $true
                    }
                    tpm = [pscustomobject]@{
                        present = $true
                        ready   = $false
                        version = '2.0'
                    }
                    hypervisors = [pscustomobject]@{
                        vmware_workstation_installed = $true
                        virtualbox_installed         = $false
                    }
                    windows_features = [pscustomobject]@{
                        device_guard_available   = $true
                        hyperv_enabled           = $false
                        memory_integrity_enabled = $false
                    }
                    notes = @()
                }
            }
        }
    }

    It 'describes VM storage fit with more context than a simple yes or no' {
        $report = New-SystemInfoReport

        $text = ConvertTo-SystemInfoText -Report $report

        $text | Should -Match 'TPM: Present, but not ready \| Version 2\.0'
        $text | Should -Match 'Hypervisors: VMware Workstation installed \| Oracle VirtualBox not detected'
        $text | Should -Match 'CPU layout: 8 cores, 16 threads, reported max clock 4200 MHz'
        $text | Should -Match 'Memory: 16 GB total, 3[.,]7 GB free across 2 module\(s\)'
        $text | Should -Match 'C: \[System\].*VM storage fit: Usable, but not ideal for VM files'
        $text | Should -Match 'D:.*VM storage fit: Preferred for VM files'
        $text | Should -Match 'E:.*VM storage fit: Too tight for practical VM files'
    }

    It 'omits low-confidence module wording when the memory module count is zero' {
        $report = New-SystemInfoReport -ModuleCount 0

        $text = ConvertTo-SystemInfoText -Report $report

        $text | Should -Match 'Memory: 16 GB total, 3[.,]7 GB free'
        $text | Should -Not -Match 'across 0 module\(s\)'
    }

    It 'omits the module count cleanly when it is null or unknown' {
        $report = New-SystemInfoReport -ModuleCount $null

        $text = ConvertTo-SystemInfoText -Report $report

        $text | Should -Match 'Memory: 16 GB total, 3[.,]7 GB free'
        $text | Should -Not -Match 'module\(s\)'
    }
}
