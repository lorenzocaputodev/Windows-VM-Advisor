Describe 'Get-NominalMemoryGb' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\util\Get-NominalMemoryGb.ps1')
    }

    It 'maps <Reported> GB reported by Windows to <Expected> GB installed' -ForEach @(
        @{ Reported = 3.5; Expected = 4 }
        @{ Reported = 5.6; Expected = 6 }
        @{ Reported = 7.6; Expected = 8 }
        @{ Reported = 8.0; Expected = 8 }
        @{ Reported = 15.9; Expected = 16 }
        @{ Reported = 31.8; Expected = 32 }
    ) {
        Get-NominalMemoryGb -ReportedGb $Reported | Should -Be $Expected
    }

    It 'returns zero when no memory was detected' {
        Get-NominalMemoryGb -ReportedGb 0 | Should -Be 0
    }
}
