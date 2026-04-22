$ErrorActionPreference = 'Stop'

$minimumPesterVersion = [version]'5.0.0'
$pesterModule = Get-Module -ListAvailable -Name Pester |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (($null -eq $pesterModule) -or ($pesterModule.Version -lt $minimumPesterVersion)) {
    throw ('Pester {0} or later is required. Run .\scripts\bootstrap-dev.ps1 first.' -f $minimumPesterVersion)
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testSuites = @(
    'tests\unit',
    'tests\integration'
)

function Invoke-TestSuiteInChildProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SuitePath
    )

    $escapedProjectRoot = $projectRoot.Replace("'", "''")
    $escapedSuitePath = $SuitePath.Replace("'", "''")
    $command = @"
Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath '$escapedProjectRoot'
Import-Module Pester -MinimumVersion $minimumPesterVersion -Force
`$configuration = New-PesterConfiguration
`$configuration.Run.Path = '$escapedSuitePath'
`$configuration.Run.PassThru = `$true
`$result = Invoke-Pester -Configuration `$configuration
if (-not `$result) { throw 'Pester did not return a result object.' }
`$failedCount = 0
if (`$result.PSObject.Properties.Name -contains 'FailedCount') { `$failedCount += [int]`$result.FailedCount }
if (`$result.PSObject.Properties.Name -contains 'FailedBlocksCount') { `$failedCount += [int]`$result.FailedBlocksCount }
if (`$failedCount -gt 0) { exit 1 }
"@

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $command | Out-Host
    return [int]$LASTEXITCODE
}

foreach ($suitePath in $testSuites) {
    $exitCode = Invoke-TestSuiteInChildProcess -SuitePath $suitePath
    if ($exitCode -ne 0) {
        throw ('Pester reported failures in suite {0}.' -f $suitePath)
    }
}

& (Join-Path $projectRoot 'scripts\validate-sample-report.ps1')
