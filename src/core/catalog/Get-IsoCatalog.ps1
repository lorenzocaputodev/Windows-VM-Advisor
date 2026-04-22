$script:IsoCatalogPath = Join-Path $PSScriptRoot 'iso-catalog.json'

function Get-IsoCatalog {
    if (-not (Get-Variable -Name IsoCatalogCache -Scope Script -ErrorAction SilentlyContinue)) {
        $script:IsoCatalogCache = $null
    }

    if (-not $script:IsoCatalogCache) {
        $script:IsoCatalogCache = Get-Content -Raw -Path $script:IsoCatalogPath | ConvertFrom-Json
    }

    return $script:IsoCatalogCache
}
