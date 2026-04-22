function Get-PreferredVMStorage {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Storage,

        [double]$MinimumFreeGb = 40
    )

    $thresholds = Get-AdvisorThresholds
    $mediaRank = @{
        NVMe    = 4
        SSD     = 3
        Unknown = 2
        HDD     = 1
    }

    $candidateDrives = @(
        @($Storage.drives) |
        Where-Object { [double]$_.free_gb -ge $MinimumFreeGb }
    )

    if ($candidateDrives.Count -eq 0) {
        return $null
    }

    $hasAlternative = [bool](@($candidateDrives | Where-Object { -not $_.is_system_drive }).Count -gt 0)

    return @(
        $candidateDrives |
        Sort-Object -Property `
            @{ Expression = {
                    if (
                        $_.is_system_drive -and
                        $hasAlternative -and
                        [double]$_.free_gb -lt $thresholds.readiness_limited_storage_free_gb
                    ) {
                        1
                    }
                    else {
                        0
                    }
                }; Descending = $false },
            @{ Expression = {
                    if ($mediaRank.ContainsKey([string]$_.storage_type_hint)) {
                        $mediaRank[[string]$_.storage_type_hint]
                    }
                    else {
                        0
                    }
                }; Descending = $true },
            @{ Expression = { [double]$_.free_gb }; Descending = $true },
            @{ Expression = { [string]$_.drive_letter }; Descending = $false } |
        Select-Object -First 1
    )[0]
}
