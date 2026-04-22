function Get-SafeRegistryValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        $Default = $null
    )

    try {
        $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
    }
    catch {
        return $Default
    }

    if ($item.PSObject.Properties.Name -contains $Name) {
        return $item.$Name
    }

    return $Default
}
