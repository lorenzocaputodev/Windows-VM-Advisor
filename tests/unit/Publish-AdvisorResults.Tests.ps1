Describe 'Publish-AdvisorResults helpers' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\output\Publish-AdvisorResults.ps1')
    }

    BeforeEach {
        $script:workRoot = Join-Path $env:TEMP ('vmadv-publish-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:workRoot -Force | Out-Null
    }

    AfterEach {
        Remove-Item -LiteralPath $script:workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Resolve-UserPath' {
        It 'keeps rooted paths and resolves relative paths against the base' {
            Resolve-UserPath -Path 'C:\Data\Out' -BasePath 'D:\Base' | Should -Be 'C:\Data\Out'
            Resolve-UserPath -Path 'Out\Run' -BasePath 'D:\Base' | Should -Be 'D:\Base\Out\Run'
        }
    }

    Context 'New-ArchiveResultsDirectory' {
        It 'never reuses a directory created in the same second' {
            $archiveRoot = Join-Path $script:workRoot 'archive'

            $paths = 1..4 | ForEach-Object { New-ArchiveResultsDirectory -BasePath $archiveRoot }

            @($paths | Select-Object -Unique).Count | Should -Be 4
            foreach ($path in $paths) {
                (Test-Path -LiteralPath $path) | Should -BeTrue
            }
        }
    }

    Context 'Publish-LatestResults' {
        It 'copies the archive into latest and replaces the previous latest content' {
            $resultsRoot = Join-Path $script:workRoot 'results'
            $firstArchive = New-ArchiveResultsDirectory -BasePath (Join-Path $resultsRoot 'archive')
            Set-Content -LiteralPath (Join-Path $firstArchive 'Details.json') -Value 'first'
            Set-Content -LiteralPath (Join-Path $firstArchive 'Old-Only.txt') -Value 'old'
            Publish-LatestResults -ArchiveDir $firstArchive -ResultsRoot $resultsRoot | Out-Null

            $secondArchive = New-ArchiveResultsDirectory -BasePath (Join-Path $resultsRoot 'archive')
            Set-Content -LiteralPath (Join-Path $secondArchive 'Details.json') -Value 'second'
            $latest = Publish-LatestResults -ArchiveDir $secondArchive -ResultsRoot $resultsRoot

            $latest | Should -Be (Join-Path (Resolve-Path $resultsRoot).Path 'latest')
            (Get-Content -LiteralPath (Join-Path $latest 'Details.json')) | Should -Be 'second'
            (Test-Path -LiteralPath (Join-Path $latest 'Old-Only.txt')) | Should -BeFalse
        }

        It 'leaves no staging or backup folders behind' {
            $resultsRoot = Join-Path $script:workRoot 'results'
            $archive = New-ArchiveResultsDirectory -BasePath (Join-Path $resultsRoot 'archive')
            Set-Content -LiteralPath (Join-Path $archive 'Details.json') -Value 'data'

            Publish-LatestResults -ArchiveDir $archive -ResultsRoot $resultsRoot | Out-Null
            Publish-LatestResults -ArchiveDir $archive -ResultsRoot $resultsRoot | Out-Null

            $leftovers = @(Get-ChildItem -LiteralPath $resultsRoot -Force | Where-Object { $_.Name -like '.latest-*' })
            $leftovers.Count | Should -Be 0
        }

        It 'keeps the previous latest untouched when the archive cannot be copied' {
            $resultsRoot = Join-Path $script:workRoot 'results'
            $archive = New-ArchiveResultsDirectory -BasePath (Join-Path $resultsRoot 'archive')
            Set-Content -LiteralPath (Join-Path $archive 'Details.json') -Value 'good'
            $latest = Publish-LatestResults -ArchiveDir $archive -ResultsRoot $resultsRoot

            { Publish-LatestResults -ArchiveDir (Join-Path $script:workRoot 'missing') -ResultsRoot $resultsRoot } | Should -Throw

            (Get-Content -LiteralPath (Join-Path $latest 'Details.json')) | Should -Be 'good'
        }
    }

    Context 'Resolve-DefaultResultsRoot' {
        It 'uses the project Results folder when it is writable' {
            $result = Resolve-DefaultResultsRoot -ProjectRoot $script:workRoot -FallbackBase (Join-Path $script:workRoot 'fallback')

            $result | Should -Be (Join-Path $script:workRoot 'Results')
        }

        It 'falls back to the local app data folder when the project folder is not writable' {
            Mock Test-DirectoryWritable { $false }

            $result = Resolve-DefaultResultsRoot -ProjectRoot $script:workRoot -FallbackBase 'C:\Users\Test\AppData\Local'

            $result | Should -Be 'C:\Users\Test\AppData\Local\Windows-VM-Advisor\Results'
        }
    }
}
