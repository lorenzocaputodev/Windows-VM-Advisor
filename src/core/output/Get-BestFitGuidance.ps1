function Get-BestFitGuidance {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Report
    )

    $recommendations = @($Report.recommendations)
    $recommendedRecommendations = @(
        $recommendations |
        Where-Object { $_.compatibility_label -eq 'recommended' }
    )
    $possibleRecommendations = @(
        $recommendations |
        Where-Object { $_.compatibility_label -eq 'possible' }
    )
    $usableRecommendations = @(
        $recommendations |
        Where-Object { $_.compatibility_label -ne 'not_recommended' }
    )

    $bestOverall = $null
    if ($usableRecommendations.Count -gt 0) {
        $bestOverall = @($usableRecommendations | Select-Object -First 1)[0]
    }
    $catalogEntries = @()
    try {
        $catalogEntries = @(Get-IsoCatalog)
    }
    catch {
        $catalogEntries = @()
    }

    $catalogById = @{}
    foreach ($catalogEntry in $catalogEntries) {
        $catalogById[[string]$catalogEntry.id] = $catalogEntry
    }

    function Get-CatalogRole {
        param([pscustomobject]$Recommendation)

        $catalogEntry = $catalogById[[string]$Recommendation.id]
        if ($catalogEntry) {
            return [string]$catalogEntry.role
        }

        return ''
    }

    $bestLightweight = $null
    $bestLightweightMatches = @(
        $usableRecommendations |
        Where-Object { (Get-CatalogRole -Recommendation $_) -eq 'lightweight_desktop' } |
        Select-Object -First 1
    )
    if ($bestLightweightMatches.Count -gt 0) {
        $bestLightweight = @($bestLightweightMatches)[0]
    }

    if (-not $bestLightweight) {
        $bestLightweightMatches = @(
            $usableRecommendations |
            Where-Object {
                $_.family -eq 'linux' -and
                $_.vm_profile -and
                [int]$_.vm_profile.memory_mb -le 4096
            } |
            Select-Object -First 1
        )
        if ($bestLightweightMatches.Count -gt 0) {
            $bestLightweight = @($bestLightweightMatches)[0]
        }
    }
    $bestWindowsMatches = @(
        $usableRecommendations |
        Where-Object { (Get-CatalogRole -Recommendation $_) -eq 'windows_desktop' } |
        Select-Object -First 1
    )
    $bestWindowsMatches = @($bestWindowsMatches)
    $bestWindows = if ($bestWindowsMatches.Count -gt 0) { @($bestWindowsMatches)[0] } else { $null }

    return [pscustomobject]@{
        best_overall     = $bestOverall
        best_lightweight = $bestLightweight
        best_windows     = $bestWindows
        overall_is_lightweight = [bool]($bestOverall -and $bestLightweight -and $bestOverall.id -eq $bestLightweight.id)
    }
}
