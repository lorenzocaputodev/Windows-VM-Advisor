function Get-SafeCimInstance {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClassName,

        [string]$Namespace = 'root/cimv2',

        [string]$Filter,

        [switch]$First
    )

    $results = @()
    $normalizedNamespace = if ($Namespace) { $Namespace -replace '/', '\' } else { 'root\cimv2' }

    if (Test-CommandAvailable -Name 'Get-CimInstance') {
        $parameters = @{
            ClassName   = $ClassName
            Namespace   = $Namespace
            ErrorAction = 'Stop'
        }

        if ($Filter) {
            $parameters.Filter = $Filter
        }

        try {
            $results = @(Get-CimInstance @parameters)
        }
        catch {
            $results = @()
        }
    }

    if (@($results).Count -eq 0 -and (Test-CommandAvailable -Name 'Get-WmiObject')) {
        $parameters = @{
            Class       = $ClassName
            Namespace   = $normalizedNamespace
            ErrorAction = 'Stop'
        }

        if ($Filter) {
            $parameters.Filter = $Filter
        }

        try {
            $results = @(Get-WmiObject @parameters)
        }
        catch {
            $results = @()
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
