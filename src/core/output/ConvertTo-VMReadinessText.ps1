function ConvertTo-VMReadinessText {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Report
    )

    $readiness = $Report.vm_readiness
    $system = $Report.system_information
    $lines = New-Object System.Collections.Generic.List[string]
    $systemDriveCheck = @($readiness.checks | Where-Object { $_.id -eq 'system-drive-pressure' } | Select-Object -First 1)[0]
    $vmStorageCheck = @($readiness.checks | Where-Object { $_.id -eq 'vm-storage-availability' } | Select-Object -First 1)[0]

    function Get-CheckStatusText {
        param([string]$Status)

        switch ($Status) {
            'ok' { return 'OK' }
            'warning' { return 'Warning' }
            'blocked' { return 'Blocked' }
            'info' { return 'Info' }
            default { return $Status }
        }
    }

    $lines.Add('Windows-VM-Advisor - VM Readiness')
    $lines.Add('=================================')
    $lines.Add('')
    $lines.Add(('Takeaway: {0}' -f $readiness.takeaway))
    $lines.Add('')
    $lines.Add(('State: {0}' -f $readiness.state.ToUpperInvariant()))
    if ($readiness.headline -and $readiness.headline -ne $readiness.takeaway -and $readiness.headline -ne $readiness.primary_reason) {
        $lines.Add(('Headline: {0}' -f $readiness.headline))
    }
    if ($readiness.primary_reason -and $readiness.primary_reason -ne $readiness.takeaway -and $readiness.primary_reason -ne $readiness.headline) {
        $lines.Add(('Why this result: {0}' -f $readiness.primary_reason))
    }
    $lines.Add('')
    $lines.Add('Storage at a glance:')
    if ($systemDriveCheck) {
        $lines.Add(('- System drive pressure: {0} - {1}' -f (Get-CheckStatusText -Status $systemDriveCheck.status), $systemDriveCheck.details))
    }
    if ($vmStorageCheck) {
        $lines.Add(('- Overall VM storage availability: {0} - {1}' -f (Get-CheckStatusText -Status $vmStorageCheck.status), $vmStorageCheck.details))
    }

    $lines.Add('')
    $lines.Add('Current blockers:')
    $renderedBlockers = @($readiness.blockers | Where-Object {
        $value = [string]$_
        $value -and $value -ne $readiness.takeaway -and $value -ne $readiness.headline
    })
    if ($renderedBlockers.Count -gt 0) {
        foreach ($item in $renderedBlockers) {
            $lines.Add(('- {0}' -f $item))
        }
    }
    else {
        $lines.Add('- None')
    }

    $lines.Add('')
    $lines.Add('Current limitations:')
    $renderedLimitations = @($readiness.limitations | Where-Object {
        $value = [string]$_
        $value -and $value -ne $readiness.takeaway -and $value -ne $readiness.headline
    })
    if ($renderedLimitations.Count -gt 0) {
        foreach ($item in $renderedLimitations) {
            $lines.Add(('- {0}' -f $item))
        }
    }
    else {
        $lines.Add('- None')
    }

    $lines.Add('')
    $lines.Add('Detailed checks:')
    foreach ($check in @($readiness.checks)) {
        $lines.Add(('- {0}: {1} - {2}' -f $check.label, (Get-CheckStatusText -Status $check.status), $check.details))
    }

    return ($lines -join [Environment]::NewLine)
}
