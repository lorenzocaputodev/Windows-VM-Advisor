function ConvertTo-AdvisorJson {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Report
    )

    return ($Report | ConvertTo-Json -Depth 12)
}
