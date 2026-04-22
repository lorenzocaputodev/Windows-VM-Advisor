function Convert-ToRoundedGigabytes {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Bytes
    )

    return [math]::Round(($Bytes / 1GB), 1)
}
