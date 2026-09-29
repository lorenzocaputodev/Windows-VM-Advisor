[CmdletBinding()]
param(
    [int]$TimeoutSeconds = 20
)

# Network check for the official pages listed in the guest catalog.
# It is intentionally not part of CI: sites can be slow, rate limit, or block automated requests.
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$catalogPath = Join-Path $projectRoot 'src\core\catalog\iso-catalog.json'
$catalog = Get-Content -Raw -Encoding UTF8 -Path $catalogPath | ConvertFrom-Json

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$failures = 0
foreach ($entry in $catalog) {
    foreach ($field in @('official_download_page', 'official_release_page')) {
        $url = [string]$entry.$field
        try {
            try {
                $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec $TimeoutSeconds -MaximumRedirection 10 -ErrorAction Stop
            }
            catch {
                # Some sites reject HEAD requests or unknown clients, so retry once with a browser-like GET.
                $response = Invoke-WebRequest -Uri $url -Method Get -UseBasicParsing -TimeoutSec $TimeoutSeconds -MaximumRedirection 10 -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' -ErrorAction Stop
            }

            Write-Host ('[OK  ] {0} {1} ({2})' -f $entry.id, $field, $response.StatusCode)
        }
        catch {
            $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
            if ($statusCode -in @(401, 403, 429)) {
                # The host answered but refuses automated clients, so the link cannot be judged from here.
                Write-Host ('[WARN] {0} {1} {2} - blocked for automated requests ({3})' -f $entry.id, $field, $url, $statusCode)
            }
            else {
                $failures++
                Write-Host ('[FAIL] {0} {1} {2} - {3}' -f $entry.id, $field, $url, $_.Exception.Message)
            }
        }
    }
}

if ($failures -gt 0) {
    throw ('{0} catalog link(s) could not be verified.' -f $failures)
}

Write-Host 'All catalog links responded.'
