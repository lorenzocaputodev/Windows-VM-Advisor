Describe 'iso-catalog.json integrity' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        . (Join-Path $script:ProjectRoot 'src\core\catalog\Get-IsoCatalog.ps1')
        $script:catalog = @(Get-IsoCatalog)
        $script:requiredFields = @(
            'id', 'display_name', 'family', 'flavor', 'category', 'architecture',
            'official_download_page', 'official_release_page', 'typical_vm_fit', 'role',
            'default_desktop_fit', 'resource_tier', 'specialist', 'requires_tpm',
            'requires_secure_boot', 'requires_uefi', 'notes', 'low_end_host_friendly',
            'general_purpose_vm_use', 'security_lab_use', 'enterprise_windows_testing',
            'base_score', 'min_host_ram_gb', 'min_free_storage_gb'
        )
    }

    It 'has unique ids' {
        $ids = @($script:catalog | Select-Object -ExpandProperty id)

        @($ids | Select-Object -Unique).Count | Should -Be $ids.Count
    }

    It 'defines every required field on every entry' {
        foreach ($entry in $script:catalog) {
            $names = @($entry.PSObject.Properties.Name)
            foreach ($field in $script:requiredFields) {
                ($names -contains $field) | Should -BeTrue -Because ('{0} must define {1}' -f $entry.id, $field)
            }
        }
    }

    It 'uses only https download and release pages' {
        foreach ($entry in $script:catalog) {
            $entry.official_download_page | Should -Match '^https://[^\s]+$' -Because $entry.id
            $entry.official_release_page | Should -Match '^https://[^\s]+$' -Because $entry.id
        }
    }

    It 'uses only known enumeration values' {
        foreach ($entry in $script:catalog) {
            $entry.typical_vm_fit | Should -BeIn @('light', 'balanced', 'performance') -Because $entry.id
            $entry.default_desktop_fit | Should -BeIn @('low', 'medium', 'high') -Because $entry.id
            $entry.resource_tier | Should -BeIn @('light', 'medium', 'heavy') -Because $entry.id
            $entry.family | Should -BeIn @('windows', 'linux', 'bsd') -Because $entry.id
            $entry.architecture | Should -Be 'x64' -Because $entry.id
        }
    }

    It 'uses positive numeric requirements' {
        foreach ($entry in $script:catalog) {
            ([double]$entry.min_host_ram_gb -gt 0) | Should -BeTrue -Because $entry.id
            ([double]$entry.min_free_storage_gb -gt 0) | Should -BeTrue -Because $entry.id
            ([int]$entry.base_score -gt 0) | Should -BeTrue -Because $entry.id
        }
    }

    It 'only marks entries as end of support together with an explanatory note' {
        foreach ($entry in $script:catalog) {
            $names = @($entry.PSObject.Properties.Name)
            if (($names -contains 'support_status') -and $entry.support_status -eq 'end_of_support') {
                ($names -contains 'support_note') | Should -BeTrue -Because $entry.id
                [string]$entry.support_note | Should -Not -BeNullOrEmpty -Because $entry.id
            }
        }
    }
}
