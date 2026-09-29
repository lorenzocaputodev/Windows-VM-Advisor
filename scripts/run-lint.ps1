$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$settingsPath = Join-Path $projectRoot 'PSScriptAnalyzerSettings.psd1'

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    throw 'PSScriptAnalyzer is required. Install it with: Install-Module PSScriptAnalyzer -Scope CurrentUser'
}

Import-Module PSScriptAnalyzer

$findings = @(
    foreach ($relativePath in @('src', 'scripts')) {
        Invoke-ScriptAnalyzer -Path (Join-Path $projectRoot $relativePath) -Recurse -Settings $settingsPath
    }
)

if ($findings.Count -gt 0) {
    $findings | ForEach-Object {
        Write-Host ('{0}:{1} [{2}] {3}' -f $_.ScriptName, $_.Line, $_.RuleName, $_.Message)
    }

    throw ('PSScriptAnalyzer reported {0} finding(s).' -f $findings.Count)
}

Write-Host 'PSScriptAnalyzer found no issues.'
