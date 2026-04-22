Describe 'ConvertTo-IsoRecommendationsText' {
    BeforeAll {
        . "$PSScriptRoot\..\TestHelpers.ps1"
        . (Join-Path $script:ProjectRoot 'src\core\catalog\Get-IsoCatalog.ps1')
        . (Join-Path $script:ProjectRoot 'src\core\output\Get-BestFitGuidance.ps1')
        . (Join-Path $script:ProjectRoot 'src\core\output\ConvertTo-IsoRecommendationsText.ps1')
    }

    It 'suppresses empty usable sections and uses a clean summary when no practical guest is usable' {
        $report = [pscustomobject]@{
            recommendations = @(
                [pscustomobject]@{
                    id                  = 'linux-mint'
                    display_name        = 'Linux Mint'
                    family              = 'linux'
                    compatibility_label = 'not_recommended'
                    fit_reason          = 'No suitable local fixed drive has enough free space for Linux Mint.'
                    vm_profile          = $null
                },
                [pscustomobject]@{
                    id                  = 'ubuntu-lts'
                    display_name        = 'Ubuntu LTS'
                    family              = 'linux'
                    compatibility_label = 'not_recommended'
                    fit_reason          = 'No suitable local fixed drive has enough free space for Ubuntu LTS.'
                    vm_profile          = $null
                }
            )
        }

        $text = ConvertTo-IsoRecommendationsText -Report $report

        $text | Should -Match 'Best-fit guidance:'
        $text | Should -Match 'No practical guest is currently recommended under the current host conditions\.'
        $text | Should -Not -Match 'Best overall fit: None'
        $text | Should -Not -Match 'Best choices:'
        $text | Should -Not -Match 'Usable, but less ideal:'
        $text | Should -Match 'Not recommended:'
        $text | Should -Match 'Linux Mint \[Not recommended\]'
    }
}
