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

    return [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($BasePath, $Path))
}

function Test-DirectoryWritable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $probePath = $null
    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
        }

        $probePath = Join-Path $Path ('.write-test-{0}.tmp' -f [guid]::NewGuid().ToString('N'))
        Set-Content -LiteralPath $probePath -Value 'ok' -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($probePath -and (Test-Path -LiteralPath $probePath)) {
            Remove-Item -LiteralPath $probePath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Resolve-DefaultResultsRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,

        [string]$FallbackBase = $env:LOCALAPPDATA
    )

    $projectResults = Join-Path $ProjectRoot 'Results'
    if (Test-DirectoryWritable -Path $projectResults) {
        return $projectResults
    }

    # The project folder can be read-only (for example under Program Files).
    if ($FallbackBase) {
        return (Join-Path $FallbackBase 'Windows-VM-Advisor\Results')
    }

    return $projectResults
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
    $token = [guid]::NewGuid().ToString('N')
    $stagingDir = Join-Path $ResultsRoot ('.latest-staging-{0}' -f $token)
    $backupDir = Join-Path $ResultsRoot ('.latest-previous-{0}' -f $token)

    # Build the new folder next to the old one first, so a failed copy never leaves "latest" empty.
    New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
    try {
        foreach ($item in @(Get-ChildItem -LiteralPath $ArchiveDir -Force -ErrorAction Stop)) {
            Copy-Item -LiteralPath $item.FullName -Destination $stagingDir -Recurse -Force -ErrorAction Stop
        }

        $hadPrevious = Test-Path -LiteralPath $latestDir
        if ($hadPrevious) {
            Move-Item -LiteralPath $latestDir -Destination $backupDir -Force -ErrorAction Stop
        }

        try {
            Move-Item -LiteralPath $stagingDir -Destination $latestDir -Force -ErrorAction Stop
        }
        catch {
            if ($hadPrevious -and (Test-Path -LiteralPath $backupDir)) {
                Move-Item -LiteralPath $backupDir -Destination $latestDir -Force -ErrorAction Stop
            }

            throw
        }

        if ($hadPrevious) {
            Remove-Item -LiteralPath $backupDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    finally {
        if (Test-Path -LiteralPath $stagingDir) {
            Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    return (Resolve-Path $latestDir).Path
}
