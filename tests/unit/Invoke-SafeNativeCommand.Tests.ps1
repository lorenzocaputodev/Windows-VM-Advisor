Describe 'Invoke-SafeNativeCommand' {
    BeforeAll {
        $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        . (Join-Path $projectRoot 'src\core\util\Test-CommandAvailable.ps1')
        . (Join-Path $projectRoot 'src\core\util\Invoke-SafeNativeCommand.ps1')
    }

    It 'returns null when the command is unavailable' {
        Mock Test-CommandAvailable { $false }

        (Invoke-SafeNativeCommand -FilePath 'missing-command') | Should -Be $null
    }

    It 'returns null when the command throws' {
        Mock Test-CommandAvailable { $true }
        function throw-native { throw 'boom' }

        try {
            (Invoke-SafeNativeCommand -FilePath 'throw-native') | Should -Be $null
        }
        finally {
            Remove-Item Function:\throw-native -ErrorAction SilentlyContinue
        }
    }

    It 'returns null when the command output is empty' {
        Mock Test-CommandAvailable { $true }
        function empty-native { '' }

        try {
            (Invoke-SafeNativeCommand -FilePath 'empty-native') | Should -Be $null
        }
        finally {
            Remove-Item Function:\empty-native -ErrorAction SilentlyContinue
        }
    }

    It 'returns trimmed output when the command succeeds' {
        Mock Test-CommandAvailable { $true }
        function ok-native { '  hello world  ' }

        try {
            (Invoke-SafeNativeCommand -FilePath 'ok-native') | Should -Be 'hello world'
        }
        finally {
            Remove-Item Function:\ok-native -ErrorAction SilentlyContinue
        }
    }
}
