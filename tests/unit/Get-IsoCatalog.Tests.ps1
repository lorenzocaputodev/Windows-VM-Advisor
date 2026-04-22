Describe 'Get-IsoCatalog' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        . (Join-Path $script:ProjectRoot 'src\core\catalog\Get-IsoCatalog.ps1')
    }

    It 'contains exactly the final 12 guest entries for the redesigned catalog step' {
        $catalog = @(Get-IsoCatalog)
        $ids = @($catalog | Select-Object -ExpandProperty id)

        $ids | Should -Be @(
            'windows-11',
            'windows-10',
            'linux-mint',
            'ubuntu-lts',
            'debian-stable',
            'fedora-workstation',
            'lubuntu',
            'kali-linux',
            'arch-linux',
            'rocky-linux',
            'freebsd',
            'nixos'
        )
    }

    It 'adds the new compact metadata fields to every catalog entry' {
        $catalog = @(Get-IsoCatalog)

        foreach ($entry in $catalog) {
            (@($entry.PSObject.Properties.Name) -contains 'role') | Should -BeTrue
            (@($entry.PSObject.Properties.Name) -contains 'default_desktop_fit') | Should -BeTrue
            (@($entry.PSObject.Properties.Name) -contains 'resource_tier') | Should -BeTrue
            (@($entry.PSObject.Properties.Name) -contains 'specialist') | Should -BeTrue
        }
    }

    It 'keeps FreeBSD internally coherent as a Unix-like BSD guest' {
        $catalog = @(Get-IsoCatalog)
        $freebsd = @($catalog | Where-Object { $_.id -eq 'freebsd' })[0]

        $freebsd.family | Should -Be 'bsd'
        $freebsd.category | Should -Be 'unix_like'
        $freebsd.role | Should -Be 'unix_like_advanced'
    }
}
