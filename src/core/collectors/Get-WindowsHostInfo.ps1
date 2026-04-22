function Get-WindowsHostInfo {
    $os = Get-SafeCimInstance -ClassName 'Win32_OperatingSystem' -First

    $displayVersion = Get-SafeRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'DisplayVersion'
    if (-not $displayVersion) {
        $displayVersion = Get-SafeRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'ReleaseId'
    }

    [pscustomobject]@{
        name         = if ($os -and $os.Caption) { [string]$os.Caption } else { 'Unknown Windows' }
        version      = if ($displayVersion) { [string]$displayVersion } elseif ($os -and $os.Version) { [string]$os.Version } else { 'Unknown' }
        build        = if ($os -and $os.BuildNumber) { [string]$os.BuildNumber } else { 'Unknown' }
        architecture = if ($os -and $os.OSArchitecture) { [string]$os.OSArchitecture } else { 'Unknown' }
    }
}
