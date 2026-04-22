$ErrorActionPreference = 'Stop'
$minimumPesterVersion = [version]'5.0.0'

Write-Host 'Bootstrapping Windows-VM-Advisor development environment...'

if (-not (Get-Command Install-Module -ErrorAction SilentlyContinue)) {
    throw 'Install-Module is not available. PowerShellGet may be missing.'
}

try {
    $pesterModule = Get-Module -ListAvailable -Name Pester |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (($null -eq $pesterModule) -or ($pesterModule.Version -lt $minimumPesterVersion)) {
        Write-Host ("Installing Pester {0} or later for current user..." -f $minimumPesterVersion)
        Install-Module -Name Pester -MinimumVersion $minimumPesterVersion -Scope CurrentUser -Force -SkipPublisherCheck
    }
    else {
        Write-Host ("Pester {0} already available." -f $pesterModule.Version)
    }
}
catch {
    Write-Warning ('Could not install Pester automatically: {0}' -f $_.Exception.Message)
}

Write-Host 'Bootstrap complete.'
