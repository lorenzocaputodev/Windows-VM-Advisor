function ConvertTo-IsoRecommendationsText {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Report
    )

    $guidance = Get-BestFitGuidance -Report $Report
    $recommendations = @($Report.recommendations)
    $recommendedEntries = @($recommendations | Where-Object { [string]$_.compatibility_label -eq 'recommended' })
    $possibleEntries = @($recommendations | Where-Object { [string]$_.compatibility_label -eq 'possible' })
    $notRecommendedEntries = @($recommendations | Where-Object { [string]$_.compatibility_label -eq 'not_recommended' })
    $hasUsableEntries = [bool](($recommendedEntries.Count + $possibleEntries.Count) -gt 0)
    $lines = New-Object System.Collections.Generic.List[string]

    function Add-RecommendationGroup {
        param(
            [Parameter(Mandatory = $true)]
            $LineBuffer,

            [Parameter(Mandatory = $true)]
            [object[]]$Entries,

            [Parameter(Mandatory = $true)]
            [string]$Heading,

            [Parameter(Mandatory = $true)]
            [string]$LabelValue
        )

        $LineBuffer.Add($Heading + ':')
        $groupEntries = @($Entries | Where-Object { [string]$_.compatibility_label -eq $LabelValue })

        foreach ($entry in $groupEntries) {
            $label = switch ([string]$entry.compatibility_label) {
                'recommended' { 'Recommended' }
                'possible' { 'Possible' }
                default { 'Not recommended' }
            }

            $LineBuffer.Add(('- {0} [{1}]' -f $entry.display_name, $label))
            $LineBuffer.Add(('   {0}' -f $entry.fit_reason))
        }

        $LineBuffer.Add('')
    }

    $lines.Add('Windows-VM-Advisor - ISO Recommendations')
    $lines.Add('========================================')
    $lines.Add('')
    $lines.Add('Best-fit guidance:')
    if ($hasUsableEntries) {
        $lines.Add(('- Best overall fit: {0}' -f $guidance.best_overall.display_name))
        if ($guidance.best_lightweight -and -not $guidance.overall_is_lightweight) {
            $lines.Add(('- Best lightweight option: {0}' -f $guidance.best_lightweight.display_name))
        }
        if ($guidance.best_windows) {
            $lines.Add(('- Best Windows option: {0}' -f $guidance.best_windows.display_name))
        }
    }
    else {
        $lines.Add('- No practical guest is currently recommended under the current host conditions.')
    }
    $lines.Add('')
    if ($recommendedEntries.Count -gt 0) {
        Add-RecommendationGroup -LineBuffer $lines -Entries $recommendations -Heading 'Best choices' -LabelValue 'recommended'
    }
    if ($possibleEntries.Count -gt 0) {
        Add-RecommendationGroup -LineBuffer $lines -Entries $recommendations -Heading 'Usable, but less ideal' -LabelValue 'possible'
    }
    if ($notRecommendedEntries.Count -gt 0) {
        Add-RecommendationGroup -LineBuffer $lines -Entries $recommendations -Heading 'Not recommended' -LabelValue 'not_recommended'
    }

    return ($lines -join [Environment]::NewLine).TrimEnd()
}
