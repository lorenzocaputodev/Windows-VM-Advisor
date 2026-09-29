[CmdletBinding()]
param(
    [ValidateSet('auto', 'windows', 'linux')]
    [string]$Guest = 'auto',

    [ValidateSet('light', 'balanced', 'performance')]
    [string]$Mode = 'balanced',

    [ValidateSet('auto', 'vmware', 'virtualbox')]
    [string]$Hypervisor = 'auto',

    [string]$ResultsRoot,

    [string]$ResultsPathFile
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)
$internalCliPath = Join-Path $projectRoot 'src\cli\Invoke-VMAdvisor.ps1'
$helperPaths = @(
    (Join-Path $projectRoot 'src\core\output\Publish-AdvisorResults.ps1'),
    (Join-Path $projectRoot 'src\core\output\Get-BestFitGuidance.ps1'),
    (Join-Path $projectRoot 'src\core\output\ConvertTo-UserConsoleSummary.ps1')
)

if (-not (Test-Path $internalCliPath)) {
    throw 'Internal CLI entry point was not found.'
}

foreach ($helperPath in $helperPaths) {
    if (-not (Test-Path $helperPath)) {
        throw ('Required helper was not found: {0}' -f (Split-Path -Leaf $helperPath))
    }

    . $helperPath
}

$resultsBasePath = if ($ResultsRoot) {
    Resolve-UserPath -Path $ResultsRoot -BasePath $projectRoot
}
else {
    Resolve-DefaultResultsRoot -ProjectRoot $projectRoot
}

$archiveRoot = Join-Path $resultsBasePath 'archive'
$archiveDir = New-ArchiveResultsDirectory -BasePath $archiveRoot

$result = & $internalCliPath `
    -GuestPreference $Guest `
    -Mode $Mode `
    -HypervisorPreference $Hypervisor `
    -OutputDir $archiveDir `
    -PassThru `
    -Quiet

if (-not $result -or -not $result.Report) {
    throw 'Windows-VM-Advisor did not return a valid result.'
}

$latestDir = Publish-LatestResults -ArchiveDir $archiveDir -ResultsRoot $resultsBasePath
$consoleSummary = ConvertTo-UserConsoleSummary -Report $result.Report -ResultsPath $latestDir

if ($ResultsPathFile) {
    Set-Content -LiteralPath $ResultsPathFile -Value $latestDir -Encoding ASCII
}

Write-Output $consoleSummary
