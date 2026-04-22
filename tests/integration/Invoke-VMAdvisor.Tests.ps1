Describe 'Windows-VM-Advisor integration' {
    BeforeAll {
        $canonicalVersion = '1.0.0'
    }

    It 'writes archive and latest results from the PowerShell entrypoint' {
        $projectRoot = Join-Path $PSScriptRoot '..\..'
        $scriptPath = Join-Path $projectRoot 'src\entrypoints\Start-Windows-VM-Advisor.ps1'
        $resultsRoot = Join-Path $env:TEMP ('windows-vm-advisor-results-' + [guid]::NewGuid().ToString('N'))

        $output = & $scriptPath -ResultsRoot $resultsRoot | Out-String
        $archiveRoot = Join-Path $resultsRoot 'archive'
        $latestRoot = Join-Path $resultsRoot 'latest'
        $archiveDir = @(
            Get-ChildItem -Directory -Path $archiveRoot |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 1
        )[0]

        ($null -ne $archiveDir) | Should -BeTrue
        ($archiveDir.Name -match '^\d{8}-\d{6}(-\d+)?$') | Should -BeTrue
        (Test-Path $latestRoot) | Should -BeTrue

        $expectedFiles = @(
            'Details.json',
            'System-Info.txt',
            'VM-Readiness.txt',
            'ISO-Recommendations.txt',
            'VM-Profiles.txt'
        )

        foreach ($fileName in $expectedFiles) {
            (Test-Path (Join-Path $archiveDir.FullName $fileName)) | Should -BeTrue
            (Test-Path (Join-Path $latestRoot $fileName)) | Should -BeTrue
        }

        @((Get-ChildItem -File -Path $latestRoot).Name).Count | Should -Be 5

        $report = Get-Content -Raw (Join-Path $latestRoot 'Details.json') | ConvertFrom-Json
        $isoRecommendationsText = Get-Content -Raw (Join-Path $latestRoot 'ISO-Recommendations.txt')
        $vmProfilesText = Get-Content -Raw (Join-Path $latestRoot 'VM-Profiles.txt')

        ($report.PSObject.Properties.Name -contains 'system_information') | Should -BeTrue
        ($report.PSObject.Properties.Name -contains 'vm_readiness') | Should -BeTrue
        ($report.PSObject.Properties.Name -contains 'recommendations') | Should -BeTrue
        ($report.system_information.storage.PSObject.Properties.Name -contains 'drives') | Should -BeTrue
        ($report.system_information.storage.PSObject.Properties.Name -contains 'preferred_vm_storage') | Should -BeTrue
        (@($report.system_information.storage.drives).Count -ge 1) | Should -BeTrue
        ($report.vm_readiness.PSObject.Properties.Name -contains 'takeaway') | Should -BeTrue
        ($report.tool_version -eq $canonicalVersion) | Should -BeTrue
        ($report.inputs.guest_preference -eq 'auto') | Should -BeTrue
        $reportLabels = @($report.recommendations | Select-Object -ExpandProperty compatibility_label)
        $recommendedCount = @($report.recommendations | Where-Object { $_.compatibility_label -eq 'recommended' }).Count
        $possibleCount = @($report.recommendations | Where-Object { $_.compatibility_label -eq 'possible' }).Count
        $labelRank = @{
            recommended     = 3
            possible        = 2
            not_recommended = 1
        }
        $observedRanks = @($reportLabels | ForEach-Object { $labelRank[[string]$_] })
        $observedRanks | Should -Be (@($observedRanks | Sort-Object -Descending))
        ($output.Contains('Takeaway')) | Should -BeTrue
        ($output.Contains('System Overview')) | Should -BeTrue
        ($output.Contains('VM Readiness')) | Should -BeTrue
        ($output.Contains('Best-Fit Guidance')) | Should -BeTrue
        ($output.Contains('Top Recommendations')) | Should -BeTrue
        ($output.Contains('Results Path')) | Should -BeTrue
        ($output.Contains('VM Profiles')) | Should -BeFalse
        ($output.Contains('RESULTS_PATH:')) | Should -BeFalse
        ($output.Contains('Results folder:')) | Should -BeFalse
        ($output.Contains($latestRoot)) | Should -BeTrue
        # The old text formatter repeated the readiness takeaway here even though it already appears in console output and VM-Readiness.txt.
        ($isoRecommendationsText.Contains('Takeaway:')) | Should -BeFalse
        if ($recommendedCount -gt 0) {
            ($isoRecommendationsText.Contains('Best choices:')) | Should -BeTrue
        }
        else {
            ($isoRecommendationsText.Contains('Best choices:')) | Should -BeFalse
        }
        if ($possibleCount -gt 0) {
            ($isoRecommendationsText.Contains('Usable, but less ideal:')) | Should -BeTrue
        }
        else {
            ($isoRecommendationsText.Contains('Usable, but less ideal:')) | Should -BeFalse
        }
        if (($recommendedCount + $possibleCount) -eq 0) {
            ($isoRecommendationsText.Contains('No practical guest is currently recommended under the current host conditions.')) | Should -BeTrue
            ($output.Contains('Best overall fit: None')) | Should -BeFalse
        }
        ($isoRecommendationsText.Contains('Same as best overall fit')) | Should -BeFalse
        ($isoRecommendationsText.Contains('- ')) | Should -BeTrue
        ($isoRecommendationsText -match '(?m)^\d+\. .+ \[(Recommended|Possible|Not recommended)\]$') | Should -BeFalse
        if (@($report.recommendations | Where-Object { $_.compatibility_label -eq 'not_recommended' }).Count -gt 0) {
            ($isoRecommendationsText.Contains('Not recommended:')) | Should -BeTrue
        }
        else {
            ($isoRecommendationsText.Contains('Not recommended:')) | Should -BeFalse
        }
        ($output -match "Top Recommendations`r?`n-------------------`r?`n`r?`n(?:- .+`r?`n)+(?:- More usable options are listed in ISO-Recommendations\.txt \(\d+ additional\)\r?\n)?(?:- Full blocked list is in ISO-Recommendations\.txt\r?\n)?") | Should -BeTrue
        if ($output.Contains('VM settings are listed in VM-Profiles.txt')) {
            ($output -match "(?s)Top Recommendations.*(?:- Full blocked list is in ISO-Recommendations\.txt\r?\n)?\r?\nVM settings are listed in VM-Profiles\.txt") | Should -BeTrue
        }
        if ((@($report.recommendations | Where-Object { $_.id -eq 'windows-10' }).Count -gt 0) -and (@($report.recommendations | Where-Object { $_.id -eq 'windows-11' }).Count -gt 0)) {
            (@($report.recommendations | Select-Object -ExpandProperty id).IndexOf('windows-10')) | Should -BeLessThan (@($report.recommendations | Select-Object -ExpandProperty id).IndexOf('windows-11'))
        }
        if ((@($report.recommendations | Where-Object { $_.id -eq 'freebsd' }).Count -gt 0)) {
            (@($report.recommendations | Where-Object { $_.id -eq 'freebsd' } | Select-Object -First 1).family) | Should -Be 'bsd'
        }
        # The old VM profiles output also repeated the readiness takeaway at the top.
        ($vmProfilesText.Contains('Takeaway:')) | Should -BeFalse
        (($vmProfilesText.Contains('Best choices:')) -or ($vmProfilesText.Contains('No practical VM profiles are recommended'))) | Should -BeTrue
        (($vmProfilesText.Contains('Usable, but less ideal:')) -or ($vmProfilesText.Contains('No practical VM profiles are recommended'))) | Should -BeTrue
        (($vmProfilesText.Contains('- ')) -or ($vmProfilesText.Contains('No practical VM profiles are recommended'))) | Should -BeTrue
    }

    It 'returns a structured result from the internal CLI when PassThru is used' {
        $scriptPath = Join-Path $PSScriptRoot '..\..\src\cli\Invoke-VMAdvisor.ps1'
        $outputDir = Join-Path $env:TEMP ('windows-vm-advisor-internal-' + [guid]::NewGuid().ToString('N'))

        $result = & $scriptPath -GuestPreference auto -Mode balanced -OutputDir $outputDir -PassThru -Quiet

        ($null -ne $result) | Should -BeTrue
        ($result.PSObject.Properties.Name -contains 'Report') | Should -BeTrue
        ($result.PSObject.Properties.Name -contains 'OutputDir') | Should -BeTrue
        ($result.PSObject.Properties.Name -contains 'DetailsPath') | Should -BeTrue
        ($result.PSObject.Properties.Name -contains 'SystemInfoPath') | Should -BeTrue
        ($result.PSObject.Properties.Name -contains 'VMReadinessPath') | Should -BeTrue
        ($result.PSObject.Properties.Name -contains 'ISORecommendationsPath') | Should -BeTrue
        ($result.PSObject.Properties.Name -contains 'VMProfilesPath') | Should -BeTrue
        ($result.Report.tool_version -eq $canonicalVersion) | Should -BeTrue
        ($result.Report.inputs.guest_preference -eq 'auto') | Should -BeTrue
        ($result.Report.system_information.storage.PSObject.Properties.Name -contains 'drives') | Should -BeTrue
        ($result.Report.system_information.storage.PSObject.Properties.Name -contains 'preferred_vm_storage') | Should -BeTrue
        (Test-Path $result.DetailsPath) | Should -BeTrue
        (Test-Path $result.SystemInfoPath) | Should -BeTrue
        (Test-Path $result.VMReadinessPath) | Should -BeTrue
        (Test-Path $result.ISORecommendationsPath) | Should -BeTrue
        (Test-Path $result.VMProfilesPath) | Should -BeTrue
    }

    It 'launches successfully through the BAT wrapper and forwards arguments' {
        $projectRoot = Join-Path $PSScriptRoot '..\..'
        $scriptPath = Join-Path $projectRoot 'Windows-VM-Advisor.bat'
        $resultsRoot = Join-Path $env:TEMP ('windows-vm-advisor-bat-' + [guid]::NewGuid().ToString('N'))

        $output = & cmd.exe /c ('(echo N& echo.) | "{0}" -Guest linux -Mode performance -ResultsRoot "{1}"' -f $scriptPath, $resultsRoot) | Out-String
        $exitCode = $LASTEXITCODE
        $latestRoot = Join-Path $resultsRoot 'latest'

        $exitCode | Should -Be 0
        (Test-Path $latestRoot) | Should -BeTrue
        ($output.Contains('[SUCCESS]')) | Should -BeTrue
        ($output.Contains('RESULTS_PATH:')) | Should -BeFalse
        ($output.Contains('Open the results folder now? [Y/N]:')) | Should -BeTrue
        ($output.Contains('Results folder:')) | Should -BeFalse

        $report = Get-Content -Raw (Join-Path $latestRoot 'Details.json') | ConvertFrom-Json
        ($report.inputs.guest_preference -eq 'linux') | Should -BeTrue
        ($report.inputs.mode -eq 'performance') | Should -BeTrue
    }
}
