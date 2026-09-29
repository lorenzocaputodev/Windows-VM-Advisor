function Get-NominalMemoryGb {
    <#
    .SYNOPSIS
        Converts the OS-reported physical memory into the installed (marketing) size.

    .DESCRIPTION
        Windows reports less RAM than is installed because firmware and integrated graphics
        reserve a share of it (for example 7.6 GB on an 8 GB laptop). Threshold checks use this
        nominal value so that 8 GB and 16 GB hosts are not treated as smaller machines.
        Resource caps that protect the host must keep using the reported value.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [double]$ReportedGb
    )

    if ($ReportedGb -le 0) {
        return [double]0
    }

    return [double][math]::Ceiling([math]::Round($ReportedGb, 1))
}
