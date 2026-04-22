function Invoke-SafeNativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @()
    )

    if (-not (Test-CommandAvailable -Name $FilePath)) {
        return $null
    }

    try {
        $output = & $FilePath @Arguments 2>$null | Out-String
    }
    catch {
        return $null
    }

    if (-not $output) {
        return $null
    }

    $text = $output.Trim()
    if (-not $text) {
        return $null
    }

    return $text
}
