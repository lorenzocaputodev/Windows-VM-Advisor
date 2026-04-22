[CmdletBinding()]
param(
    [ValidateSet('auto', 'windows', 'linux')]
    [string]$Guest = 'auto',

    [ValidateSet('light', 'balanced', 'performance')]
    [string]$Mode = 'balanced',

    [string]$ResultsRoot,

    [string]$ResultsPathFile
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)
$internalCliPath = Join-Path $projectRoot 'src\cli\Invoke-VMAdvisor.ps1'
${bestFitGuidancePath} = Join-Path $projectRoot 'src\core\output\Get-BestFitGuidance.ps1'
${consoleFormatterPath} = Join-Path $projectRoot 'src\core\output\ConvertTo-UserConsoleSummary.ps1'

function Resolve-UserPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
}

function New-ArchiveResultsDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    if (-not (Test-Path $BasePath)) {
        New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $candidatePath = Join-Path $BasePath $timestamp
    $suffix = 1

    while (Test-Path $candidatePath) {
        $candidatePath = Join-Path $BasePath ('{0}-{1}' -f $timestamp, $suffix)
        $suffix++
    }

    New-Item -ItemType Directory -Path $candidatePath | Out-Null
    return (Resolve-Path $candidatePath).Path
}

function Publish-LatestResults {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchiveDir,

        [Parameter(Mandatory = $true)]
        [string]$ResultsRoot
    )

    if (-not (Test-Path $ResultsRoot)) {
        New-Item -ItemType Directory -Path $ResultsRoot -Force | Out-Null
    }

    $latestDir = Join-Path $ResultsRoot 'latest'
    if (Test-Path $latestDir) {
        Remove-Item -LiteralPath $latestDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $latestDir -Force | Out-Null

    foreach ($item in @(Get-ChildItem -LiteralPath $ArchiveDir -Force)) {
        Copy-Item -LiteralPath $item.FullName -Destination $latestDir -Recurse -Force
    }

    return (Resolve-Path $latestDir).Path
}

if (-not (Test-Path $internalCliPath)) {
    throw 'Internal CLI entry point was not found.'
}

if (-not (Test-Path $bestFitGuidancePath)) {
    throw 'Best-fit guidance helper was not found.'
}

if (-not (Test-Path $consoleFormatterPath)) {
    throw 'Console summary formatter was not found.'
}

. $bestFitGuidancePath
. $consoleFormatterPath

$resultsBasePath = if ($ResultsRoot) {
    Resolve-UserPath -Path $ResultsRoot -BasePath $projectRoot
}
else {
    Join-Path $projectRoot 'Results'
}

$archiveRoot = Join-Path $resultsBasePath 'archive'
$archiveDir = New-ArchiveResultsDirectory -BasePath $archiveRoot

$result = & $internalCliPath `
    -GuestPreference $Guest `
    -Mode $Mode `
    -HypervisorPreference 'auto' `
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
