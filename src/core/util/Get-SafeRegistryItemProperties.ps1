function Get-SafeRegistryItemProperties {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        return @(Get-ItemProperty -Path $Path -ErrorAction Stop)
    }
    catch {
        return @()
    }
}
