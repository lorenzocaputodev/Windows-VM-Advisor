function Get-SafeCimAssociatedInstance {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [string]$ResultClassName,

        [switch]$First
    )

    $results = @()

    if (Test-CommandAvailable -Name 'Get-CimAssociatedInstance') {
        try {
            $results = @(Get-CimAssociatedInstance -InputObject $InputObject -ResultClassName $ResultClassName -ErrorAction Stop)
        }
        catch {
            $results = @()
        }
    }

    if (@($results).Count -eq 0 -and (Test-CommandAvailable -Name 'Get-WmiObject')) {
        $relativePathProperty = $InputObject.PSObject.Properties['__RELPATH']
        $relativePath = if ($relativePathProperty) { [string]$relativePathProperty.Value } else { $null }

        if ($relativePath) {
            try {
                $results = @(
                    Get-WmiObject -Query ("ASSOCIATORS OF {{{0}}} WHERE ResultClass = {1}" -f $relativePath, $ResultClassName) -ErrorAction Stop
                )
            }
            catch {
                $results = @()
            }
        }
    }

    if (@($results).Count -eq 0) {
        if ($First) {
            return $null
        }

        return @()
    }

    if ($First) {
        return @($results | Select-Object -First 1)[0]
    }

    return $results
}
